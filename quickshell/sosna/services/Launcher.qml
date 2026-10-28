pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Данные для Spotlight: программы с историей запусков, команды Сосны, калькулятор (qalc),
// эмодзи, файлы (fd), история буфера (cliphist) и веб-поиск.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string thumbDir: home + "/.cache/sosna/clip"

    property var history: ({})        // id программы → сколько раз запускали
    property var emojis: []           // [{ e, k }]
    property var clips: []            // [{ id, text, image, w, h }]
    property int clipTick: 0          // меняется, когда готовы миниатюры
    property bool thumbsReady: false
    property var files: []            // пути
    property bool filesBusy: false
    property string calc: ""          // ответ qalc
    property string calcFor: ""

    // ───────────── Программы ─────────────
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    // Набрано в русской раскладке вместо английской: «ашкуащч» → «firefox»
    readonly property string ru: "йцукенгшщзхъфывапролджэячсмитьбю."
    readonly property string en: "qwertyuiop[]asdfghjkl;'zxcvbnm,./"
    function translit(s: string): string {
        let out = "";
        for (const ch of s) {
            const i = ru.indexOf(ch);
            out += i >= 0 ? en[i] : ch;
        }
        return out;
    }

    function scoreText(t: string, q: string): int {
        if (!t)
            return 0;
        t = t.toLowerCase();
        if (t === q)
            return 120;
        if (t.startsWith(q))
            return 100;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 80;
        if (t.includes(q))
            return 60;
        // Буквы по порядку: «vsc» → «Visual Studio Code»
        let j = 0;
        for (const ch of t)
            if (ch === q[j] && ++j === q.length)
                return 25;
        return 0;
    }

    function scoreApp(a, q: string): int {
        let s = Math.max(scoreText(a.name, q), scoreText(a.genericName, q) * 0.7, scoreText(a.id, q) * 0.8, (a.keywords ?? []).reduce((m, k) => Math.max(m, scoreText(k, q) * 0.6), 0));
        if (s > 0)
            s += Math.min(30, (history[a.id] ?? 0) * 3);
        return s;
    }

    function searchApps(q: string): var {
        q = q.toLowerCase().trim();
        if (!q) {
            // Все программы: сначала частые, потом по алфавиту
            const top = Object.keys(history).sort((x, y) => history[y] - history[x]).map(id => apps.find(a => a.id === id)).filter(a => !!a).slice(0, 7);
            const rest = apps.filter(a => !top.includes(a)).sort((x, y) => x.name.localeCompare(y.name, "ru"));
            return top.concat(rest).map(appItem);
        }
        const alt = translit(q);
        return apps.map(a => ({ a: a, s: Math.max(scoreApp(a, q), alt !== q ? scoreApp(a, alt) - 5 : 0) }))
            .filter(x => x.s > 0)
            .sort((x, y) => y.s - x.s)
            .slice(0, 12)
            .map(x => appItem(x.a));
    }

    function appItem(a): var {
        return {
            kind: "app",
            icon: a.icon,
            title: a.name,
            sub: a.genericName || a.comment || "Программа",
            id: a.id,
            run: () => root.launch(a),
            pin: () => root.togglePin(a)
        };
    }

    function togglePin(a): void {
        const pinned = DockModel.isPinned(a.id);
        pinned ? DockModel.unpin(a.id) : DockModel.pin(a.id);
        Island.show("text", { title: pinned ? "Убрано из Дока" : "Закреплено в Доке", body: a.name, icon: pinned ? "keep_off" : "keep" }, 1600);
    }

    function launch(a): void {
        const h = Object.assign({}, history);
        h[a.id] = (h[a.id] ?? 0) + 1;
        history = h;
        historyFile.setText(JSON.stringify(h) + "\n");
        const it = DockModel.get(a.id);
        if (it.entry)
            DockModel.launch(it);
        else
            a.execute();
    }

    // ───────────── Команды Сосны ─────────────
    readonly property var commands: [
        { g: "lock", t: "Заблокировать экран", k: "lock блок замок", run: () => Session.lock() },
        { g: "bedtime", t: "Сон", k: "sleep suspend сон спать", run: () => Session.suspend() },
        { g: "restart_alt", t: "Перезагрузить", k: "reboot restart перезагрузка", run: () => Ui.powerAsk = true },
        { g: "power_settings_new", t: "Выключить", k: "poweroff shutdown выключение", run: () => Ui.powerAsk = true },
        { g: "logout", t: "Завершить сеанс", k: "logout выйти выход", run: () => Session.logout() },
        { g: "grid_view", t: "Mission Control", k: "mission окна рабочие столы", run: () => Ui.missionOpen = true },
        { g: "tune", t: "Центр управления", k: "control центр", run: () => Ui.controlOpen = true },
        { g: "notifications", t: "Центр уведомлений", k: "notifications уведомления календарь", run: () => Ui.notifOpen = true },
        { g: "settings", t: "Настройки Сосны", k: "settings настройки параметры", run: () => Ui.openSettings("") },
        { g: "graphic_eq", t: "Звук", k: "sound audio звук громкость колонки микрофон", run: () => Ui.openSound() },
        { g: "wallpaper", t: "Обои", k: "wallpaper обои фон", run: () => Ui.wallOpen = true },
        { g: "screenshot_region", t: "Снимок области", k: "screenshot скриншот снимок область", run: () => Shot.pick() },
        { g: "screenshot_monitor", t: "Снимок экрана", k: "screenshot скриншот снимок экран", run: () => Shot.full() },
        { g: "radio_button_checked", t: Recorder.active ? "Остановить запись" : "Запись экрана", k: "record запись видео", run: () => Recorder.toggle() },
        { g: "timer", t: Focus.running ? "Остановить фокус" : "Фокус 25 минут", k: "focus фокус помодоро таймер", run: () => Focus.toggle() },
        { g: "colorize", t: "Пипетка", k: "color picker цвет пипетка", run: () => Shot.pickColor() },
        { g: "nightlight", t: Night.on ? "Выключить ночной свет" : "Включить ночной свет", k: "night ночной свет", run: () => Night.toggle() },
        { g: "do_not_disturb_on", t: Notifs.dnd ? "Выключить «Не беспокоить»" : "Не беспокоить", k: "dnd беспокоить тишина", run: () => Notifs.dnd = !Notifs.dnd },
        { g: "coffee", t: Idle.coffee ? "Разрешить блокировку" : "Кофе — не блокировать", k: "coffee кофе блокировка", run: () => Idle.coffee = !Idle.coffee },
        { g: "info", t: "Об этой Сосне", k: "about сосна система", run: () => Ui.aboutOpen = true },
        { g: "hourglass", t: "Экранное время", k: "screen time экранное время статистика", run: () => Ui.openSettings("screentime") },
        { g: "content_paste", t: "История буфера", k: "clipboard буфер", run: () => Ui.spotlight(";") },
        { g: "mood", t: "Эмодзи", k: "emoji эмодзи смайлы", run: () => Ui.spotlight(":") },
        { g: "delete_sweep", t: "Очистить историю буфера", k: "clipboard clear буфер очистить", run: () => Quickshell.execDetached(["cliphist", "wipe"]) },
        { g: "refresh", t: "Перезапустить Сосну", k: "restart reload сосна перезапуск", run: () => Quickshell.execDetached(["sh", "-c", "qs -c sosna kill; sleep .3; " + root.home + "/.local/bin/sosna-start"]) }
    ]

    function searchCommands(q: string, shell: bool): var {
        q = q.toLowerCase().trim();
        const alt = translit(q);
        const res = commands.map(c => ({ c: c, s: q ? Math.max(scoreText(c.t, q), scoreText(c.k, q), scoreText(c.k, alt)) : 1 }))
            .filter(x => x.s > 0)
            .sort((x, y) => y.s - x.s)
            .map(x => ({ kind: "cmd", glyph: x.c.g, title: x.c.t, sub: "Команда Сосны", run: x.c.run }));
        if (shell && q)
            res.push({ kind: "cmd", glyph: "terminal", title: "Выполнить: " + q, sub: "В терминале foot", run: () => Quickshell.execDetached(["foot", "--hold", "sh", "-c", q]) });
        return res;
    }

    // ───────────── Калькулятор ─────────────
    function looksLikeMath(q: string): bool {
        return /^[\d\s.,+\-*\/^()%x×÷]+$/.test(q) && /\d/.test(q) && /[+\-*\/^%×÷]/.test(q);
    }

    function compute(q: string): void {
        q = q.trim();
        if (q === calcFor)
            return;
        calcFor = q;
        calc = "";
        if (!q)
            return;
        calcProc.command = ["qalc", "-t", "--", q.replace(/×/g, "*").replace(/÷/g, "/")];
        calcDebounce.restart();
    }

    // ───────────── Эмодзи ─────────────
    // Русские слова → английские ключи из списка эмодзи
    readonly property var emojiRu: ({
        "смех": "joy laugh rofl", "ржу": "rofl joy", "лол": "joy rofl", "улыб": "smil grin", "грус": "sad cry pensive", "плак": "cry sob", "слез": "cry tear",
        "любов": "heart love kiss", "серд": "heart", "сердеч": "heart", "поцел": "kiss", "огонь": "fire", "огон": "fire", "ок": "ok", "класс": "thumbs up",
        "лайк": "thumbs up", "палец": "thumbs", "дизлайк": "thumbs down", "спасиб": "pray", "молит": "pray", "хлоп": "clap", "сил": "muscle flex",
        "кот": "cat", "кош": "cat", "соба": "dog", "пёс": "dog", "пес": "dog", "лис": "fox", "медвед": "bear", "панд": "panda", "мыш": "mouse", "зая": "rabbit", "заяц": "rabbit",
        "сосн": "evergreen tree", "ёлк": "christmas tree evergreen", "елк": "christmas tree evergreen", "дерев": "tree", "цвет": "flower", "роз": "rose",
        "солн": "sun", "луна": "moon", "звезд": "star", "снег": "snow", "дожд": "rain", "облак": "cloud", "молни": "lightning zap", "радуг": "rainbow",
        "череп": "skull", "умер": "skull dead", "клоун": "clown", "какаш": "poop", "привидени": "ghost", "призрак": "ghost", "робот": "robot", "инопланет": "alien",
        "глаз": "eye", "думат": "thinking", "дума": "thinking", "шок": "scream shock", "злой": "angry rage", "злост": "angry rage", "крут": "sunglasses cool",
        "спат": "sleep zzz", "сон": "sleep zzz", "рук": "hand", "привет": "wave", "пока": "wave", "праздн": "party tada", "вечерин": "party", "подар": "gift",
        "торт": "cake", "пицц": "pizza", "кофе": "coffee", "пиво": "beer", "еда": "food", "яблок": "apple", "деньг": "money dollar", "день": "money",
        "игр": "game video", "музык": "music note", "нот": "note music", "машин": "car", "ракет": "rocket", "дом": "house home", "флаг": "flag",
        "росси": "russia", "галоч": "check", "галк": "check", "крест": "cross x", "вопрос": "question", "восклиц": "exclamation", "часы": "clock watch",
        "телефон": "phone", "комп": "computer laptop", "книг": "book", "ручк": "pen", "замок": "lock", "ключ": "key", "лампоч": "bulb", "идея": "bulb",
        "ноль": "zero", "сто": "100", "100": "100", "искр": "sparkles", "блест": "sparkles", "вау": "astonished wow", "подмиг": "wink", "язык": "tongue",
        "стыд": "flushed", "ангел": "angel halo", "дьявол": "devil imp", "черт": "devil imp", "корон": "crown", "алмаз": "gem diamond", "мяч": "ball"
    })

    function searchEmoji(q: string): var {
        q = q.toLowerCase().trim();
        let keys = [q];
        if (/[а-яё]/.test(q)) {
            keys = [];
            for (const ru in emojiRu)
                if (q.startsWith(ru) || ru.startsWith(q) && q.length >= 3)
                    keys = keys.concat(emojiRu[ru].split(" "));
            if (keys.length === 0)
                return [];
        }
        const list = q ? emojis.filter(e => keys.some(k => e.k.includes(k))) : emojis;
        return list.slice(0, 160).map(e => ({ kind: "emoji", emoji: e.e, title: e.k, sub: "", run: () => root.copy(e.e, e.e) }));
    }

    // ───────────── Файлы ─────────────
    function findFiles(q: string): void {
        q = q.trim();
        filesProc.running = false;
        if (q.length < 2) {
            files = [];
            return;
        }
        filesProc.command = ["fd", "-i", "--max-results", "60", "--exclude", ".cache", "--exclude", "node_modules", "--", q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), home];
        filesDebounce.restart();
    }

    function fileGlyph(p: string): string {
        const ext = p.split(".").pop().toLowerCase();
        if (p.endsWith("/"))
            return "folder";
        if (["png", "jpg", "jpeg", "webp", "gif", "svg"].includes(ext))
            return "image";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext))
            return "music_note";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext))
            return "movie";
        if (["pdf", "doc", "docx", "odt", "txt", "md"].includes(ext))
            return "description";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "zst"].includes(ext))
            return "folder_zip";
        if (["js", "ts", "py", "qml", "lua", "rs", "c", "cpp", "java", "sh", "json"].includes(ext))
            return "code";
        return "draft";
    }

    function isImage(p: string): bool {
        return /\.(png|jpe?g|webp|gif)$/i.test(p);
    }

    function fileItems(q: string): var {
        const lq = q.toLowerCase().trim();
        return files.map(p => {
            const clean = p.replace(/\/$/, "");
            const name = clean.split("/").pop();
            return { p: p, name: name, s: name.toLowerCase().startsWith(lq) ? 2 : name.toLowerCase().includes(lq) ? 1 : 0, depth: clean.split("/").length };
        }).sort((a, b) => b.s - a.s || a.depth - b.depth).slice(0, 30).map(f => ({
            kind: "file",
            glyph: fileGlyph(f.p),
            image: isImage(f.p) ? "file://" + f.p : "",
            title: f.name,
            sub: f.p.replace(home, "~").replace(/\/$/, ""),
            run: () => Quickshell.execDetached(["xdg-open", f.p]),
            alt: () => Quickshell.execDetached(["thunar", f.p.replace(/\/[^\/]*\/?$/, "")])
        }));
    }

    // ───────────── Буфер обмена ─────────────
    function loadClips(): void {
        clipProc.running = true;
    }

    function clipItems(q: string): var {
        q = q.toLowerCase().trim();
        clipTick;
        return clips.filter(c => !q || (!c.image && c.text.toLowerCase().includes(q)) || (c.image && "картинка изображение image".includes(q)))
            .slice(0, 60)
            .map(c => ({
                kind: "clip",
                glyph: c.image ? "hourglass_top" : /^https?:\/\//.test(c.text) ? "link" : "notes",
                image: c.image ? (thumbsReady ? "file://" + thumbDir + "/" + c.id + ".png" : "") : "",
                title: c.image ? "Изображение " + c.w + "×" + c.h : c.text.replace(/\s+/g, " ").slice(0, 200),
                full: c.image ? "" : c.text,
                sub: c.image ? "Картинка из буфера" : c.text.length + " симв.",
                run: () => Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$0\" | cliphist decode | wl-copy", c.id]),
                del: () => {
                    Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$0\" | cliphist delete", c.id]);
                    root.clips = root.clips.filter(x => x.id !== c.id);
                }
            }));
    }

    // ───────────── Веб ─────────────
    function webItems(q: string): var {
        q = q.trim();
        const e = encodeURIComponent(q);
        const sites = [
            ["travel_explore", "Google", "https://www.google.com/search?q="],
            ["smart_display", "YouTube", "https://www.youtube.com/results?search_query="],
            ["menu_book", "Википедия", "https://ru.wikipedia.org/w/index.php?search="],
            ["code", "GitHub", "https://github.com/search?q="],
            ["translate", "Переводчик", "https://translate.google.com/?sl=auto&tl=ru&text="]
        ];
        if (!q)
            return sites.map(s => ({ kind: "web", glyph: s[0], title: s[1], sub: "Напиши запрос", run: () => {} }));
        const res = sites.map(s => ({ kind: "web", glyph: s[0], title: q, sub: "Искать: " + s[1], run: () => Quickshell.execDetached(["xdg-open", s[2] + e]) }));
        if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(q))
            res.unshift({ kind: "web", glyph: "public", title: q, sub: "Открыть сайт", run: () => Quickshell.execDetached(["xdg-open", "https://" + q]) });
        return res;
    }

    function copy(text: string, shown: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        Island.show("text", { title: "Скопировано", body: shown, icon: "content_copy" }, 1600);
    }

    // ───────────── Процессы и файлы ─────────────
    FileView {
        id: historyFile
        path: root.home + "/.cache/sosna/launches.json"
        onLoaded: {
            try {
                root.history = JSON.parse(text());
            } catch (e) {}
        }
    }

    FileView {
        path: Quickshell.shellDir + "/assets/emojis.txt"
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const i = line.indexOf(" ");
                if (i > 0)
                    out.push({ e: line.slice(0, i), k: line.slice(i + 1).toLowerCase() });
            }
            root.emojis = out;
        }
    }

    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: calcProc.running = true
    }

    Process {
        id: calcProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                root.calc = r && !/error|warning/i.test(r) ? r : "";
            }
        }
    }

    Timer {
        id: filesDebounce
        interval: 160
        onTriggered: {
            root.filesBusy = true;
            filesProc.running = true;
        }
    }

    Process {
        id: filesProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(s => s.length > 0);
                root.filesBusy = false;
            }
        }
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const imgs = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const id = line.slice(0, tab);
                    const body = line.slice(tab + 1);
                    const m = body.match(/^\[\[ binary data .* (png|jpeg|jpg|webp|bmp) (\d+)x(\d+) \]\]$/);
                    if (m) {
                        out.push({ id: id, text: "", image: true, w: m[2], h: m[3] });
                        if (imgs.length < 40)
                            imgs.push(id);
                    } else if (!body.startsWith("[[ binary")) {
                        out.push({ id: id, text: body, image: false });
                    }
                    if (out.length >= 300)
                        break;
                }
                root.clips = out;
                if (imgs.length > 0) {
                    root.thumbsReady = false;
                    thumbProc.command = ["sh", "-c", "d=\"$0\"; mkdir -p \"$d\"; for id in \"$@\"; do [ -s \"$d/$id.png\" ] || printf '%s\\t\\n' \"$id\" | cliphist decode > \"$d/$id.png\"; done", root.thumbDir].concat(imgs);
                    thumbProc.running = true;
                }
            }
        }
    }

    Process {
        id: thumbProc
        onExited: {
            root.thumbsReady = true;
            root.clipTick++;
        }
    }
}
