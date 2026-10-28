import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services

// Скруглённые углы экрана (чёрные «уголки» поверх всего, мышь проходит насквозь)
// и горячий угол: мышь в левый верхний угол → Mission Control (действие — в Настройках).
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: Config.o.cornersRound && !Hypr.fullscreen
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sosna-corners"
            mask: Region {}

            Repeater {
                model: 4
                delegate: Shape {
                    required property int index
                    readonly property real r: Config.o.cornerRadius
                    width: r
                    height: r
                    x: index % 2 === 0 ? 0 : parent.width - r
                    y: index < 2 ? 0 : parent.height - r
                    rotation: [0, 90, 270, 180][index]
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "black"
                        strokeWidth: -1
                        startX: 0
                        startY: 0
                        PathLine { x: r; y: 0 }
                        PathArc { x: 0; y: r; radiusX: r; radiusY: r; direction: PathArc.Counterclockwise }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
        }
    }

    // Горячий угол: окошко 3×3 пикселя; срабатывает, если мышь задержалась на 120 мс
    PanelWindow {
        screen: Quickshell.screens[0]
        visible: Config.o.hotCorner && !Hypr.fullscreen && !Session.locked
        color: "transparent"
        anchors {
            top: true
            left: true
        }
        implicitWidth: 3
        implicitHeight: 3
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sosna-hotcorner"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: dwell.restart()
            onExited: dwell.stop()
        }
        Timer {
            id: dwell
            interval: 120
            onTriggered: {
                const a = Config.o.hotCornerAction;
                if (a === "spotlight")
                    Ui.spotlight("");
                else if (a === "control")
                    Ui.toggle("controlOpen");
                else if (a === "lock")
                    Session.lock();
                else
                    Ui.toggle("missionOpen");
            }
        }
    }
}
