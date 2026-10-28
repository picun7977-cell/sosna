pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Что играет + синхронный текст песни с lrclib.net (scripts/lyrics.py)
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? lastPlayed ?? players[0] ?? null
    property MprisPlayer lastPlayed: null

    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0
    property real position: 0
    readonly property bool hasTrack: !!player && title.length > 0

    // Текст песни
    property var lyrics: []          // [{ t: секунды, text: строка }]
    property int line: -1
    property string lyricsState: "none" // none | loading | ok | plain | missing
    property string plainLyrics: ""     // текст без таймингов (если синхронного нет)
    property int retries: 0
    readonly property bool hasLyrics: lyricsState === "ok" && lyrics.length > 0
    readonly property string currentLine: hasLyrics && line >= 0 ? lyrics[line].text : ""
    // Сколько строки уже спето (0…1). LRCLIB даёт время только начала строк, поэтому
    // растягиваем до следующей строки, но не дольше, чем её реально можно спеть (~0,11 с на букву)
    readonly property real lineProgress: {
        if (!hasLyrics || line < 0)
            return 0;
        const start = lyrics[line].t;
        const gap = line + 1 < lyrics.length ? lyrics[line + 1].t - start : 5;
        const dur = Math.max(0.8, Math.min(gap - 0.15, Math.max(1.5, currentLine.length * 0.11)));
        return Math.max(0, Math.min(1, (position + 0.25 - start) / dur));
    }
    property var cache: ({})
    property string trackKey: ""

    function toggle(): void {
        player?.togglePlaying();
    }
    function next(): void {
        player?.next();
    }
    function prev(): void {
        player?.previous();
    }
    function seek(sec: real): void {
        if (player?.canSeek)
            player.position = sec;
    }

    function fmt(s: real): string {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    onPlayingChanged: if (playing) lastPlayed = player
    onTitleChanged: loadLyrics()
    onArtistChanged: loadLyrics()

    // Позиция Mpris сама не обновляется — опрашиваем, пока играет
    Timer {
        running: root.playing
        interval: 200
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.player.positionChanged();
            root.position = root.player.position;
            root.updateLine();
        }
    }

    function updateLine(): void {
        if (!hasLyrics) {
            line = -1;
            return;
        }
        const p = position + 0.25;
        let i = line >= 0 && lyrics[line].t <= p ? line : 0;
        while (i + 1 < lyrics.length && lyrics[i + 1].t <= p)
            i++;
        line = lyrics[0].t > p ? -1 : i;
    }

    function parseLrc(lrc: string): var {
        const out = [];
        for (const raw of lrc.split("\n")) {
            // matchAll в движке Qt нет — собираем метки времени через exec
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            const tags = [];
            let m;
            while ((m = re.exec(raw)) !== null)
                tags.push(m);
            if (!tags.length)
                continue;
            const text = raw.replace(/\[[^\]]*\]/g, "").trim();
            for (const m of tags)
                out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: text || "♪" });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    // SoundCloud часто кладёт «Исполнитель - Название» в title
    function splitTitle(): var {
        let a = artist, t = title;
        const m = t.match(/^(.+?)\s+[-–—]\s+(.+)$/);
        if (m) {
            a = m[1];
            t = m[2];
        }
        t = t.replace(/\s*[\(\[](official|lyric|audio|video|prod|feat|ft)[^\)\]]*[\)\]]/gi, "").trim();
        return { artist: a, title: t };
    }

    function loadLyrics(): void {
        const key = artist + "\u0001" + title;
        if (key === trackKey)
            return;
        trackKey = key;
        line = -1;
        retries = 0;
        retryTimer.stop();
        plainLyrics = "";
        if (!title) {
            lyrics = [];
            lyricsState = "none";
            return;
        }
        if (cache[key]) {
            setLyrics(cache[key].lines, cache[key].plain);
            return;
        }
        lyrics = [];
        lyricsState = "loading";
        lookupTimer.restart(); // ждём, пока метаданные «устаканятся»
    }

    Timer {
        id: lookupTimer
        interval: 600
        onTriggered: root.request()
    }

    // lrclib недоступен (нет сети, блокировка, перегрузка) — это не «текста нет», пробуем позже
    Timer {
        id: retryTimer
        interval: 20000
        onTriggered: root.request()
    }

    function setLyrics(lines: var, plain: string): void {
        lyrics = lines;
        plainLyrics = lines.length ? "" : plain;
        lyricsState = lines.length ? "ok" : plain ? "plain" : "missing";
        updateLine();
    }

    // Поиск — в scripts/lyrics.py: lrclib напрямую, иначе через локальный прокси (Throne, Happ…),
    // найденное кэшируется на диске и потом работает без сети
    function request(): void {
        // Ещё ищем текст прошлого трека — запросим этот сразу после
        if (lyricsProc.running) {
            lyricsProc.pending = true;
            return;
        }
        const q = splitTitle();
        lyricsProc.key = trackKey;
        lyricsProc.command = ["python3", Quickshell.shellDir + "/scripts/lyrics.py", q.artist, q.title, String(Math.round(length)), Config.o.lyricsProxy];
        lyricsProc.running = true;
    }

    Process {
        id: lyricsProc
        property string key
        property bool pending: false
        onRunningChanged: if (!running && pending) {
            pending = false;
            root.request();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (lyricsProc.key !== root.trackKey)
                    return;
                let res;
                try {
                    res = JSON.parse(text);
                } catch (e) {
                    res = { status: "error" };
                }
                if (res.status === "error") {
                    if (root.retries++ < 6)
                        retryTimer.restart();
                    else
                        root.setLyrics([], "");
                    return;
                }
                const parsed = res.synced ? root.parseLrc(res.synced) : [];
                root.cache[lyricsProc.key] = { lines: parsed, plain: res.plain ?? "" };
                root.setLyrics(parsed, res.plain ?? "");
            }
        }
    }
}
