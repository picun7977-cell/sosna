pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Рамки окон в цвет акцента темы (общий с Сосной): активное — градиент акцента, остальные — еле заметные.
// После hyprctl reload Hyprland возвращает свои цвета, поэтому применяем заново.
Singleton {
    id: root

    function hex(c: color, a: real): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return h(c.r) + h(c.g) + h(c.b) + h(a);
    }

    function apply(): void {
        const acc = Theme.accent;
        const light = Theme.mix(acc, Qt.color("#ffffff"), 0.35);
        Hyprland.dispatch(`(function() hl.config({ general = { col = { active_border = { colors = { "rgba(${hex(acc, 0.95)})", "rgba(${hex(light, 0.95)})" }, angle = 45 }, inactive_border = "rgba(${hex(Qt.color("#ffffff"), 0.08)})" } } }) return hl.dsp.exec_cmd("true") end)()`);
    }

    Connections {
        target: Theme
        function onAccentChanged(): void {
            debounce.restart();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(e: HyprlandEvent): void {
            if (e.name === "configreloaded")
                debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.apply()
    }

    Component.onCompleted: debounce.restart()
}
