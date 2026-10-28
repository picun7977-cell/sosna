import QtQuick
import qs.services

// Толстый ползунок как в Центре управления macOS: белая заливка, значок внутри
Rectangle {
    id: root

    property real value: 0.5
    property string icon: "volume_up"
    property color fill: Theme.text
    signal moved(real v)

    height: 26
    radius: 13
    color: Theme.alpha(Theme.text, 0.12)
    clip: true

    Rectangle {
        width: Math.max(root.height, root.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        radius: parent.radius
        color: root.fill
        Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Icon {
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 16
        fill: true
        color: "#1a1b1f"
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(m.x / width)
        onPositionChanged: m => { if (pressed) root.moved(Math.max(0, Math.min(1, m.x / width))) }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
