pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Загрузка CPU/GPU/RAM для виджета «Система». Опрашивается, только пока виден рабочий стол.
Singleton {
    id: root

    property bool active: false
    property real cpu: 0
    property int cpuTemp: 0
    property real gpu: 0
    property int gpuTemp: 0
    property real ramUsed: 0
    property real ramTotal: 1
    property var lastStat: null

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: mem; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: temp; path: "/sys/class/hwmon/hwmon1/temp1_input"; blockLoading: true }

    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",").map(s => parseFloat(s));
                if (p.length === 2) {
                    root.gpu = p[0] / 100;
                    root.gpuTemp = p[1];
                }
            }
        }
    }

    Timer {
        running: root.active
        interval: 2500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            mem.reload();
            temp.reload();
            const f = stat.text().split("\n")[0].split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], sum = f.reduce((a, b) => a + b, 0);
            if (root.lastStat) {
                const dt = sum - root.lastStat.sum, di = idle - root.lastStat.idle;
                if (dt > 0)
                    root.cpu = 1 - di / dt;
            }
            root.lastStat = { sum: sum, idle: idle };
            const m = mem.text();
            const total = parseInt(m.match(/MemTotal:\s+(\d+)/)[1]);
            const avail = parseInt(m.match(/MemAvailable:\s+(\d+)/)[1]);
            root.ramTotal = total / 1048576;
            root.ramUsed = (total - avail) / 1048576;
            root.cpuTemp = Math.round(parseInt(temp.text()) / 1000);
            gpuProc.running = true;
        }
    }
}
