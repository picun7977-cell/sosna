import QtQuick

// Знак Claude: оранжевая звёздочка из лучей разной длины. spinning — медленно крутится и «дышит».
Item {
    id: root

    property real size: 20
    property bool spinning: false
    property color color: "#d97757"

    width: size
    height: size

    // Длина каждого луча (доля радиуса) — неровные, как у рисованной звёздочки
    readonly property var rays: [1.0, 0.78, 0.95, 0.72, 1.0, 0.84, 0.9, 0.74, 0.98, 0.8, 0.92, 0.76]

    Item {
        id: burst
        anchors.fill: parent

        Repeater {
            model: root.rays.length
            Rectangle {
                required property int index
                readonly property real len: root.size / 2 * root.rays[index]
                width: Math.max(1.5, root.size * 0.11)
                height: len
                radius: width / 2
                color: root.color
                antialiasing: true
                x: (root.size - width) / 2
                y: root.size / 2 - len
                transform: Rotation {
                    origin.x: root.size * 0.055
                    origin.y: len
                    angle: index * 360 / root.rays.length
                }
            }
        }

        RotationAnimation on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 6000
        }
        SequentialAnimation on scale {
            running: root.spinning
            loops: Animation.Infinite
            NumberAnimation { to: 0.82; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }
}
