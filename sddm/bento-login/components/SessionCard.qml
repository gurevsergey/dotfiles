import QtQuick

// Карточка 3 — сессия: день недели, дата, имя сессии (клик/←→ листают)
Card {
    id: card
    property date now: new Date()
    property string sessionName: ""
    signal clicked()

    readonly property var sessionParts: {
        var m = /^\s*(.*?)\s*\((.*)\)\s*$/.exec(sessionName)
        return m ? [m[1], m[2]] : [sessionName, ""]
    }
    readonly property string sessionMain: sessionParts[0]
    readonly property string sessionSub: sessionParts[1]

    readonly property real u: th.u
    readonly property var days: ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
    readonly property var months: ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE","JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"]

    color: th.session

    Rectangle {
        id: frame
        anchors { fill: parent; margins: 20 * card.u }
        color: "transparent"
        radius: 10 * card.u
        border.color: card.th.ink
        border.width: Math.max(1, 1.5 * card.u)

        readonly property real ip: 22 * card.u

        Column {
            x: frame.ip; y: frame.ip
            spacing: 14 * card.u
            Text {
                text: card.days[card.now.getDay()]
                color: card.th.ink
                font.family: card.th.monoBold
                font.pixelSize: 13 * card.u
                font.letterSpacing: 1 * card.u
            }
            Text {
                text: card.now.getDate() + " " + card.months[card.now.getMonth()] + " " + card.now.getFullYear()
                color: card.th.ink
                font.family: card.th.monoBold
                font.pixelSize: 13 * card.u
                font.letterSpacing: 1 * card.u
            }
        }

        // имя сессии + «DE»
        Item {
            id: nameRow
            x: frame.ip; width: frame.width - 2 * frame.ip
            height: sessionText.height
            anchors.bottom: rule.top
            anchors.bottomMargin: 10 * card.u

            // «Hyprland (uwsm-managed)» → крупно HYPRLAND, мелко UWSM-MANAGED
            Text {
                anchors { left: parent.left; bottom: sessionText.top; bottomMargin: 2 * card.u }
                text: card.sessionSub.toUpperCase()
                visible: text.length > 0
                color: card.th.ink
                font.family: card.th.monoBold
                font.pixelSize: 11 * card.u
                font.letterSpacing: 1 * card.u
            }
            Text {
                id: sessionText
                width: parent.width - tag.width - 16 * card.u
                text: card.sessionMain.toUpperCase()
                elide: Text.ElideRight
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 20 * card.u
                color: card.th.ink
                font.family: card.th.display
                font.pixelSize: 44 * card.u
                font.letterSpacing: 1 * card.u
                opacity: area.containsMouse ? 0.75 : 1

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: sessionText; property: "opacity"; to: 0; duration: 90 }
                        PropertyAction {}
                        NumberAnimation { target: sessionText; property: "opacity"; to: 1; duration: 140 }
                    }
                }
            }
            Text {
                id: tag
                anchors { right: parent.right; baseline: sessionText.baseline }
                text: card.cfg("sessionTag", "DE")
                color: card.th.ink
                font.family: card.th.display
                font.pixelSize: 26 * card.u
            }
            MouseArea {
                id: area
                anchors.fill: sessionText
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.clicked()
            }
        }

        Rectangle {
            id: rule
            x: frame.ip; width: frame.width - 2 * frame.ip; height: Math.max(1, 1.5 * card.u)
            anchors.bottom: hint.top; anchors.bottomMargin: 14 * card.u
            color: card.th.ink
        }

        Text {
            id: hint
            x: frame.ip
            anchors.bottom: parent.bottom; anchors.bottomMargin: frame.ip
            text: card.cfg("sessionHint", "SELECT\nSESSION\nBEFORE LOGIN")
            color: card.th.ink
            font.family: card.th.monoBold
            font.pixelSize: 11 * card.u
            lineHeight: 1.35
        }
        Text {
            anchors { right: parent.right; rightMargin: frame.ip; bottom: hint.bottom }
            text: card.cfg("copyright", "©2026")
            horizontalAlignment: Text.AlignRight
            lineHeight: 1.35
            color: card.th.ink
            font.family: card.th.monoBold
            font.pixelSize: 11 * card.u
        }
    }
}
