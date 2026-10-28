pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Какие панели открыты + горячие клавиши (hl.dsp.global("sosna:…")) + IPC
Singleton {
    id: root

    property bool spotlightOpen: false
    property string spotlightPrefix: ""
    property bool controlOpen: false
    property bool notifOpen: false
    property bool logoOpen: false
    property bool aboutOpen: false
    property bool wallOpen: false
    property bool missionOpen: false
    property bool switcherOpen: false
    property bool dockReveal: false
    property bool powerAsk: false
    property bool settingsOpen: false
    property string settingsPage: "general"
    property bool soundOpen: false
    // Меню значка трея
    property var trayItem: null
    property real trayX: 0
    // Анимация входа: false → панели спрятаны, true → выехали
    property bool entered: false

    readonly property bool popupOpen: controlOpen || notifOpen || logoOpen || aboutOpen || wallOpen || powerAsk || trayItem !== null

    function closePopups(): void {
        controlOpen = notifOpen = logoOpen = aboutOpen = wallOpen = powerAsk = false;
        trayItem = null;
    }

    function openTray(item, x: real): void {
        const same = trayItem === item;
        closeAll();
        if (!same) {
            trayX = x;
            trayItem = item;
        }
    }

    function closeAll(): void {
        closePopups();
        spotlightOpen = missionOpen = switcherOpen = false;
    }

    function toggle(name: string): void {
        const was = root[name];
        closeAll();
        root[name] = !was;
    }

    function spotlight(prefix: string): void {
        const was = spotlightOpen;
        closeAll();
        spotlightPrefix = prefix;
        spotlightOpen = !was || prefix !== "";
    }

    function openSettings(page: string): void {
        closeAll();
        settingsPage = page || "general";
        settingsOpen = true;
    }

    // Звук — раздел Настроек (свой вместо pavucontrol)
    function openSound(): void {
        openSettings("sound");
    }

    function enter(): void {
        entered = false;
        enterTimer.interval = Config.o.startupAnim ? 250 : 1;
        enterTimer.restart();
    }

    Timer {
        id: enterTimer
        interval: 250
        onTriggered: {
            root.entered = true;
            if (Config.o.startupSound)
                Sounds.play("chime");
        }
    }

    Component.onCompleted: enter()

    GlobalShortcut {
        appid: "sosna"
        name: "spotlight"
        description: "Spotlight"
        onPressed: root.spotlight("")
    }
    // Одиночный Win: открываем на отпускание, если между нажатием и отпусканием не было других клавиш
    property bool superUsed: false
    GlobalShortcut {
        appid: "sosna"
        name: "spotlightTap"
        description: "Spotlight (Win)"
        onReleased: {
            if (!root.superUsed && !Hypr.fullscreen)
                root.spotlight("");
            root.superUsed = false;
        }
    }
    GlobalShortcut {
        appid: "sosna"
        name: "spotlightCancel"
        onPressed: root.superUsed = true
    }
    GlobalShortcut {
        appid: "sosna"
        name: "clipboard"
        description: "История буфера"
        onPressed: root.spotlight(";")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "emoji"
        description: "Эмодзи"
        onPressed: root.spotlight(":")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "control"
        description: "Центр управления"
        onPressed: root.toggle("controlOpen")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "notifs"
        description: "Центр уведомлений"
        onPressed: root.toggle("notifOpen")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "mission"
        description: "Mission Control"
        onPressed: root.toggle("missionOpen")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "switcher"
        description: "Переключатель окон"
        onPressed: {
            if (root.switcherOpen)
                root.switcherNext();
            else {
                root.closeAll();
                root.switcherOpen = true;
            }
        }
    }
    GlobalShortcut {
        appid: "sosna"
        name: "switcherPrev"
        onPressed: {
            if (root.switcherOpen)
                root.switcherPrev();
            else {
                root.closeAll();
                root.switcherOpen = true;
            }
        }
    }
    GlobalShortcut {
        appid: "sosna"
        name: "switcherDone"
        onReleased: if (root.switcherOpen) root.switcherDone()
        onPressed: if (root.switcherOpen) root.switcherDone()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "settings"
        description: "Настройки Сосны"
        onPressed: root.settingsOpen ? (root.settingsOpen = false) : root.openSettings("")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "sound"
        description: "Звук"
        onPressed: root.settingsOpen && root.settingsPage === "sound" ? (root.settingsOpen = false) : root.openSound()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "power"
        description: "Выключение"
        onPressed: {
            root.closeAll();
            root.powerAsk = true;
        }
    }
    GlobalShortcut {
        appid: "sosna"
        name: "lock"
        description: "Заблокировать"
        onPressed: Session.lock()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "about"
        description: "Об этой Сосне"
        onPressed: root.toggle("aboutOpen")
    }
    GlobalShortcut {
        appid: "sosna"
        name: "media"
        description: "Пауза/play"
        onPressed: Media.toggle()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "mediaNext"
        onPressed: Media.next()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "mediaPrev"
        onPressed: Media.prev()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "record"
        description: "Запись экрана"
        onPressed: Recorder.toggle()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "focus"
        description: "Фокус-таймер"
        onPressed: Focus.toggle()
    }
    GlobalShortcut {
        appid: "sosna"
        name: "dock"
        description: "Показать док"
        onPressed: root.dockReveal = !root.dockReveal
    }

    signal switcherNext
    signal switcherPrev
    signal switcherDone

    IpcHandler {
        target: "ui"
        function spotlight(prefix: string): void {
            root.spotlight(prefix);
        }
        function toggle(name: string): void {
            root.toggle(name + "Open");
        }
        function settings(page: string): void {
            root.openSettings(page);
        }
        function sound(): void {
            root.openSound();
        }
        function close(): void {
            root.closeAll();
        }
        function openSettings(page: string): void {
        closeAll();
        settingsPage = page || "general";
        settingsOpen = true;
    }

    // Звук — раздел Настроек (свой вместо pavucontrol)
    function openSound(): void {
        openSettings("sound");
    }

    function enter(): void {
            root.enter();
        }
    }
}
