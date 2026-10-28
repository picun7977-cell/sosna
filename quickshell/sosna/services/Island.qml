pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Состояние «острова». Есть короткие события (громкость, раскладка, уведомление…)
// и постоянные режимы (запись, фокус, Эби, музыка). Событие на время перекрывает режим.
Singleton {
    id: root

    property string event: ""        // volume | layout | caps | notif | claude | shot | color | text
    property var data: ({})
    property bool hovered: false
    property bool pinnedOpen: false   // развёрнут кликом

    property bool forceIdle: false   // для проверки сцен: qs -c sosna ipc call island idle <сцена>
    readonly property string mode: {
        if (forceIdle)
            return "idle";
        if (Recorder.active)
            return "rec";
        if (Abi.state !== "idle")
            return "abi";
        if (Focus.running)
            return "focus";
        if (Media.hasTrack)
            return "music";
        return "idle";
    }

    // Что показывать сейчас
    readonly property string view: event !== "" ? event : mode
    readonly property bool expanded: event === "" && ((hovered || pinnedOpen) && (mode === "music" || mode === "focus" || mode === "rec") || pinnedOpen && mode === "idle")

    // Сцены острова в покое — сменяют друг друга
    readonly property var scenes: {
        if (!Config.o.islandIdle)
            return ["dot"];
        const s = [];
        if (Weather.ready)
            s.push("weather");
        if (Config.o.islandPet)
            s.push("pet");
        return s.length ? s : ["dot"];
    }
    property int sceneIndex: 0
    readonly property string scene: scenes[sceneIndex % scenes.length] ?? "dot"

    Timer {
        running: root.mode === "idle" && root.event === "" && !root.hovered && !root.pinnedOpen && root.scenes.length > 1
        interval: 9000
        repeat: true
        onTriggered: root.sceneIndex = (root.sceneIndex + 1) % root.scenes.length
    }

    // Дней до события из настроек (карточка «Сегодня»)
    function countdown(): int {
        const t = new Date(Config.o.countdownDate + "T00:00:00");
        return Math.ceil((t - new Date()) / 86400000);
    }

    function show(kind: string, payload: var, ms: int): void {
        data = payload ?? {};
        event = kind;
        hideTimer.interval = ms > 0 ? ms : 2000;
        hideTimer.restart();
    }

    function dismiss(): void {
        hideTimer.stop();
        event = "";
    }

    Timer {
        id: hideTimer
        onTriggered: root.event = ""
    }

    Connections {
        target: Audio
        function onVolumeTouched(): void {
            if (!Ui.controlOpen)
                root.show("volume", {}, 1400);
        }
    }

    Connections {
        target: Hypr
        function onLayoutSwitched(from: string, to: string): void {
            root.show("layout", { from: from, to: to }, 900);
        }
        function onCapsChanged(): void {
            root.show("caps", { on: Hypr.caps }, 1100);
        }
    }

    // qs -c sosna ipc call island show "Заголовок" "текст"
    IpcHandler {
        target: "island"

        function show(title: string, body: string): void {
            root.show("text", { title: title, body: body }, 3500);
        }
        function color(hex: string): void {
            root.show("color", { hex: hex }, 2500);
        }
        function toggle(): void {
            root.pinnedOpen = !root.pinnedOpen;
        }
        function idle(scene: string): void {
            root.forceIdle = scene !== "";
            const i = root.scenes.indexOf(scene);
            if (i >= 0)
                root.sceneIndex = i;
        }
        function actions(): void {
            root.show("actions", {}, 6000);
        }
    }
}
