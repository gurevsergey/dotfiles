import QtQuick

// Круглая тёмная кнопка ‹ › по бокам сетки
Rectangle {
    id: btn
    property var th
    property string glyph: "›"
    signal clicked()

    width: 44 * th.u; height: width; radius: width / 2
    color: area.containsMouse ? "#2a2a2a" : "#161616"
    border.color: "#3a3a3a"; border.width: 1
    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2 * btn.th.u
        text: btn.glyph
        color: "#e8e8e8"
        font.family: btn.th.sans
        font.pixelSize: 30 * btn.th.u
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
