import QtQuick

// Карточка 1 — вертикальный арт: цвет + картинка (cover), «01», иероглифы
Card {
    id: card
    color: th.art

    Image {
        anchors.fill: parent
        source: card.th.background_image
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: card.th.backgroundOpacity
    }

    Text {
        id: idx
        anchors { left: parent.left; top: parent.top; leftMargin: 22 * card.th.u; topMargin: 20 * card.th.u }
        text: card.cfg("artIndex", "01")
        color: card.th.ink
        font.family: card.th.display
        font.pixelSize: 26 * card.th.u
    }
    Text {
        anchors { right: parent.right; top: parent.top; rightMargin: 22 * card.th.u; topMargin: 22 * card.th.u }
        text: card.cfg("artCaption", "Exhibition\nTour 2026")
        horizontalAlignment: Text.AlignRight
        color: card.th.ink
        font.family: card.th.mono
        font.pixelSize: 10 * card.th.u
        lineHeight: 1.1
    }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 24 * card.th.u; bottomMargin: 18 * card.th.u }
        text: card.cfg("artGlyphs", "独創").split("").join("\n")
        color: card.th.ink
        font.family: card.th.cjk
        font.weight: Font.Bold
        font.pixelSize: 118 * card.th.u
        lineHeight: 0.98
    }
}
