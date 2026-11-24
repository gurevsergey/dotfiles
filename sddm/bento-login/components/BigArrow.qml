import QtQuick

// Толстая стрелка ↗
Canvas {
    id: cv
    property color color: "black"
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        var s = Math.min(width, height)
        ctx.reset()
        ctx.fillStyle = cv.color
        ctx.strokeStyle = cv.color
        // наконечник
        ctx.beginPath()
        ctx.moveTo(s * 0.30, 0)
        ctx.lineTo(s, 0)
        ctx.lineTo(s, s * 0.70)
        ctx.closePath()
        ctx.fill()
        // древко
        ctx.lineWidth = s * 0.16
        ctx.lineCap = "butt"
        ctx.beginPath()
        ctx.moveTo(s * 0.06, s * 0.94)
        ctx.lineTo(s * 0.70, s * 0.30)
        ctx.stroke()
    }
}
