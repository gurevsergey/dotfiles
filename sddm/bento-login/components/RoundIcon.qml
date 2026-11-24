import QtQuick

// Круглая иконка с тонкой рамкой (перезагрузка / выключение / сон)
Item {
    id: ic
    property var th
    property string glyph: ""
    property string tip: ""
    property bool available: true
    signal clicked()

    width: 38 * th.u; height: width
    opacity: available ? 1 : 0.35

    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        color: area.containsMouse && ic.available ? ic.th.ink : "transparent"
        border.color: ic.th.ink
        border.width: Math.max(1.5, 2 * ic.th.u)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Text {
        anchors.centerIn: parent
        text: ic.glyph
        color: area.containsMouse && ic.available ? ic.th.main : ic.th.ink
        font.family: ic.th.mono
        font.pixelSize: 20 * ic.th.u
    }
    Text {
        // подпись при наведении
        anchors.bottom: parent.top
        anchors.bottomMargin: 6 * ic.th.u
        anchors.horizontalCenter: parent.horizontalCenter
        visible: area.containsMouse
        text: ic.tip
        color: ic.th.ink
        font.family: ic.th.mono
        font.pixelSize: 11 * ic.th.u
        font.letterSpacing: 1
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: ic.available
        cursorShape: Qt.PointingHandCursor
        onClicked: ic.clicked()
    }
}
