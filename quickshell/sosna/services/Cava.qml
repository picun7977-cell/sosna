pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Полоски звука для острова: cava работает, только пока играет музыка
Singleton {
    id: root

    property bool wanted: Media.playing
    property var bars: [0, 0, 0, 0, 0, 0]

    Process {
        running: root.wanted
        command: ["cava", "-p", Quickshell.shellDir + "/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s.length).map(s => parseInt(s) / 100);
                if (v.length >= 6)
                    root.bars = v.slice(0, 6);
            }
        }
        onRunningChanged: if (!running) root.bars = [0, 0, 0, 0, 0, 0]
    }
}
