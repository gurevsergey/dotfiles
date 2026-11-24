// bento-login — SDDM 0.21+ / Qt6
import QtQuick
import "components"

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: th.background

    // ── Чтение theme.conf ─────────────────────────────────────────────
    function cfgRaw(key, fallback) {
        var v = (typeof config !== "undefined" && config) ? config[key] : undefined
        if (v === undefined || v === null || String(v) === "") return fallback
        return String(v).replace(/\\n/g, "\n")
    }
    // Значение из theme.conf с подстановкой %KEY% из сведений о ПК
    function cfg(key, fallback) {
        var s = cfgRaw(key, fallback)
        if (s === undefined || s === null) return s
        var v = root.vars
        return String(s).replace(/%([A-Z_]+)%/g, function (all, k) {
            return v[k] !== undefined && v[k] !== "" ? v[k] : root.cfgRaw("missingValue", "—")
        })
    }
    function cfgBool(key, fallback) {
        var v = cfgRaw(key, fallback ? "true" : "false")
        return String(v).toLowerCase() === "true"
    }

    // относительный путь → от папки темы, абсолютный → file://
    function path(p) {
        p = String(p)
        if (p.charAt(0) === "/") return "file://" + p
        if (/^[a-z]+:/i.test(p)) return p
        return Qt.resolvedUrl(p)
    }

    readonly property int paletteCount: Math.max(1, parseInt(cfgRaw("paletteCount", "1")))
    property int paletteIndex: Math.min(paletteCount, Math.max(1, parseInt(cfgRaw("defaultPalette", "1")))) - 1

    function pal(key, fallback) { return cfgRaw("palette" + (paletteIndex + 1) + "_" + key, fallback) }
    function nextPalette(step) { paletteIndex = (paletteIndex + step + paletteCount) % paletteCount }

    // ── Шрифты ───────────────────────────────────────────────────────
    FontLoader { id: fDisplay;  source: root.path(root.cfgRaw("fontDisplay",  "fonts/ArchivoBlack-Regular.ttf")) }
    FontLoader { id: fSans;     source: root.path(root.cfgRaw("fontSans",     "fonts/SpaceGrotesk.ttf")) }
    FontLoader { id: fMono;     source: root.path(root.cfgRaw("fontMono",     "fonts/JetBrainsMonoNerdFontMono-Regular.ttf")) }
    FontLoader { id: fMonoBold; source: root.path(root.cfgRaw("fontMonoBold", "fonts/JetBrainsMonoNerdFontMono-Bold.ttf")) }

    // ── Общая тема для всех карточек ─────────────────────────────────
    QtObject {
        id: th
        // единица масштаба: 1 = экран 1920×1080
        readonly property real u: Math.min(root.width / 1920, root.height / 1080)
        readonly property real radius: 16 * u

        property color background: root.pal("background", "#0b0b0b")
        property color art:        root.pal("art",        "#c8312b")
        property color main:       root.pal("main",       "#e0a060")
        property color session:    root.pal("session",    "#6fa06a")
        property color clock:      root.pal("clock",      "#a8a8a8")
        property color accent:     root.pal("accent",     "#d43a2f")
        property color ink:        root.pal("ink",        "#0b0b0b")
        Behavior on background { ColorAnimation { duration: 400 } }
        Behavior on art        { ColorAnimation { duration: 400 } }
        Behavior on main       { ColorAnimation { duration: 400 } }
        Behavior on session    { ColorAnimation { duration: 400 } }
        Behavior on clock      { ColorAnimation { duration: 400 } }
        Behavior on accent     { ColorAnimation { duration: 400 } }
        Behavior on ink        { ColorAnimation { duration: 400 } }

        readonly property string display:  fDisplay.status  === FontLoader.Ready ? fDisplay.name  : "sans-serif"
        readonly property string sans:     fSans.status     === FontLoader.Ready ? fSans.name     : "sans-serif"
        readonly property string mono:     fMono.status     === FontLoader.Ready ? fMono.name     : "monospace"
        readonly property string monoBold: fMonoBold.status === FontLoader.Ready ? fMonoBold.name : "monospace"
        readonly property string cjk: root.cfgRaw("fontCjk", "IBM Plex Sans JP")

        readonly property url background_image: root.path(root.cfgRaw("background", "background.png"))
        readonly property real backgroundOpacity: parseFloat(root.cfgRaw("backgroundOpacity", "1"))
    }

    // ── Время (одно на все карточки) ─────────────────────────────────
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // ── Сведения о ПК: файл от bento-sysinfo.sh (root, systemd) ──────
    // Перечитывается раз в sysinfoRefresh секунд; ?t= обходит кэш компонентов.
    property var sysinfo: ({})
    property int sysinfoStamp: 0
    Loader {
        id: sysLoader
        active: root.cfgRaw("sysinfoFile", "") !== ""
        source: active ? root.path(root.cfgRaw("sysinfoFile", "")) + "?t=" + root.sysinfoStamp : ""
        onLoaded: if (item && item.info) root.sysinfo = item.info
    }
    Timer {
        interval: Math.max(30, parseInt(root.cfgRaw("sysinfoRefresh", "120"))) * 1000
        running: sysLoader.active; repeat: true
        onTriggered: root.sysinfoStamp++
    }

    function fmtUptime(sec) {
        if (!(sec > 0)) return ""
        var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m")
    }
    // Всё, что доступно для %KEY%: файл + живые значения
    readonly property var vars: {
        var o = {}
        for (var k in sysinfo) o[k] = String(sysinfo[k])
        if (sysinfo.BOOT_EPOCH) o.UPTIME = fmtUptime(Math.floor(now.getTime() / 1000) - parseInt(sysinfo.BOOT_EPOCH))
        if (typeof sddm !== "undefined" && sddm.hostName) o.HOST = o.HOST || sddm.hostName
        o.SESSIONS = String(sessionNames.count)
        o.SESSION_NO = String(sessionIndex + 1)
        if (typeof userModel !== "undefined") o.USERS = String(userModel.count)
        if (typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts.length > keyboard.currentLayout && keyboard.currentLayout >= 0)
            o.LAYOUT = String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase()
        return o
    }

    // ── Сессии: имена из sessionModel ────────────────────────────────
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    readonly property int sessionCount: sessionNames.count
    readonly property string sessionName: {
        var it = sessionNames.count > 0 ? sessionNames.itemAt(Math.min(sessionIndex, sessionNames.count - 1)) : null
        return it ? it.sname : "DEFAULT"
    }
    function nextSession(step) {
        if (sessionCount > 0) sessionIndex = (sessionIndex + step + sessionCount) % sessionCount
    }
    Repeater {
        id: sessionNames
        model: (typeof sessionModel !== "undefined") ? sessionModel : 0
        delegate: Item { required property string name; property string sname: name; visible: false }
    }

    // ── Геометрия бенто-сетки ────────────────────────────────────────
    readonly property real m: width * 0.03
    readonly property real g: width * 0.012
    readonly property real innerH: height - 2 * m
    readonly property real leftW: width * 0.20
    readonly property real rightX: m + leftW + g
    readonly property real rightW: width - rightX - m
    readonly property real topH: (innerH - g) * 0.6
    readonly property real botH: innerH - g - topH
    readonly property real botW: (rightW - g) / 2

    ArtCard {
        id: artCard
        th: th; cfg: root.cfg
        x: root.m; y: root.m; width: root.leftW; height: root.innerH
    }

    LoginCard {
        id: loginCard
        th: th; cfg: root.cfg; now: root.now
        sessionIndex: root.sessionIndex
        x: root.rightX; y: root.m; width: root.rightW; height: root.topH
        onSessionStep: (step) => root.nextSession(step)
    }

    SessionCard {
        th: th; cfg: root.cfg; now: root.now
        sessionName: root.sessionName
        x: root.rightX; y: root.m + root.topH + root.g; width: root.botW; height: root.botH
        onClicked: root.nextSession(1)
    }

    ClockCard {
        th: th; cfg: root.cfg; now: root.now
        x: root.rightX + root.botW + root.g; y: root.m + root.topH + root.g; width: root.botW; height: root.botH
    }

    // ── Перелистывание палитр ────────────────────────────────────────
    NavArrow {
        th: th; glyph: "‹"
        x: root.m - width / 2; y: root.height / 2 - height / 2
        onClicked: root.nextPalette(-1)
    }
    NavArrow {
        th: th; glyph: "›"
        x: root.width - root.m - width / 2; y: root.height / 2 - height / 2
        onClicked: root.nextPalette(1)
    }

    Rectangle {
        // точки-индикатор
        visible: root.paletteCount > 1
        width: dots.width + 20 * th.u; height: 22 * th.u; radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)
        x: root.rightX + root.rightW / 2 - width / 2
        y: root.height - root.m - height / 2
        Row {
            id: dots
            anchors.centerIn: parent
            spacing: 8 * th.u
            Repeater {
                model: root.paletteCount
                Rectangle {
                    required property int index
                    width: 9 * th.u; height: width; radius: width / 2
                    color: index === root.paletteIndex ? "#ffffff" : "#6a6a6a"
                    Behavior on color { ColorAnimation { duration: 200 } }
                    MouseArea { anchors.fill: parent; anchors.margins: -4 * th.u; cursorShape: Qt.PointingHandCursor; onClicked: root.paletteIndex = parent.index }
                }
            }
        }
    }

    Component.onCompleted: loginCard.focusInitial()
}
