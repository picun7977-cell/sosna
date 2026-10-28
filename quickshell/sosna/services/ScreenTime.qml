pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Экранное время: сколько секунд сегодня было в фокусе каждое приложение.
// ~/.local/state/sosna/screentime.json → { "2026-10-28": { "firefox": 3600, … }, … } (хранится 14 дней)
Singleton {
    id: root

    property var data: ({})
    property bool loaded: false
    property bool idle: false
    readonly property string today: Qt.formatDate(clock.date, "yyyy-MM-dd")
    readonly property var day: data[today] ?? {}
    readonly property int total: Object.values(day).reduce((a, b) => a + b, 0)

    // [{ cls, name, icon, sec }] по убыванию
    readonly property var top: Object.keys(day).map(cls => {
        const e = DesktopEntries.heuristicLookup(cls);
        return { cls: cls, name: e?.name ?? Hypr.prettify(cls), icon: e?.icon ?? cls, sec: day[cls] };
    }).sort((a, b) => b.sec - a.sec)

    function fmt(sec: int): string {
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
        return h > 0 ? h + " ч " + m + " мин" : m > 0 ? m + " мин" : sec + " с";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    IdleMonitor {
        timeout: 120
        onIsIdleChanged: root.idle = isIdle
    }

    Timer {
        running: Config.o.screenTime && root.loaded
        interval: 5000
        repeat: true
        onTriggered: {
            if (root.idle || Session.locked || !Hypr.active || Hypr.active.workspace?.id !== Hypr.wsId)
                return;
            const cls = Hypr.classOf(Hypr.active);
            if (!cls)
                return;
            const d = Object.assign({}, root.data);
            const t = Object.assign({}, d[root.today] ?? {});
            t[cls] = (t[cls] ?? 0) + 5;
            d[root.today] = t;
            root.data = d;
            root.dirty = true;
        }
    }

    property bool dirty: false
    Timer {
        running: root.dirty
        interval: 60000
        onTriggered: root.save()
    }

    function save(): void {
        const keys = Object.keys(data).sort().slice(-14);
        const d = {};
        for (const k of keys)
            d[k] = data[k];
        file.setText(JSON.stringify(d) + "\n");
        dirty = false;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/sosna/screentime.json"
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: {
            Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/sosna"]);
            root.loaded = true;
        }
    }
}
