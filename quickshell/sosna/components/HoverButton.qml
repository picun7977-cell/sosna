import QtQuick
import qs.services

// Прозрачная кнопка с подсветкой при наведении
Rectangle {
    id: root

    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property color hoverColor: Theme.tileHover
    property bool active: false
    signal clicked(var mouse)

    property real hoverScale: 1.1

    radius: 7
    scale: mouse.pressed ? 0.94 : mouse.containsMouse ? hoverScale : 1
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    color: active ? Theme.alpha(Theme.text, 0.18) : mouse.containsMouse ? hoverColor : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
    }
}
