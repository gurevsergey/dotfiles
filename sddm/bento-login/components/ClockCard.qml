import QtQuick

// Карточка 4 — подпись, логотип, огромные часы ЧЧММ (часы чёрные, минуты акцентные)
Card {
    id: card
    property date now: new Date()
    readonly property real u: th.u

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    color: th.clock

    Text {
        anchors { left: parent.left; top: parent.top; leftMargin: 30 * card.u; topMargin: 26 * card.u }
        text: card.cfg("clockCaption", "Retro ai\ntecnology")
        color: card.th.ink
        font.family: card.th.sans
        font.weight: Font.Medium
        font.pixelSize: 26 * card.u
        lineHeight: 1.1
    }

    // логотип: две косые плашки
    Canvas {
        id: logo
        anchors { right: parent.right; top: parent.top; rightMargin: 30 * card.u; topMargin: 28 * card.u }
        width: 44 * card.u; height: width
        property color c: card.th.ink
        onCChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), s = width
            ctx.reset()
            ctx.fillStyle = c
            ctx.beginPath()
            ctx.moveTo(0, 0); ctx.lineTo(s * 0.42, 0); ctx.lineTo(s * 0.42, s * 0.55); ctx.lineTo(0, s); ctx.closePath()
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(s * 0.58, 0); ctx.lineTo(s, 0); ctx.lineTo(s * 0.58, s * 0.45); ctx.closePath()
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(s, s * 0.22); ctx.lineTo(s, s); ctx.lineTo(s * 0.30, s); ctx.closePath()
            ctx.fill()
        }
    }

    Row {
        id: clock
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 22 * card.u; bottomMargin: 10 * card.u }
        Text {
            text: card.pad2(card.now.getHours())
            color: card.th.ink
            font.family: card.th.display
            font.pixelSize: Math.min(card.height * 0.58, card.width * 0.30)
            font.letterSpacing: -4 * card.u
        }
        Text {
            text: card.pad2(card.now.getMinutes())
            color: card.th.accent
            font.family: card.th.display
            font.pixelSize: Math.min(card.height * 0.58, card.width * 0.30)
            font.letterSpacing: -4 * card.u
        }
    }
    Rectangle {
        x: clock.x + clock.width + 10 * card.u
        y: clock.y + clock.height * 0.22
        width: 6 * card.u; height: width; radius: width / 2
        color: card.th.ink
    }
}
