pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code в острове: что он делает сейчас, токены и чат. Данные шлёт мод task-notify:
//   qs -c sosna ipc call claude activity "Читает Media.qml" 48213 <сессия>
//   qs -c sosna ipc call claude user "текст запроса" <сессия>
//   qs -c sosna ipc call claude reply "ответ" 48213 <сессия>
//   qs -c sosna ipc call claude done <сессия>
// Сообщение из острова кладём в ~/.cache/sosna/claude-inbox-<сессия>.txt — мод забирает его
// и отправляет в ту сессию как обычный запрос.
Singleton {
    id: root

    property bool working: false
    property string activity: ""
    property int tokens: 0
    property string sid: ""
    property var messages: []            // [{ role: "user" | "claude", text }]
    property bool hold: false            // чат развёрнут — не прятать
    readonly property bool present: working || linger.running || hold

    // 48213 → «48k», 9400 → «9.4k»
    function fmtTokens(n: int): string {
        if (n < 1000)
            return String(n);
        return (n / 1000).toFixed(n < 10000 ? 1 : 0) + "k";
    }

    function push(role: string, text: string): void {
        const m = messages.slice(-39);
        // Своё сообщение из острова мод присылает обратно — второй раз не добавляем
        if (role === "user" && m.length && m[m.length - 1].role === "user" && m[m.length - 1].text === text)
            return;
        m.push({ role: role, text: text });
        messages = m;
    }

    function send(text: string): void {
        text = text.trim();
        if (!text || !sid)
            return;
        push("user", text);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.cache/sosna\" && printf '%s' \"$1\" > \"$HOME/.cache/sosna/claude-inbox-$0.txt\"", sid, text]);
        activity = "Отправлено…";
        working = true;
        stale.restart();
    }

    IpcHandler {
        target: "claude"

        function activity(text: string, tokens: int, sid: string): void {
            root.sid = sid;
            root.activity = text;
            if (tokens > 0)
                root.tokens = tokens;
            root.working = true;
            stale.restart();
        }
        function user(text: string, sid: string): void {
            root.sid = sid;
            root.push("user", text);
        }
        function reply(text: string, tokens: int, sid: string): void {
            root.sid = sid;
            if (tokens > 0)
                root.tokens = tokens;
            root.push("claude", text);
        }
        function done(sid: string): void {
            root.sid = sid;
            root.working = false;
            root.activity = "Готово";
            stale.stop();
            linger.restart();
        }
    }

    // После ответа остров ещё немного держит Claude — чтобы успеть развернуть и ответить
    Timer {
        id: linger
        interval: 120000
    }

    // Claude закрыли посреди хода или он долго ждёт подтверждения — гасим сами
    Timer {
        id: stale
        interval: 600000
        onTriggered: root.working = false
    }
}
