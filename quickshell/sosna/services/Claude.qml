pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code в острове: что он делает сейчас, контекст и чат. Данные шлёт мод task-notify:
//   qs -c sosna ipc call claude activity "Читает Media.qml" 48213 <сессия>
//   qs -c sosna ipc call claude user "текст запроса" <сессия>
//   qs -c sosna ipc call claude reply "ответ" 48213 <сессия>
//   qs -c sosna ipc call claude done <сессия>
//   qs -c sosna ipc call claude meta <сессия> "папка" 48213 24     — контекст: токены и %
//   qs -c sosna ipc call claude out <сессия> 3214                   — написано за ход (↓ у спиннера)
//   qs -c sosna ipc call claude bye <сессия>                       — сессия закрылась
// Сообщение из острова кладём в ~/.cache/sosna/claude-inbox-<сессия>.txt — мод забирает его
// и отправляет в ту сессию как обычный запрос.
// Открыто несколько Claude — остров показывает последнюю (где был последний запрос),
// остальные копят своё молча; в развёрнутом чате между ними можно переключаться.
Singleton {
    id: root

    // ── Показанная сессия ──
    property string sid: ""
    property bool working: false
    property string activity: ""
    property int tokens: 0
    property int percent: -1             // заполнение контекста, -1 — мод не прислал
    property int out: -1                 // токенов написано за ход, как «↓ 3.2k tokens» в терминале; -1 — старый мод
    // Переписка показанной сессии. ListModel, а не массив: при новом сообщении список
    // не пересоздаётся и не прыгает наверх, пока его листаешь
    readonly property ListModel messages: ListModel {}
    property bool hold: false            // чат развёрнут — не прятать и не перескакивать
    readonly property bool present: working || linger.running || hold

    // ── Все сессии: sid → { name, working, activity, tokens, percent, at, chat: [{ role, text }] } ──
    property var store: ({})
    // Для переключателя: [{ sid, name, working, at, hint }] в порядке появления — вкладки не прыгают
    property var sessions: []

    // 48213 → «48k», 9400 → «9.4k»
    function fmtTokens(n: int): string {
        if (n < 1000)
            return String(n);
        return (n / 1000).toFixed(n < 10000 ? 1 : 0) + "k";
    }

    function entry(s: string): var {
        if (!store[s])
            store[s] = { name: "", working: false, activity: "", tokens: 0, percent: -1, out: -1, at: Date.now(), chat: [] };
        return store[s];
    }

    function relist(): void {
        const l = [];
        for (const s in store) {
            const e = store[s];
            // Закрыли без «bye» (убили терминал) — через 6 часов тишины забываем
            if (s !== sid && Date.now() - e.at > 21600000) {
                delete store[s];
                continue;
            }
            const last = e.chat.filter(m => m.role === "user").pop();
            l.push({ sid: s, name: e.name || "Claude", working: e.working, at: e.at, hint: last ? last.text : "" });
        }
        sessions = l;
    }

    // Показать сессию s: состояние берём из её записи
    function show(s: string): void {
        const e = entry(s);
        sid = s;
        // Долго молчит посреди хода — Claude закрыли или он ждёт подтверждения
        working = e.working && Date.now() - e.at < stale.interval;
        activity = e.activity;
        tokens = e.tokens;
        percent = e.percent;
        out = e.out;
        messages.clear();
        for (const m of e.chat)
            messages.append(m);
        if (working)
            stale.restart();
    }

    // Выбор в переключателе
    function select(s: string): void {
        if (s !== sid && store[s])
            show(s);
    }

    // Событие от сессии s: true — это показанная сессия (при нужде переключаемся на неё).
    // force — новый запрос: перескакиваем, если только чат не развёрнут на другой сессии
    function take(s: string, force: bool): bool {
        entry(s).at = Date.now();
        if (s === sid)
            return true;
        if (present && !(force && !hold))
            return false;
        show(s);
        return true;
    }

    function push(s: string, role: string, text: string): void {
        const e = entry(s);
        const m = e.chat;
        // Своё сообщение из острова мод присылает обратно — второй раз не добавляем
        if (role === "user" && m.length && m[m.length - 1].role === "user" && m[m.length - 1].text === text)
            return;
        m.push({ role: role, text: text });
        while (m.length > 40)
            m.shift();
        if (s === sid) {
            messages.append({ role: role, text: text });
            while (messages.count > m.length)
                messages.remove(0);
        }
        relist();
    }

    // Состояние хода сессии s; в остров — только если она показана
    function state(s: string, isWorking: bool, text: string, n: int): void {
        const e = entry(s);
        e.working = isWorking;
        e.activity = text;
        if (n > 0)
            e.tokens = n;
        if (s === sid) {
            working = isWorking;
            activity = text;
            tokens = e.tokens;
        }
        relist();
    }

    function send(text: string): void {
        text = text.trim();
        if (!text || !sid)
            return;
        push(sid, "user", text);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.cache/sosna\" && printf '%s' \"$1\" > \"$HOME/.cache/sosna/claude-inbox-$0.txt\"", sid, text]);
        state(sid, true, "Отправлено…", 0);
        stale.restart();
    }

    IpcHandler {
        target: "claude"

        function activity(text: string, tokens: int, sid: string): void {
            const shown = root.take(sid, false);
            root.state(sid, true, text, tokens);
            if (shown)
                stale.restart();
        }
        // Новый запрос — эта сессия становится последней
        function user(text: string, sid: string): void {
            root.take(sid, true);
            root.push(sid, "user", text);
        }
        function reply(text: string, tokens: int, sid: string): void {
            root.take(sid, false);
            const e = root.entry(sid);
            if (tokens > 0) {
                e.tokens = tokens;
                if (sid === root.sid)
                    root.tokens = tokens;
            }
            root.push(sid, "claude", text);
        }
        function done(sid: string): void {
            const shown = root.take(sid, false);
            root.state(sid, false, "Готово", 0);
            if (shown) {
                stale.stop();
                linger.restart();
            }
        }
        // Точный контекст сессии — те же цифры, что в строке состояния Claude Code
        function meta(sid: string, name: string, tokens: int, percent: int): void {
            const e = root.entry(sid);
            e.name = name;
            e.tokens = tokens;
            e.percent = percent;
            if (sid === root.sid) {
                root.tokens = tokens;
                root.percent = percent;
            } else if (root.sid === "") {
                root.show(sid);
            }
            root.relist();
        }
        function out(sid: string, n: int): void {
            root.entry(sid).out = n;
            if (sid === root.sid)
                root.out = n;
        }
        function bye(sid: string): void {
            delete root.store[sid];
            root.relist();
            if (sid !== root.sid)
                return;
            linger.stop();
            stale.stop();
            if (root.sessions.length) {
                // Закрыли показанную — переходим на самую свежую из оставшихся
                root.show(root.sessions.reduce((a, b) => b.at > a.at ? b : a).sid);
            } else {
                root.sid = "";
                root.working = false;
                root.activity = "";
                root.tokens = 0;
                root.percent = -1;
                root.out = -1;
                root.messages.clear();
            }
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
        onTriggered: {
            root.working = false;
            if (root.store[root.sid])
                root.store[root.sid].working = false;
            root.relist();
        }
    }
}
