pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Голосовой ассистент Эби пишет сюда своё состояние:
// qs -c sosna ipc call abi state listening|thinking|speaking|idle "текст"
Singleton {
    id: root

    property string state: "idle"
    property string text: ""

    IpcHandler {
        target: "abi"
        function state(s: string, t: string): void {
            root.state = s;
            root.text = t;
            safety.restart();
        }
    }

    // Если Эби упала и не прислала idle — сами вернёмся через 40 с
    Timer {
        id: safety
        interval: 40000
        onTriggered: root.state = "idle"
    }
}
