pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Курсор: позиция (для глазок острова) и «встряхни мышь» — курсор ненадолго вырастает, как на маке.
// Данные даёт scripts/cursor.py, он опрашивает сокет Hyprland.
Singleton {
    id: root

    property real x: 960
    property real y: 540
    property bool big: false
    readonly property string theme: "Bibata-Modern-Classic"
    readonly property int size: 20

    signal shaken

    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/cursor.py"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "shake") {
                    if (Config.o.shake)
                        root.grow();
                    return;
                }
                const p = line.split(" ");
                root.x = Number(p[0]);
                root.y = Number(p[1]);
            }
        }
    }

    function grow(): void {
        root.shaken();
        if (!big) {
            big = true;
            Quickshell.execDetached(["hyprctl", "setcursor", theme, String(size * 3)]);
        }
        shrink.restart();
    }

    Timer {
        id: shrink
        interval: 1300
        onTriggered: {
            root.big = false;
            Quickshell.execDetached(["hyprctl", "setcursor", root.theme, String(root.size)]);
        }
    }
}
