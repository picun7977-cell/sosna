pragma Singleton

import QtQuick
import Quickshell

// Тихие системные звуки (сгенерированы ffmpeg, лежат в sounds/)
Singleton {
    readonly property bool enabled: Config.o.sounds

    function play(name: string): void {
        if (enabled)
            Quickshell.execDetached(["pw-play", "--volume", "0.6", Quickshell.shellDir + "/sounds/" + name + ".ogg"]);
    }
}
