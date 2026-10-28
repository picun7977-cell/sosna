pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Содержимое дока: закреплённые (~/.config/sosna/dock.json) + запущенные незакреплённые.
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.config/sosna/dock.json"
    readonly property var defaults: ["thunar", "foot", "firefox", "code", "org.telegram.desktop", "discord", "steam"]

    property var pinned: []
    property var launching: ({})   // id → время запуска (иконка подпрыгивает)
    property int launchTick: 0

    // Все элементы дока: { id, entry, pinned, windows: [toplevel] }
    readonly property var items: {
        const tops = Hypr.toplevels;
        const used = new Set();
        const res = [];
        for (const id of pinned) {
            const entry = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
            const wins = tops.filter(t => matches(t, id, entry));
            wins.forEach(w => used.add(w));
            res.push({ id: id, entry: entry, pinned: true, windows: wins });
        }
        const extra = new Map();
        for (const t of tops) {
            if (used.has(t))
                continue;
            const cls = Hypr.classOf(t);
            if (!cls)
                continue;
            const entry = DesktopEntries.heuristicLookup(cls);
            const id = entry?.id ?? cls;
            if (!extra.has(id))
                extra.set(id, { id: id, entry: entry, pinned: false, windows: [] });
            extra.get(id).windows.push(t);
        }
        return res.concat([...extra.values()]);
    }

    // Стабильный список id для Repeater (ScriptModel не пересоздаёт делегаты, если id те же)
    readonly property var ids: items.map(i => i.id)

    function get(id: string): var {
        return items.find(i => i.id === id) ?? { id: id, entry: null, pinned: false, windows: [] };
    }

    function matches(t, id: string, entry): bool {
        const cls = Hypr.classOf(t);
        if (!cls)
            return false;
        if (cls === id.toLowerCase())
            return true;
        if (entry?.startupClass && cls === entry.startupClass.toLowerCase())
            return true;
        const guess = DesktopEntries.heuristicLookup(cls);
        return !!guess && !!entry && guess.id === entry.id;
    }

    function isPinned(id: string): bool {
        return pinned.includes(id);
    }

    function pin(id: string): void {
        if (!isPinned(id)) {
            pinned = pinned.concat([id]);
            save();
        }
    }

    function unpin(id: string): void {
        pinned = pinned.filter(p => p !== id);
        save();
    }

    function move(id: string, to: int): void {
        const arr = pinned.filter(p => p !== id);
        arr.splice(Math.max(0, Math.min(to, arr.length)), 0, id);
        pinned = arr;
        save();
    }

    function save(): void {
        store.setText(JSON.stringify({ pinned: pinned }, null, 2) + "\n");
    }

    // Запуск с прыжком иконки: прыгает, пока не появится окно (но не дольше 6 с)
    function launch(item): void {
        if (!item.entry)
            return;
        item.entry.execute();
        const l = Object.assign({}, launching);
        l[item.id] = Date.now();
        launching = l;
        launchTick++;
    }

    function isLaunching(id: string): bool {
        launchTick; // зависимость для привязок
        const t = launching[id];
        return !!t && Date.now() - t < 6000;
    }

    // Открыть или переключиться: клик по запущенному — фокус следующего его окна
    function activate(item): void {
        if (item.windows.length === 0) {
            launch(item);
            return;
        }
        const wins = item.windows;
        const idx = wins.findIndex(w => w === Hypr.active);
        const next = wins[(idx + 1) % wins.length];
        Hypr.focusWindow(next.address);
    }

    onItemsChanged: {
        // Окно появилось — перестаём прыгать
        let changed = false;
        const l = Object.assign({}, launching);
        for (const it of items)
            if (l[it.id] && it.windows.length > 0) {
                delete l[it.id];
                changed = true;
            }
        if (changed) {
            launching = l;
            launchTick++;
        }
    }

    Timer {
        interval: 6100
        running: Object.keys(root.launching).length > 0
        onTriggered: {
            root.launching = {};
            root.launchTick++;
        }
    }

    FileView {
        id: store
        path: root.file
        onLoaded: {
            try {
                root.pinned = JSON.parse(text()).pinned ?? root.defaults;
            } catch (e) {
                root.pinned = root.defaults;
            }
        }
        onLoadFailed: {
            root.pinned = root.defaults;
            root.save();
        }
    }
}
