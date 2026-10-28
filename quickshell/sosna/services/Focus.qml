pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Фокус-таймер (помодоро). На время фокуса включается «Не беспокоить».
Singleton {
    id: root

    property bool running: false
    property int total: 25 * 60
    property int left: total
    property string label: "Фокус"
    property bool dndBefore: false
    readonly property real progress: total > 0 ? left / total : 0

    function start(minutes: int, name: string): void {
        total = minutes * 60;
        left = total;
        label = name || "Фокус";
        dndBefore = Notifs.dnd;
        Notifs.dnd = true;
        running = true;
    }

    function stop(): void {
        running = false;
        Notifs.dnd = dndBefore;
    }

    function toggle(): void {
        if (running)
            stop();
        else
            start(25, "Фокус");
    }

    function fmt(): string {
        return Math.floor(left / 60) + ":" + String(left % 60).padStart(2, "0");
    }

    Timer {
        running: root.running
        interval: 1000
        repeat: true
        onTriggered: {
            root.left--;
            if (root.left <= 0) {
                root.stop();
                Sounds.play("focus");
                Island.show("text", { title: root.label + " — готово", body: "Отдохни 5 минут", icon: "self_improvement" }, 6000);
            }
        }
    }

    IpcHandler {
        target: "focus"
        function start(minutes: int, name: string): void {
            root.start(minutes, name);
        }
        function stop(): void {
            root.stop();
        }
    }
}
