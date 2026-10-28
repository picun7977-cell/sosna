pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Обёртка над Hyprland: окна, рабочие столы, раскладка, Caps Lock.
// В Hyprland 0.56 диспетчеры — это Lua-выражения hl.dsp.*
Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels.values
    readonly property HyprlandToplevel active: Hyprland.activeToplevel
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int wsId: focusedWorkspace?.id ?? 1
    readonly property var wsWindows: toplevels.filter(t => t.workspace?.id === wsId)
    readonly property bool wsEmpty: wsWindows.length === 0
    // Окно на весь экран (игра, видео) — остров и док прячутся
    readonly property bool fullscreen: wsWindows.some(t => (t.lastIpcObject?.fullscreen ?? 0) > 0)

    // Имя активного приложения для строки меню
    readonly property string activeApp: {
        const t = active;
        if (!t || t.workspace?.id !== wsId)
            return "Рабочий стол";
        const cls = t.lastIpcObject?.class ?? t.wayland?.appId ?? "";
        if (cls === "org.quickshell" && (t.title ?? "").startsWith("Сосна"))
            return "Настройки";
        const entry = DesktopEntries.heuristicLookup(cls);
        return entry?.name ?? prettify(cls);
    }
    readonly property string activeTitle: (active && active.workspace?.id === wsId) ? (active.title ?? "") : ""

    property string layout: "RU"
    property bool caps: false

    signal layoutSwitched(string from, string to)

    function prettify(cls: string): string {
        if (!cls)
            return "";
        const s = cls.split(".").pop().replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function dispatch(lua: string): void {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int): void {
        dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
    }

    function focusWindow(addr: string): void {
        dispatch(`hl.dsp.focus({ window = "address:0x${addr}" })`);
    }

    function closeWindow(addr: string): void {
        dispatch(`hl.dsp.window.close({ window = "address:0x${addr}" })`);
    }

    function moveWindow(addr: string, ws: int): void {
        dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:0x${addr}" })`);
    }

    function exec(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function classOf(t): string {
        return (t?.lastIpcObject?.class ?? t?.wayland?.appId ?? "").toLowerCase();
    }

    function shortLayout(name: string): string {
        const n = name.toLowerCase();
        if (n.startsWith("russian"))
            return "RU";
        if (n.startsWith("english"))
            return "EN";
        if (n.startsWith("ukrain"))
            return "UA";
        return name.slice(0, 2).toUpperCase();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "activelayout") {
                const name = event.data.split(",").slice(1).join(",");
                const next = root.shortLayout(name);
                if (next !== root.layout) {
                    const prev = root.layout;
                    root.layout = next;
                    root.layoutSwitched(prev, next);
                }
            } else if (["openwindow", "closewindow", "movewindow", "fullscreen", "activewindow", "workspace", "changefloatingmode"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            }
        }
    }

    // Начальная раскладка
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main) ?? JSON.parse(text).keyboards[0];
                    root.layout = root.shortLayout(kb.active_keymap);
                } catch (e) {}
            }
        }
    }

    // Caps Lock: один долгоживущий процесс читает светодиоды клавиатур
    Process {
        running: true
        command: ["sh", "-c", "while :; do cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -1; sleep 0.3; done"]
        stdout: SplitParser {
            onRead: line => {
                const on = line.trim() !== "0" && line.trim() !== "";
                if (on !== root.caps)
                    root.caps = on;
            }
        }
    }
}
