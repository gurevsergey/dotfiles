import QtQuick

// Блок «H M S D»: четыре столбика, заполненных снизу пропорционально времени
Rectangle {
    id: bars
    property var th
    property date now: new Date()

    readonly property real daysInMonth: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    readonly property var values: [
        now.getHours() / 23,
        now.getMinutes() / 59,
        now.getSeconds() / 59,
        now.getDate() / daysInMonth
    ]

    color: "transparent"
    border.color: th.ink
    border.width: Math.max(2, 3 * th.u)

    Row {
        id: row
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 16 * bars.th.u }
        spacing: 12 * bars.th.u
        Repeater {
            model: 4
            Column {
                required property int index
                spacing: 10 * bars.th.u
                Rectangle {
                    width: 24 * bars.th.u
                    height: bars.height - 16 * bars.th.u - 44 * bars.th.u
                    color: "transparent"
                    border.color: bars.th.ink
                    border.width: Math.max(1.5, 2 * bars.th.u)
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: parent.border.width + 2 * bars.th.u }
                        height: Math.max(0, (parent.height - 2 * anchors.margins) * Math.min(1, bars.values[index]))
                        color: bars.th.accent
                        Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ["H", "M", "S", "D"][index]
                    color: bars.th.ink
                    font.family: bars.th.display
                    font.pixelSize: 15 * bars.th.u
                }
            }
        }
    }
}
