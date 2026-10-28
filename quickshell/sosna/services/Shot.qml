pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Скриншоты (Super+Shift+S — заморозка и выделение, Print — весь экран) и пипетка
Singleton {
    id: root

    property bool picking: false
    property string last: ""
    property int tick: 0
    signal captureRect(rect r)

    function pick(): void {
        if (picking)
            return;
        Ui.closeAll();
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/Pictures/Screenshots"]);
        Hyprland.refreshToplevels();
        picking = true;
    }

    // Файл сохранён слоем выбора области: в буфер + миниатюра
    function finish(path: string): void {
        Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$0\"", path]);
        done(path);
    }

    function full(): void {
        const f = newPath();
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$0\")\" && grim \"$0\" && wl-copy --type image/png < \"$0\"", f]);
        delayed.path = f;
        delayed.restart();
    }

    function newPath(): string {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return Quickshell.env("HOME") + "/Pictures/Screenshots/Снимок " + d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + "." + p(d.getMinutes()) + "." + p(d.getSeconds()) + ".png";
    }

    // Вызывается после сохранения файла: звук затвора + миниатюра в углу
    function done(path: string): void {
        last = path;
        tick++;
        Sounds.play("shutter");
    }

    function edit(path: string): void {
        Quickshell.execDetached(["satty", "--filename", path, "--output-filename", path, "--copy-command", "wl-copy"]);
    }

    function pickColor(): void {
        colorProc.running = true;
    }

    Timer {
        id: regionTimer
        property rect r
        interval: 450
        onTriggered: root.captureRect(r)
    }

    Timer {
        id: delayed
        property string path
        interval: 350
        onTriggered: root.done(path)
    }

    Process {
        id: colorProc
        command: ["hyprpicker", "-a", "-f", "hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = text.trim();
                if (/^#[0-9a-fA-F]{6}$/.test(hex))
                    Island.show("color", { hex: hex }, 2600);
            }
        }
    }

    IpcHandler {
        target: "shot"
        function area(): void {
            root.pick();
        }
        function full(): void {
            root.full();
        }
        // qs -c sosna ipc call shot region 100 100 640 360
        function region(x: int, y: int, w: int, h: int): void {
            root.pick();
            regionTimer.r = Qt.rect(x, y, w, h);
            regionTimer.restart();
        }
        function cancel(): void {
            root.picking = false;
        }
        function color(): void {
            root.pickColor();
        }
    }
}
