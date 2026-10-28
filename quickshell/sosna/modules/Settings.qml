import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// «Настройки Сосны» — отдельное окно в духе Системных настроек macOS.
// Разделы слева, справа — группы строк с переключателями и ползунками. Всё пишется в Config (settings.json).
Scope {
    id: root

    readonly property var pages: [
        { id: "general", n: "Основные", g: "settings", c: "#8e8e93" },
        { id: "appearance", n: "Внешний вид", g: "palette", c: "#5e5ce6" },
        { id: "dock", n: "Док", g: "dock_to_bottom", c: "#0a84ff" },
        { id: "island", n: "Остров", g: "pill", c: "#1c1c1e" },
        { id: "desktop", n: "Рабочий стол", g: "widgets", c: "#30b0c7" },
        { id: "sound", n: "Звук", g: "volume_up", c: "#ff375f" },
        { id: "display", n: "Экран", g: "brightness_6", c: "#ff9f0a" },
        { id: "screentime", n: "Экранное время", g: "hourglass_bottom", c: "#bf5af2" },
        { id: "weather", n: "Погода", g: "partly_cloudy_day", c: "#64d2ff" },
        { id: "keys", n: "Клавиши", g: "keyboard", c: "#636366" },
        { id: "about", n: "О Сосне", g: "park", c: "#30d158" }
    ]

    LazyLoader {
        active: Ui.settingsOpen

        FloatingWindow {
            id: win

            title: "Сосна · Настройки"
            implicitWidth: 940
            implicitHeight: 640
            minimumSize: Qt.size(760, 480)
            color: "transparent"
            visible: true
            onVisibleChanged: if (!visible) Ui.settingsOpen = false

            Rectangle {
                anchors.fill: parent
                color: Theme.glassStrong
                radius: 0

                // ───── Боковая панель ─────
                Rectangle {
                    id: side
                    width: 230
                    height: parent.height
                    color: Qt.rgba(0, 0, 0, 0.22)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.topMargin: 18
                        spacing: 2

                        // Профиль
                        Row {
                            spacing: 10
                            bottomPadding: 14
                            leftPadding: 4
                            ClippingRectangle {
                                width: 42
                                height: 42
                                radius: 21
                                color: Theme.tile
                                Image {
                                    anchors.fill: parent
                                    source: Config.avatar
                                    sourceSize: Qt.size(84, 84)
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: avatarPick.running = true
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Label { text: Config.userName; weight: Font.Bold; size: 14 }
                                Label { text: "Сосна · " + Weather.city; dim: true; size: 11.5 }
                            }
                        }

                        Repeater {
                            model: root.pages
                            delegate: Rectangle {
                                id: navItem
                                required property var modelData
                                readonly property bool cur: Ui.settingsPage === modelData.id
                                width: parent.width
                                height: 34
                                radius: 8
                                color: cur ? Theme.accent : navMouse.containsMouse ? Theme.tile : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: navItem.modelData.c
                                        scale: navMouse.containsMouse ? 1.1 : 1
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        Icon {
                                            anchors.centerIn: parent
                                            text: navItem.modelData.g
                                            size: 15
                                            fill: true
                                            color: "white"
                                        }
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: navItem.modelData.n
                                        size: 13
                                        color: navItem.cur ? Theme.inkOnAccent : Theme.text
                                    }
                                }
                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Ui.settingsPage = navItem.modelData.id
                                }
                            }
                        }
                    }
                }

                // ───── Содержимое ─────
                Flickable {
                    id: flick
                    anchors.left: side.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    contentHeight: page.implicitHeight + 60
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: page
                        x: 28
                        y: 22
                        width: flick.width - 56
                        spacing: 14

                        Label {
                            text: root.pages.find(p => p.id === Ui.settingsPage)?.n ?? ""
                            size: 22
                            weight: Font.Bold
                        }

                        Loader {
                            id: pageLoader
                            width: parent.width
                            sourceComponent: ({
                                general: pGeneral, appearance: pAppearance, dock: pDock, island: pIsland, desktop: pDesktop,
                                sound: pSound, display: pDisplay, screentime: pTime, weather: pWeather, keys: pKeys, about: pAbout
                            })[Ui.settingsPage] ?? pGeneral
                            onLoaded: {
                                flick.contentY = 0;
                                item.opacity = 0;
                                fadeIn.restart();
                            }
                            NumberAnimation {
                                id: fadeIn
                                target: pageLoader.item
                                property: "opacity"
                                to: 1
                                duration: 200
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════ Разделы ═════════════

    Component {
        id: pGeneral
        Column {
            spacing: 14
            Group {
                Row2 {
                    title: "Аватар"
                    sub: "Картинка на экране блокировки, в Центре управления и здесь"
                    ClippingRectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.tile
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            source: Config.avatar
                            sourceSize: Qt.size(80, 80)
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                        }
                    }
                    Btn { text: "Выбрать…"; accent: true; onClicked: avatarPick.running = true }
                }
                Row2 {
                    title: "Имя"
                    Field { width: 180; text: Config.userName; onEdited: t => { if (t.trim()) Config.o.userName = t.trim(); } }
                }
            }
            Group {
                Toggle { title: "Системные звуки"; sub: "Затвор, уведомления, разблокировка"; key: "sounds" }
                Toggle { title: "Звук при входе"; key: "startupSound" }
                Toggle { title: "Анимация входа"; sub: "Строка меню и док выезжают при запуске"; key: "startupAnim" }
            }
            Group {
                Choice {
                    title: "Блокировать экран"
                    sub: "После простоя (если не включён «Кофе»)"
                    key: "lockAfter"
                    options: [{ v: 300, t: "5 мин" }, { v: 600, t: "10 мин" }, { v: 1800, t: "30 мин" }, { v: 0, t: "Никогда" }]
                }
                Row2 {
                    title: "Кофе"
                    sub: "Пока включён, экран не гаснет и не блокируется"
                    Switch { on: Idle.coffee; onToggled: Idle.coffee = !Idle.coffee }
                }
            }
            Group {
                Toggle { title: "Горячий угол"; sub: "Мышь в левый верхний угол экрана"; key: "hotCorner" }
                Choice {
                    title: "Действие угла"
                    key: "hotCornerAction"
                    options: [{ v: "mission", t: "Mission Control" }, { v: "spotlight", t: "Spotlight" }, { v: "control", t: "Центр упр." }, { v: "lock", t: "Блокировка" }]
                }
                Toggle { title: "Встряхни мышь"; sub: "Курсор увеличивается, если его потерял"; key: "shake" }
            }
        }
    }

    Component {
        id: pAppearance
        Column {
            spacing: 14
            Group {
                Row2 {
                    title: "Акцентный цвет"
                    sub: Config.o.accent ? Config.o.accent : "Из обоев (" + Wall.accent + ")"
                    Row {
                        spacing: 7
                        Repeater {
                            model: ["", "#0a84ff", "#bf5af2", "#ff375f", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#8e8e93"]
                            delegate: Rectangle {
                                id: swatch
                                required property string modelData
                                readonly property bool cur: Config.o.accent === modelData
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData || Wall.accent
                                border.width: cur ? 2 : 0
                                border.color: "white"
                                scale: sw.containsMouse ? 1.2 : 1
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Icon {
                                    visible: swatch.modelData === ""
                                    anchors.centerIn: parent
                                    text: "wallpaper"
                                    size: 13
                                    color: Theme.inkOnAccent
                                }
                                MouseArea {
                                    id: sw
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.o.accent = swatch.modelData
                                }
                            }
                        }
                    }
                }
                Toggle { title: "Скруглённые углы экрана"; key: "cornersRound" }
                SliderRow { title: "Радиус углов"; key: "cornerRadius"; from: 6; to: 28; step: 1; unit: " пк" }
                Toggle { title: "Погода на обоях"; sub: "Снег и дождь, когда они идут в городе"; key: "weatherFx" }
            }
            Label { text: "Обои"; weight: Font.Bold; size: 14 }
            Grid {
                width: parent.width
                columns: 4
                spacing: 10
                Repeater {
                    model: Wall.all
                    delegate: ClippingRectangle {
                        id: wallCell
                        required property string modelData
                        readonly property bool cur: Wall.path === modelData
                        width: (parent.width - 30) / 4
                        height: width * 0.6
                        radius: 10
                        color: Theme.tile
                        border.width: cur ? 3 : 0
                        border.color: Theme.accent
                        scale: wm.containsMouse ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Image {
                            anchors.fill: parent
                            source: "file://" + wallCell.modelData
                            sourceSize: Qt.size(320, 200)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea {
                            id: wm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wall.set(wallCell.modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pDock
        Column {
            spacing: 14
            Group {
                SliderRow { title: "Размер значков"; key: "dockIcon"; from: 36; to: 72; step: 1; unit: " пк" }
                Toggle { title: "Увеличение при наведении"; key: "dockMagnify" }
                SliderRow { title: "Сила увеличения"; key: "dockMaxScale"; from: 1.2; to: 2.2; step: 0.05; unit: "×"; digits: 2 }
                Toggle { title: "Прятать док, когда есть окна"; sub: "Подведи мышь к нижнему краю — выедет"; key: "dockAutohide" }
            }
            Label { text: "Справа в доке"; weight: Font.Bold; size: 14 }
            Group {
                Toggle { title: "Загрузки"; sub: "Стопка последних файлов"; key: "dockDownloads" }
                Repeater {
                    model: Config.o.dockFolders ?? []
                    delegate: Row2 {
                        required property string modelData
                        title: modelData.split("/").pop() || modelData
                        sub: modelData.replace(Quickshell.env("HOME"), "~")
                        Btn { text: "Убрать"; onClicked: Config.o.dockFolders = Config.o.dockFolders.filter(p => p !== parent.parent.modelData) }
                    }
                }
                Row2 {
                    title: "Добавить папку или файл"
                    sub: "Или перетащи её из Файлов прямо на док"
                    Btn {
                        text: "Выбрать…"
                        accent: true
                        onClicked: folderPick.running = true
                    }
                }
            }
            Label { text: "Закреплённые программы"; weight: Font.Bold; size: 14 }
            Label { width: parent.width; text: "Порядок меняется перетаскиванием в самом доке, а убрать значок можно, вытащив его вверх. Добавить — Spotlight → правый клик по программе."; dim: true; size: 12; wrapMode: Text.Wrap }
            Group {
                Repeater {
                    model: DockModel.pinned
                    delegate: Row2 {
                        id: pinRow
                        required property string modelData
                        readonly property var entry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)
                        title: entry?.name ?? modelData
                        icon: entry?.icon ?? modelData
                        Btn { text: "Убрать"; onClicked: DockModel.unpin(pinRow.modelData) }
                    }
                }
                Row2 {
                    title: "Добавить программу"
                    Btn {
                        text: "Открыть Spotlight"
                        accent: true
                        onClicked: Ui.spotlight("")
                    }
                }
            }
        }
    }

    Component {
        id: pIsland
        Column {
            spacing: 14
            Group {
                Toggle { title: "Прятать в играх"; sub: "Когда окно на весь экран, остров уезжает"; key: "islandHideFullscreen" }
                Toggle { title: "Текст песни"; sub: "Синхронные строки из LRCLIB"; key: "islandLyrics" }
            }
            Group {
                Toggle { title: "Жизнь в покое"; sub: "Когда ничего не играет: погода и сосенка по очереди"; key: "islandIdle" }
                Toggle { title: "Сосенка-тамагочи"; sub: "Растёт, пока ты работаешь, и грустит без внимания"; key: "islandPet" }
            }
            Group {
                Row2 {
                    title: "Обратный отсчёт"
                    sub: "Показывается в карточке «Сегодня» (клик по острову)"
                    Field { width: 150; text: Config.o.countdownTitle; onEdited: t => Config.o.countdownTitle = t }
                    Field { width: 110; text: Config.o.countdownDate; placeholder: "ГГГГ-ММ-ДД"; onEdited: t => { if (/^\d{4}-\d{2}-\d{2}$/.test(t)) Config.o.countdownDate = t; } }
                }
            }
        }
    }

    Component {
        id: pDesktop
        Column {
            spacing: 14
            Group {
                Toggle { title: "Секунды в часах строки меню"; key: "barSeconds" }
                Toggle { title: "Дата в строке меню"; key: "barDate" }
            }
            Group {
                Toggle { title: "Виджеты на рабочем столе"; sub: "Перетаскиваются мышью, двойной клик — на место"; key: "widgets" }
            }
            Group {
                Toggle { title: "Часы"; key: "wClock" }
                Toggle { title: "Погода"; key: "wWeather" }
                Toggle { title: "Календарь"; key: "wCalendar" }
                Toggle { title: "Музыка"; key: "wMusic" }
                Toggle { title: "Система"; sub: "ЦП, видеокарта, память"; key: "wSystem" }
                Toggle { title: "Экранное время"; key: "wScreenTime" }
                Toggle { title: "Заметка"; key: "wNote" }
            }
            Group {
                Row2 {
                    title: "Расставить по умолчанию"
                    Btn { text: "Сбросить"; onClicked: Config.o.widgetPos = {} }
                }
            }
        }
    }

    Component {
        id: pSound
        Column {
            spacing: 14
            Label { text: "Выход"; weight: Font.Bold; size: 14 }
            Group {
                Repeater {
                    model: Audio.sinks
                    delegate: Device {
                        required property var modelData
                        node: modelData
                        current: Audio.sink === modelData
                        glyph: (modelData.description ?? "").toLowerCase().includes("hdmi") ? "tv" : /head|науш|temple/i.test(modelData.description ?? "") ? "headphones" : "speaker"
                        onPicked: Audio.setDefaultSink(modelData)
                    }
                }
            }
            Group {
                Row2 {
                    title: "Громкость"
                    Slider {
                        width: 300
                        value: Audio.muted ? 0 : Audio.volume
                        icon: Audio.muted ? "volume_off" : "volume_up"
                        onMoved: v => Audio.setVolume(v)
                    }
                }
                Row2 {
                    title: "Без звука"
                    Switch { on: Audio.muted; onToggled: Audio.toggleMute() }
                }
            }

            Label { text: "Вход"; weight: Font.Bold; size: 14 }
            Group {
                Repeater {
                    model: Audio.sources
                    delegate: Device {
                        required property var modelData
                        node: modelData
                        current: Audio.source === modelData
                        glyph: "mic"
                        onPicked: Audio.setDefaultSource(modelData)
                    }
                }
                Row2 {
                    title: "Чувствительность микрофона"
                    Slider {
                        width: 300
                        value: Audio.micMuted ? 0 : Audio.micVolume
                        icon: Audio.micMuted ? "mic_off" : "mic"
                        onMoved: v => Audio.setMic(v)
                    }
                }
            }

            Label { text: "Программы"; weight: Font.Bold; size: 14 }
            Label { visible: Audio.players.length === 0; text: "Сейчас ничего не играет"; dim: true; size: 12.5 }
            Group {
                visible: Audio.players.length > 0
                Repeater {
                    model: Audio.players
                    delegate: Row2 {
                        id: appRow
                        required property var modelData
                        title: Audio.appName(modelData)
                        sub: modelData.properties?.["media.name"] ?? ""
                        icon: Audio.appIcon(modelData)
                        HoverButton {
                            width: 30
                            height: 30
                            radius: 15
                            onClicked: appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                            Icon {
                                anchors.centerIn: parent
                                text: appRow.modelData.audio?.muted ? "volume_off" : "volume_up"
                                size: 18
                                color: appRow.modelData.audio?.muted ? Theme.red : Theme.text
                            }
                        }
                        Slider {
                            width: 220
                            value: appRow.modelData.audio?.muted ? 0 : (appRow.modelData.audio?.volume ?? 0)
                            icon: "graphic_eq"
                            onMoved: v => {
                                appRow.modelData.audio.muted = false;
                                appRow.modelData.audio.volume = v;
                            }
                        }
                        Label { width: 34; text: Math.round((appRow.modelData.audio?.volume ?? 0) * 100) + "%"; size: 11.5; dim: true; mono: true; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
            PwObjectTracker {
                objects: Audio.players
            }
            Group {
                Toggle { title: "Звуки Сосны"; sub: "Затвор, уведомления, «пуф» в доке"; key: "sounds" }
            }
        }
    }

    Component {
        id: pDisplay
        Column {
            spacing: 14
            Group {
                Row2 {
                    title: "Яркость монитора"
                    sub: Brightness.bus >= 0 ? "По DDC/CI · " + Math.round(Brightness.value * 100) + "%" : "Ищу монитор…"
                    Slider {
                        width: 300
                        value: Brightness.value
                        icon: "brightness_6"
                        onMoved: v => Brightness.set(v)
                    }
                }
            }
            Group {
                Row2 {
                    title: "Ночной свет"
                    sub: Night.on ? Night.temp + " K" : "Выключен"
                    Switch { on: Night.on; onToggled: Night.toggle() }
                }
                Row2 {
                    title: "Теплота"
                    Slider {
                        width: 300
                        value: (6500 - Night.temp) / 3500
                        icon: "wb_twilight"
                        fill: Night.on ? Theme.orange : Theme.text
                        onMoved: v => Night.setTemp(Math.round((6500 - v * 3500) / 100) * 100)
                    }
                }
            }
        }
    }

    Component {
        id: pTime
        Column {
            spacing: 14
            Group {
                Toggle { title: "Считать экранное время"; sub: "Сколько каждая программа была в фокусе (без простоя)"; key: "screenTime" }
            }
            Row {
                spacing: 12
                Label { text: "Сегодня"; weight: Font.Bold; size: 14 }
                Label { text: ScreenTime.fmt(ScreenTime.total); size: 14; color: Theme.accent; weight: Font.DemiBold }
            }
            // Неделя столбиками
            Rectangle {
                id: weekBox
                width: parent.width
                height: 150
                radius: 12
                color: Theme.tile
                readonly property var week: {
                    const res = [];
                    const now = new Date();
                    for (let i = 6; i >= 0; i--) {
                        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
                        const k = Qt.formatDate(d, "yyyy-MM-dd");
                        const day = ScreenTime.data[k] ?? {};
                        res.push({ k: k, t: Object.values(day).reduce((a, b) => a + b, 0), n: ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"][d.getDay()] });
                    }
                    return res;
                }
                readonly property real max: Math.max(3600, ...week.map(w => w.t))
                Row {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: (width - 7 * 40) / 6
                    Repeater {
                        model: weekBox.week
                        delegate: Column {
                            required property var modelData
                            required property int index
                            width: 40
                            spacing: 4
                            anchors.bottom: parent.bottom
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t > 0 ? Math.round(modelData.t / 360) / 10 + "ч" : ""; size: 10.5; dim: true }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 26
                                height: Math.max(3, 86 * modelData.t / weekBox.max)
                                radius: 6
                                color: index === 6 ? Theme.accent : Theme.alpha(Theme.accent, 0.4)
                                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n; size: 11; color: index === 6 ? Theme.text : Theme.text2 }
                        }
                    }
                }
            }
            Group {
                Repeater {
                    model: ScreenTime.top.slice(0, 12)
                    delegate: Row2 {
                        id: stRow
                        required property var modelData
                        title: modelData.name
                        icon: modelData.icon
                        Rectangle {
                            width: 220
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.1)
                            Rectangle {
                                width: parent.width * stRow.modelData.sec / Math.max(1, ScreenTime.top[0].sec)
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                            }
                        }
                        Label { width: 80; text: ScreenTime.fmt(stRow.modelData.sec); size: 12; dim: true; horizontalAlignment: Text.AlignRight }
                    }
                }
                Row2 {
                    visible: ScreenTime.top.length === 0
                    title: "Пока пусто"
                    sub: "Время считается каждые 5 секунд"
                }
            }
        }
    }

    Component {
        id: pWeather
        Column {
            id: wcol
            spacing: 14
            property var found: []
            Group {
                Row2 {
                    title: "Город"
                    sub: Weather.ready ? Weather.signed(Weather.temp) + " · " + Weather.desc : "Загружаю…"
                    Label { text: Config.o.city; weight: Font.DemiBold; size: 14 }
                }
                Row2 {
                    title: "Найти другой"
                    Field {
                        width: 240
                        placeholder: "Например, Москва"
                        onEdited: t => {
                            if (t.trim().length < 2)
                                return;
                            const xhr = new XMLHttpRequest();
                            xhr.onreadystatechange = () => {
                                if (xhr.readyState !== XMLHttpRequest.DONE)
                                    return;
                                try {
                                    wcol.found = JSON.parse(xhr.responseText).results ?? [];
                                } catch (e) {
                                    wcol.found = [];
                                }
                            };
                            xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=ru&name=" + encodeURIComponent(t.trim()));
                            xhr.send();
                        }
                    }
                }
                Repeater {
                    model: wcol.found
                    delegate: Row2 {
                        id: cityRow
                        required property var modelData
                        title: modelData.name
                        sub: [modelData.admin1, modelData.country].filter(x => !!x).join(", ")
                        Btn {
                            text: "Выбрать"
                            accent: true
                            onClicked: {
                                Config.o.city = cityRow.modelData.name;
                                Config.o.lat = cityRow.modelData.latitude;
                                Config.o.lon = cityRow.modelData.longitude;
                                wcol.found = [];
                                Weather.refresh();
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pKeys
        Column {
            spacing: 14
            Group {
                Repeater {
                    model: [
                        ["Win", "Spotlight и все программы"], ["Win + Space", "Spotlight"], ["Win + V", "История буфера"], ["Win + .", "Эмодзи"],
                        ["Win + Tab", "Mission Control"], ["Alt + Tab", "Переключение окон"], ["Win + K", "Центр управления"],
                        ["Win + B", "Центр уведомлений"], ["Win + ,", "Настройки Сосны"], ["Ctrl + Alt + V", "Звук"], ["Win + L", "Заблокировать"],
                        ["Win + Shift + S", "Снимок области"], ["Print", "Снимок экрана"], ["Win + Shift + C", "Пипетка"], ["Win + Alt + R", "Запись экрана"],
                        ["Win + F1 / F2", "Яркость монитора"], ["Ctrl + Alt + Delete", "Выключение"], ["Ctrl + Win + Alt + R", "Перезапустить Сосну"]
                    ]
                    delegate: Row2 {
                        id: keyRow
                        required property var modelData
                        title: modelData[1]
                        Rectangle {
                            width: keyL.implicitWidth + 16
                            height: 24
                            radius: 6
                            color: Theme.tile
                            border.width: 1
                            border.color: Theme.hairline
                            Label { id: keyL; anchors.centerIn: parent; text: keyRow.modelData[0]; mono: true; size: 11.5 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pAbout
        Column {
            spacing: 14
            Item {
                width: parent.width
                height: 150
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Pine { anchors.horizontalCenter: parent.horizontalCenter; width: 64; height: 64 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Сосна"; size: 22; weight: Font.Bold }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Своя оболочка на Quickshell · Hyprland"; dim: true; size: 12.5 }
                }
            }
            Group {
                Row2 { title: "Настройки"; sub: "~/.config/sosna/settings.json — можно править руками" }
                Row2 { title: "Код"; sub: "~/.config/quickshell/sosna" }
                Row2 {
                    title: "Вернуть всё как было"
                    sub: "uninstall.sh из репозитория Сосны (или своя команда отката, если делал бэкап)"
                }
                Row2 {
                    title: "Перезапустить Сосну"
                    Btn { text: "Перезапустить"; onClicked: Quickshell.execDetached(["sh", "-c", "qs -c sosna kill; sleep .3; " + Quickshell.env("HOME") + "/.local/bin/sosna-start"]) }
                }
            }
        }
    }

    // Выбор аватара: картинка копируется в ~/.config/sosna/avatar.<расширение>
    Process {
        id: avatarPick
        command: ["zenity", "--file-selection", "--title=Аватар", "--file-filter=Картинки | *.png *.jpg *.jpeg *.webp *.gif", "--filename=" + Quickshell.env("HOME") + "/Pictures/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (!p)
                    return;
                const dest = Quickshell.env("HOME") + "/.config/sosna/avatar." + (p.split(".").pop().toLowerCase() || "png");
                avatarCopy.dest = dest;
                avatarCopy.command = ["cp", "-f", p, dest];
                avatarCopy.running = true;
            }
        }
    }
    Process {
        id: avatarCopy
        property string dest
        onExited: code => {
            if (code === 0) {
                Config.o.avatar = "";
                Config.o.avatar = dest;
            }
        }
    }

    // Выбор папки для дока
    Process {
        id: folderPick
        command: ["zenity", "--file-selection", "--directory", "--title=Папка для Дока", "--filename=" + Quickshell.env("HOME") + "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p && !(Config.o.dockFolders ?? []).includes(p))
                    Config.o.dockFolders = (Config.o.dockFolders ?? []).concat([p]);
            }
        }
    }

    // ═════════════ Кирпичики ═════════════

    // Группа строк на «плитке» с тонкими разделителями
    component Group: Rectangle {
        id: grp
        default property alias rows: col.data
        width: parent ? parent.width : 400
        height: col.implicitHeight
        radius: 12
        color: Theme.tile
        border.width: 1
        border.color: Theme.hairline
        Column {
            id: col
            width: parent.width
        }
    }

    // Строка: значок, заголовок, подпись слева; справа — свои элементы
    component Row2: Item {
        id: r
        property string title
        property string sub
        property string icon
        default property alias controls: ctl.data
        width: parent ? parent.width : 400
        height: Math.max(sub ? 56 : 46, ctl.implicitHeight + 16)
        Rectangle {
            anchors.bottom: parent.bottom
            x: 14
            width: parent.width - 28
            height: 1
            color: Theme.hairline
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Image {
                visible: r.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                sourceSize: Qt.size(128, 128)
                source: r.icon ? Quickshell.iconPath(r.icon, "application-x-executable") : ""
                smooth: true
                mipmap: true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: r.width - ctl.width - 70 - (r.icon ? 36 : 0)
                Label { width: parent.width; text: r.title; size: 13 }
                Label { width: parent.width; visible: r.sub !== ""; text: r.sub; size: 11.5; dim: true }
            }
        }
        Row {
            id: ctl
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    // Переключатель как на маке
    component Switch: Rectangle {
        id: sw
        property bool on: false
        signal toggled
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 42
        height: 24
        radius: 12
        color: on ? Theme.accent : Theme.alpha(Theme.text, 0.18)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: 2
            x: sw.on ? 20 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
        }
        scale: swm.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        MouseArea {
            id: swm
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component Toggle: Row2 {
        id: tg
        property string key
        Switch {
            on: !!Config.o[tg.key]
            onToggled: Config.o[tg.key] = !Config.o[tg.key]
        }
    }

    component SliderRow: Row2 {
        id: sr
        property string key
        property real from: 0
        property real to: 1
        property real step: 0.01
        property string unit: ""
        property int digits: 0
        Slider {
            width: 240
            anchors.verticalCenter: parent.verticalCenter
            value: (Config.o[sr.key] - sr.from) / (sr.to - sr.from)
            icon: ""
            onMoved: v => {
                const raw = sr.from + v * (sr.to - sr.from);
                Config.o[sr.key] = Math.round(raw / sr.step) * sr.step;
            }
        }
        Label {
            width: 52
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Number(Config.o[sr.key]).toFixed(sr.digits) + sr.unit
            size: 12
            mono: true
            dim: true
        }
    }

    // Сегменты
    component Choice: Row2 {
        id: ch
        property string key
        property var options: []
        Rectangle {
            width: segRow.implicitWidth + 4
            height: 28
            radius: 8
            color: Theme.alpha(Theme.text, 0.08)
            Row {
                id: segRow
                x: 2
                y: 2
                Repeater {
                    model: ch.options
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool cur: Config.o[ch.key] === modelData.v
                        width: segL.implicitWidth + 20
                        height: 24
                        radius: 6
                        color: cur ? Theme.accent : segM.containsMouse ? Theme.tile : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Label {
                            id: segL
                            anchors.centerIn: parent
                            text: parent.modelData.t
                            size: 12
                            color: parent.cur ? Theme.inkOnAccent : Theme.text
                        }
                        MouseArea {
                            id: segM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.o[ch.key] = parent.modelData.v
                        }
                    }
                }
            }
        }
    }

    component Btn: HoverButton {
        id: b
        property string text
        property bool accent: false
        width: bl.implicitWidth + 24
        height: 28
        radius: 8
        hoverScale: 1.05
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: accent ? (hovered ? Theme.mix(Theme.accent, Qt.color("#ffffff"), 0.15) : Theme.accent) : (hovered ? Theme.tileHover : Theme.alpha(Theme.text, 0.1))
        Label {
            id: bl
            anchors.centerIn: parent
            text: b.text
            size: 12.5
            color: b.accent ? Theme.inkOnAccent : Theme.text
        }
    }

    component Field: Rectangle {
        id: f
        property alias text: ti.text
        property string placeholder
        signal edited(string t)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 28
        radius: 7
        color: Theme.alpha(Theme.text, 0.08)
        border.width: 1
        border.color: ti.activeFocus ? Theme.accent : Theme.hairline
        TextInput {
            id: ti
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            selectByMouse: true
            clip: true
            onAccepted: f.edited(text)
            onEditingFinished: f.edited(text)
            Text {
                visible: !ti.text && !ti.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: f.placeholder
                color: Theme.text3
                font: ti.font
            }
        }
    }

    // Устройство звука: выбор кружком
    component Device: Row2 {
        id: dev
        property var node
        property bool current: false
        property string glyph: "speaker"
        signal picked
        title: node?.description || node?.nickname || node?.name || "Устройство"
        sub: current ? "Используется" : ""
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: dev.glyph
            size: 20
            color: dev.current ? Theme.accent : Theme.text2
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: "transparent"
            border.width: 2
            border.color: dev.current ? Theme.accent : Theme.alpha(Theme.text, 0.3)
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: Theme.accent
                scale: dev.current ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }
        }
        MouseArea {
            width: dev.width
            height: dev.height
            parent: dev
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.picked()
        }
    }
}
