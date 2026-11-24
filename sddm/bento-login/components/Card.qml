import QtQuick

// Скруглённая карточка бенто-сетки
Rectangle {
    required property var th
    property var cfg: function (key, fallback) { return fallback }
    radius: th ? th.radius : 16
    clip: true
}
