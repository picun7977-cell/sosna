pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Запись экрана через gpu-screen-recorder (если в ~/.local/bin лежит своя обёртка — берётся она)
Singleton {
    id: root

    property bool active: proc.running
    property real startedAt: 0
    property int elapsed: 0
    property string file: ""

    function toggle(): void {
        if (proc.running) {
            proc.signal(2);
            return;
        }
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        file = Quickshell.env("HOME") + "/Videos/Screencasting/" + d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".mp4";
        startedAt = Date.now();
        elapsed = 0;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["sh", "-c", "mkdir -p \"$HOME/Videos/Screencasting\" && g=\"$HOME/.local/bin/gpu-screen-recorder\"; [ -x \"$g\" ] || g=gpu-screen-recorder; exec \"$g\" -w screen -f 60 -a default_output -o \"$0\"", root.file]
        onExited: code => {
            Island.show("text", { title: "Запись сохранена", body: root.file.replace(Quickshell.env("HOME"), "~"), icon: "movie" }, 3500);
        }
    }

    Timer {
        running: root.active
        interval: 1000
        repeat: true
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }
}
