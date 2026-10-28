import QtQuick
import QtQuick.Shapes
import qs.services

// Логотип «Сосны»: ёлочка из двух ярусов и ствол, тонкой линией
Item {
    id: root

    property color color: Theme.text
    property real stroke: 1.6

    implicitWidth: 18
    implicitHeight: 18

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        scale: width / 20
        transformOrigin: Item.TopLeft
        width: 20
        height: 20

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke * 20 / root.width
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M10 2 L6.2 7.2 H8.5 L5 12.4 H15 L11.5 7.2 H13.8 Z M10 12.4 V18" }
        }
    }
}
