import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Обои на самом нижнем слое, плавная смена с лёгким «наездом»
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        color: "#1b1c20"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "sosna-wallpaper"

        property bool flip: false
        // Рядом с картинкой лежит видео — живые обои (mpvpaper на том же слое), картинку прячем
        property bool live: false
        visible: !live

        Process {
            id: liveCheck
            command: ["sh", "-c", "for e in mp4 webm mkv mov; do [ -f \"${0%.*}.$e\" ] && echo yes && exit; done; echo no", Wall.path]
            running: Wall.path !== ""
            stdout: StdioCollector {
                onStreamFinished: win.live = text.trim() === "yes"
            }
        }

        Connections {
            target: Wall
            function onPathChanged(): void {
                if (!Wall.path)
                    return;
                liveCheck.running = false;
                liveCheck.running = true;
                win.flip = !win.flip;
                (win.flip ? b : a).source = "file://" + Wall.path;
            }
        }

        Image {
            id: a
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(win.width, win.height)
            source: Wall.path ? "file://" + Wall.path : ""
            opacity: !win.flip && status === Image.Ready ? 1 : 0
            scale: opacity < 1 ? 1.04 : 1
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        }
        Image {
            id: b
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(win.width, win.height)
            opacity: win.flip && status === Image.Ready ? 1 : 0
            scale: opacity < 1 ? 1.04 : 1
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        }
    }
}
