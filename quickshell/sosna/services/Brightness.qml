pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Яркость самого монитора по DDC/CI (ddcutil, VCP 0x10). Монитор отвечает медленно,
// поэтому ползунок меняет значение сразу, а команда уходит с небольшой задержкой.
Singleton {
    id: root

    property real value: 0.5          // 0…1
    property bool ready: false
    property int bus: -1              // /dev/i2c-N монитора, находится один раз
    property int sent: -1

    function set(v: real): void {
        value = Math.max(0, Math.min(1, v));
        applyTimer.restart();
    }

    function step(d: real): void {
        set(value + d);
        Island.show("brightness", {}, 1400);
    }

    function refresh(): void {
        readProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 140
        onTriggered: {
            const n = Math.round(root.value * 100);
            if (n === root.sent || root.bus < 0)
                return;
            if (setProc.running) {
                restart();
                return;
            }
            root.sent = n;
            setProc.command = ["ddcutil", "--bus", String(root.bus), "--noverify", "--sleep-multiplier", "0.3", "setvcp", "10", String(n)];
            setProc.running = true;
        }
    }

    Process {
        id: setProc
    }

    // Шина монитора + текущая яркость: «/dev/i2c-3» и «VCP 10 C 3 100»
    Process {
        id: readProc
        command: ["sh", "-c", "b=$(ddcutil detect --brief 2>/dev/null | sed -n 's|.*/dev/i2c-\\([0-9]*\\).*|\\1|p' | head -1); [ -n \"$b\" ] || exit 1; echo bus $b; ddcutil --bus $b getvcp 10 --brief"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(/\s+/);
                if (p[0] === "bus")
                    root.bus = Number(p[1]);
                else if (p[0] === "VCP" && p.length >= 5) {
                    root.sent = Number(p[3]);
                    root.value = Number(p[3]) / Math.max(1, Number(p[4]));
                    root.ready = true;
                }
            }
        }
    }

    IpcHandler {
        target: "brightness"
        function up(): void {
            root.step(0.05);
        }
        function down(): void {
            root.step(-0.05);
        }
        function set(percent: int): void {
            root.set(percent / 100);
        }
    }
}
