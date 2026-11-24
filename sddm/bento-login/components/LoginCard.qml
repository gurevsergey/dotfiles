import QtQuick

// Карточка 2 — заголовок, HMSD-столбики, панель входа, описание, дата, питание
Card {
    id: card
    property date now: new Date()
    property int sessionIndex: 0
    signal sessionStep(int step)

    readonly property real u: th.u
    readonly property real pad: 34 * u
    readonly property var months: ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property bool userUpper: String(cfg("userUppercase", "true")).toLowerCase() === "true"
    property bool denied: false
    property bool busy: false      // идёт проверка PAM — повторный Enter не шлём
    property bool touchKey: false  // PAM ждёт касания YubiKey

    color: th.main

    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function focusInitial() {
        if (userInput.text.length > 0) passInput.forceActiveFocus()
        else userInput.forceActiveFocus()
    }
    function doLogin() {
        if (userInput.text.length === 0) { userInput.forceActiveFocus(); return }
        if (card.busy) return
        card.denied = false
        card.busy = true
        sddm.login(userInput.text, passInput.text, card.sessionIndex)
    }
    // ←/→ листают сессии: с Alt всегда, без Alt — когда поле пустое
    function sessionKeys(event, field) {
        if (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right) return
        if ((event.modifiers & Qt.AltModifier) || field.text.length === 0) {
            card.sessionStep(event.key === Qt.Key_Left ? -1 : 1)
            event.accepted = true
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            card.busy = false
            card.touchKey = false
            card.denied = true
            passInput.text = ""
            passInput.forceActiveFocus()
            denyAnim.restart()
        }
        function onLoginSucceeded() { card.denied = false; card.busy = false; card.touchKey = false }
        function onInformationMessage(message) {
            if (/FIDO|touch|authenticator/i.test(message)) card.touchKey = true
        }
    }

    // ── Заголовок ─────────────────────────────────────────────────────
    Text {
        id: title
        x: card.pad; y: 22 * card.u
        text: card.cfg("title", "EVANGELION")
        color: card.th.ink
        font.family: card.th.display
        font.pixelSize: 78 * card.u
        font.letterSpacing: 1 * card.u
    }
    Rectangle {
        x: title.x + title.contentWidth + 10 * card.u
        y: title.y + 16 * card.u
        width: 13 * card.u; height: width; radius: width / 2
        color: card.th.accent
    }
    BigArrow {
        anchors { right: parent.right; top: parent.top; margins: card.pad }
        width: 86 * card.u; height: width
        color: card.th.ink
    }

    // ── Средний ряд ───────────────────────────────────────────────────
    readonly property real midH: 262 * u
    readonly property real midY: {
        var top = title.y + title.height
        var bottom = dateText.y
        return Math.max(top + 12 * u, (top + bottom) / 2 - midH / 2)
    }

    Bars {
        th: card.th
        now: card.now
        x: card.pad; y: card.midY
        width: 156 * card.u; height: card.midH
    }

    Rectangle {
        id: panel
        x: card.pad + 156 * card.u + 22 * card.u
        y: card.midY
        width: Math.min(640 * card.u, card.width * 0.46)
        height: card.midH
        color: "transparent"
        border.color: card.th.ink
        border.width: Math.max(2, 3 * card.u)

        readonly property real ip: 20 * card.u
        readonly property real fieldX: 130 * card.u
        readonly property real fieldH: 46 * card.u
        readonly property real bw: Math.max(1.5, 2 * card.u)

        // строка «UA 570-B ........ AUTH»
        Item {
            id: header
            x: 0; y: 0; width: parent.width; height: 42 * card.u
            Text {
                anchors { left: parent.left; leftMargin: panel.ip; verticalCenter: parent.verticalCenter }
                text: card.cfg("authCode", "UA 570-B")
                color: card.th.ink
                font.family: card.th.monoBold
                font.pixelSize: 14 * card.u
            }
            Text {
                id: dotsLeader
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                text: card.cfg("authMid", "........")
                color: card.th.ink
                opacity: 0.6
                font.family: card.th.mono
                font.pixelSize: 14 * card.u
            }
            Text {
                id: status
                anchors { right: parent.right; rightMargin: panel.ip; verticalCenter: parent.verticalCenter }
                text: card.denied ? card.cfg("authDenied", "ACCESS DENIED")
                      : card.touchKey ? card.cfg("authTouch", "TOUCH KEY")
                      : card.busy ? card.cfg("authBusy", "CHECKING")
                      : card.cfg("authLabel", "AUTH")
                color: (card.denied || card.touchKey) ? card.th.accent : card.th.ink
                font.family: card.th.monoBold
                font.pixelSize: 14 * card.u
                font.letterSpacing: card.denied ? 1.5 : 0
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: panel.bw; color: card.th.ink }
        }

        // USER
        Text {
            x: panel.ip
            anchors.verticalCenter: userBox.verticalCenter
            text: card.cfg("userLabel", "USER")
            color: card.th.ink
            font.family: card.th.monoBold
            font.pixelSize: 12 * card.u
        }
        Rectangle {
            id: userBox
            x: panel.fieldX
            y: header.height + (panel.height - header.height - 2 * panel.fieldH - 24 * card.u) / 2
            width: panel.width - panel.fieldX - panel.ip; height: panel.fieldH
            color: userInput.activeFocus ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
            border.color: card.th.ink; border.width: panel.bw
            radius: 3 * card.u
            TextInput {
                id: userInput
                anchors { fill: parent; leftMargin: 16 * card.u; rightMargin: 16 * card.u }
                verticalAlignment: TextInput.AlignVCenter
                text: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : ""
                color: card.th.ink
                selectionColor: card.th.accent
                font.family: card.th.monoBold
                font.pixelSize: 21 * card.u
                font.capitalization: card.userUpper ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: 1 * card.u
                clip: true
                KeyNavigation.tab: passInput
                Keys.onPressed: (event) => card.sessionKeys(event, userInput)
                onAccepted: card.doLogin()
                cursorDelegate: Rectangle { width: 3 * card.u; color: card.th.accent; visible: userInput.activeFocus }
            }
        }

        // PASSKEY
        Text {
            x: panel.ip
            anchors.verticalCenter: passBox.verticalCenter
            text: card.cfg("passLabel", "PASSKEY")
            color: card.th.ink
            font.family: card.th.monoBold
            font.pixelSize: 12 * card.u
        }
        Rectangle {
            id: passBox
            x: panel.fieldX; y: userBox.y + panel.fieldH + 24 * card.u
            width: userBox.width; height: panel.fieldH
            color: passInput.activeFocus ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
            border.color: card.th.ink; border.width: panel.bw
            radius: 3 * card.u

            // вспышка при ошибке
            Rectangle {
                id: flash
                anchors.fill: parent
                radius: parent.radius
                color: card.th.accent
                opacity: 0
            }

            TextInput {
                id: passInput
                anchors { left: parent.left; right: goBtn.left; top: parent.top; bottom: parent.bottom; leftMargin: 16 * card.u; rightMargin: 10 * card.u }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                color: card.th.ink
                selectionColor: card.th.accent
                font.family: card.th.monoBold
                font.pixelSize: 22 * card.u
                font.letterSpacing: 3 * card.u
                clip: true
                KeyNavigation.backtab: userInput
                Keys.onPressed: (event) => card.sessionKeys(event, passInput)
                onAccepted: card.doLogin()
                onTextChanged: if (text.length > 0) card.denied = false
                cursorDelegate: Rectangle {
                    width: 3 * card.u
                    color: card.th.accent
                    visible: passInput.activeFocus
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: passInput.activeFocus
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 530 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 530 }
                    }
                }
            }

            Rectangle {
                id: goBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 * card.u }
                height: parent.height - 12 * card.u; width: height * 1.25
                radius: 2 * card.u
                color: goArea.pressed ? card.th.accent : card.th.ink
                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: card.th.main
                    font.pixelSize: 14 * card.u
                }
                MouseArea { id: goArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.doLogin() }
            }
        }

        SequentialAnimation {
            id: denyAnim
            loops: 3
            NumberAnimation { target: flash; property: "opacity"; to: 0.85; duration: 90 }
            NumberAnimation { target: flash; property: "opacity"; to: 0;    duration: 160 }
        }
        SequentialAnimation {
            running: denyAnim.running
            NumberAnimation { target: passBox; property: "x"; to: panel.fieldX + 8 * card.u; duration: 50 }
            NumberAnimation { target: passBox; property: "x"; to: panel.fieldX - 8 * card.u; duration: 70 }
            NumberAnimation { target: passBox; property: "x"; to: panel.fieldX + 4 * card.u; duration: 60 }
            NumberAnimation { target: passBox; property: "x"; to: panel.fieldX;              duration: 50 }
        }
    }

    // ── Описание справа ──────────────────────────────────────────────
    Text {
        x: panel.x + panel.width + 40 * card.u
        width: Math.min(380 * card.u, card.width - x - card.pad)
        y: card.midY + card.midH / 2 - height / 2
        text: card.cfg("description", "")
        wrapMode: Text.WordWrap
        color: card.th.ink
        font.family: card.th.mono
        font.pixelSize: 13 * card.u
        lineHeight: 1.55
    }

    // ── Низ: дата и питание ──────────────────────────────────────────
    Text {
        id: dateText
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: card.pad; bottomMargin: 26 * card.u }
        text: "#" + card.pad2(card.now.getDate()) + card.months[card.now.getMonth()] + card.pad2(card.now.getFullYear() % 100)
        color: card.th.ink
        font.family: card.th.display
        font.pixelSize: 44 * card.u
    }

    Row {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: card.pad; bottomMargin: 28 * card.u }
        spacing: 12 * card.u
        RoundIcon {
            th: card.th; glyph: "󰜉"; tip: "REBOOT"
            available: sddm.canReboot
            onClicked: sddm.reboot()
        }
        RoundIcon {
            th: card.th; glyph: "󰐥"; tip: "POWER"
            available: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
        RoundIcon {
            th: card.th; glyph: "󰤄"; tip: "SLEEP"
            available: sddm.canSuspend
            onClicked: sddm.suspend()
        }
    }
}
