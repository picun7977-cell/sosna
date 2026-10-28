pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Громкость, микрофон и индикаторы приватности (кто слушает микрофон / снимает экран)
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string sinkName: sink?.description || sink?.nickname || "Звук"

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    // Устройства и программы для раздела «Звук» в Настройках
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !(n.name ?? "").endsWith(".monitor"))
    readonly property var players: streams.filter(n => n.audio && (n.properties ?? {})["media.class"] === "Stream/Output/Audio")

    function setDefaultSink(n): void {
        Pipewire.preferredDefaultAudioSink = n;
    }
    function setDefaultSource(n): void {
        Pipewire.preferredDefaultAudioSource = n;
    }
    function appName(n): string {
        const p = n.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "Программа";
    }
    function appIcon(n): string {
        const p = n.properties ?? {};
        const bin = p["application.process.binary"] ?? "";
        const e = DesktopEntries.heuristicLookup(p["application.icon_name"] || bin || p["application.name"] || "");
        return e?.icon ?? p["application.icon_name"] ?? bin;
    }

    // Приложения, которые пишут микрофон (без захвата «монитора» — так делает cava)
    readonly property var micUsers: streams.filter(n => {
        const p = n.properties ?? {};
        if (p["media.class"] !== "Stream/Input/Audio")
            return false;
        if (p["stream.capture.sink"] === "true")
            return false;
        const bin = p["application.process.binary"] ?? "";
        return !["cava", "quickshell", "qs"].includes(bin);
    }).map(n => n.properties["application.name"] ?? n.properties["application.process.binary"] ?? "Приложение")

    // Кто забирает видео (захват экрана: OBS, браузер, Discord)
    readonly property var screenUsers: streams.filter(n => (n.properties ?? {})["media.class"] === "Stream/Input/Video").map(n => n.properties["application.name"] ?? n.properties["application.process.binary"] ?? "Приложение")

    property bool ready: false
    signal volumeTouched

    function setVolume(v: real): void {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function setMic(v: real): void {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    onVolumeChanged: if (ready) volumeTouched()
    onMutedChanged: if (ready) volumeTouched()

    // Первые значения приходят при старте — их не показываем
    Timer {
        running: true
        interval: 1500
        onTriggered: root.ready = true
    }

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.streams, ...root.sinks, ...root.sources]
    }
}
