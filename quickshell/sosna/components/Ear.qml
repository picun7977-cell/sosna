import QtQuick
import QtQuick.Shapes
import qs.services

// Вогнутое «ушко», которым остров срастается со строкой меню
Shape {
    id: root

    property bool mirrored: false
    property real r: 12
    property color color: Theme.island

    width: r
    height: r
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: root.mirrored ? 0 : root.r
        startY: 0
        PathLine { x: root.mirrored ? 0 : root.r; y: root.r }
        PathArc {
            x: root.mirrored ? root.r : 0
            y: 0
            radiusX: root.r
            radiusY: root.r
            direction: root.mirrored ? PathArc.Clockwise : PathArc.Counterclockwise
        }
    }
}
