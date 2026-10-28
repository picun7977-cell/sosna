import QtQuick
import QtQuick.Layouts
import QtQuick.Particles
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// Рабочий стол: погода на обоях (снег/дождь по погоде города из настроек) и виджеты.
// Виджеты таскаются мышью, место запоминается в настройках; набор — в «Настройках Сосны».
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "sosna-desktop"
        visible: !Hypr.fullscreen

        // Мышь ловят только виджеты, остальное — сквозь
        mask: Region {
            Region { item: Config.o.widgets && Config.o.wClock ? wClock : null }
            Region { item: Config.o.widgets && Config.o.wWeather ? wWeather : null }
            Region { item: Config.o.widgets && Config.o.wCalendar ? wCalendar : null }
            Region { item: Config.o.widgets && Config.o.wMusic && Media.hasTrack ? wMusic : null }
            Region { item: Config.o.widgets && Config.o.wSystem ? wSystem : null }
            Region { item: Config.o.widgets && Config.o.wScreenTime ? wTime : null }
            Region { item: Config.o.widgets && Config.o.wNote ? wNote : null }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        Binding {
            target: SysInfo
            property: "active"
            value: Config.o.widgets && Config.o.wSystem && Hypr.wsEmpty
            when: Config.o.widgets
        }

        // ───────────── Погода на обоях ─────────────
        ParticleSystem {
            id: sky
            anchors.fill: parent
            running: Config.o.weatherFx && Weather.fx !== "none" && Hypr.wsEmpty
            visible: running
        }
        // Снег: мягкие хлопья разного размера, качаются на ветру
        Emitter {
            system: sky
            enabled: Weather.fx === "snow"
            width: parent.width
            height: 1
            y: -20
            emitRate: 28
            lifeSpan: 16000
            size: 1
            velocity: AngleDirection { angle: 90; angleVariation: 12; magnitude: 70; magnitudeVariation: 40 }
            group: "snow"
        }
        Wander {
            system: sky
            groups: ["snow"]
            xVariance: 60
            pace: 40
        }
        ItemParticle {
            system: sky
            groups: ["snow"]
            fade: true
            delegate: Rectangle {
                readonly property real s: 2 + Math.random() * 5
                width: s
                height: s
                radius: s / 2
                color: "white"
                opacity: 0.35 + Math.random() * 0.45
            }
        }
        // Дождь: тонкие косые штрихи
        Emitter {
            system: sky
            enabled: Weather.fx === "rain"
            width: parent.width + 200
            x: -100
            height: 1
            y: -40
            emitRate: 90
            lifeSpan: 1600
            size: 1
            velocity: AngleDirection { angle: 100; angleVariation: 2; magnitude: 1100; magnitudeVariation: 200 }
            group: "rain"
        }
        ItemParticle {
            system: sky
            groups: ["rain"]
            delegate: Rectangle {
                width: 1.2
                height: 18 + Math.random() * 16
                rotation: 10
                color: Qt.rgba(0.8, 0.88, 1, 0.28)
            }
        }

        // ───────────── Виджеты ─────────────
        Item {
            id: board
            anchors.fill: parent
            anchors.topMargin: Theme.barHeight
            visible: Config.o.widgets
            // Поверх окон (плавающих) — притушены
            opacity: Hypr.wsEmpty ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: 400 } }

            // Часы
            Widget {
                id: wClock
                key: "clock"
                on: Config.o.wClock
                defX: 48
                defY: 40
                width: 330
                height: 150
                Column {
                    anchors.centerIn: parent
                    spacing: -4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "hh:mm")
                        font.family: Theme.font
                        font.pixelSize: 78
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                        color: Theme.text
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const s = clock.date.toLocaleString(Qt.locale("ru_RU"), "dddd, d MMMM");
                            return s.charAt(0).toUpperCase() + s.slice(1);
                        }
                        size: 15
                        color: Theme.accent
                        weight: Font.DemiBold
                    }
                }
            }

            // Погода
            Widget {
                id: wWeather
                key: "weather"
                on: Config.o.wWeather && Weather.ready
                defX: 48
                defY: 206
                width: 330
                height: 168
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Column {
                            Layout.fillWidth: true
                            Label { text: Weather.city; weight: Font.DemiBold; size: 15 }
                            Text {
                                text: Weather.signed(Weather.temp)
                                font.family: Theme.font
                                font.pixelSize: 46
                                font.weight: Font.Light
                                color: Theme.text
                            }
                        }
                        Column {
                            Layout.alignment: Qt.AlignTop
                            Icon { anchors.right: parent.right; text: Weather.icon; size: 34; fill: true; color: Theme.accent }
                            Label { anchors.right: parent.right; text: Weather.desc; size: 12.5 }
                            Label { anchors.right: parent.right; text: "↑" + Weather.signed(Weather.max) + "  ↓" + Weather.signed(Weather.min); size: 12; dim: true }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: Weather.hours
                            delegate: Column {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.h; size: 11; dim: true }
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.iconFor(modelData.code, true); size: 17 }
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.signed(modelData.temp); size: 11.5 }
                            }
                        }
                    }
                }
            }

            // Календарь
            Widget {
                id: wCalendar
                key: "calendar"
                on: Config.o.wCalendar
                defX: 48
                defY: 390
                width: 330
                height: 232
                readonly property var months: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
                readonly property int year: clock.date.getFullYear()
                readonly property int month: clock.date.getMonth()
                readonly property int first: (new Date(year, month, 1).getDay() + 6) % 7
                readonly property int days: new Date(year, month + 1, 0).getDate()
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    Label { text: wCalendar.months[wCalendar.month]; weight: Font.Bold; size: 15; color: Theme.accent }
                    Grid {
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 1
                        Repeater {
                            model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                            delegate: Label {
                                required property string modelData
                                required property int index
                                width: 42
                                height: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                size: 11
                                color: index >= 5 ? Theme.alpha(Theme.red, 0.85) : Theme.text2
                                weight: Font.DemiBold
                            }
                        }
                        Repeater {
                            model: wCalendar.first + wCalendar.days
                            delegate: Item {
                                required property int index
                                readonly property int d: index - wCalendar.first + 1
                                readonly property bool today: d === clock.date.getDate()
                                width: 42
                                height: 26
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: Theme.accent
                                    visible: parent.today
                                }
                                Label {
                                    anchors.centerIn: parent
                                    visible: parent.d > 0
                                    text: parent.d
                                    size: 12.5
                                    weight: parent.today ? Font.Bold : Font.Medium
                                    color: parent.today ? Theme.inkOnAccent : Theme.text
                                }
                            }
                        }
                    }
                }
            }

            // Музыка
            Widget {
                id: wMusic
                key: "music"
                on: Config.o.wMusic && Media.hasTrack
                defX: board.width - 48 - width
                defY: 40
                width: 340
                height: 132
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14
                    ClippingRectangle {
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 104
                        radius: 14
                        color: Theme.tile
                        Image {
                            anchors.fill: parent
                            source: Media.art
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(208, 208)
                            asynchronous: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { Layout.fillWidth: true; text: Media.title; weight: Font.Bold; size: 15 }
                        Label { Layout.fillWidth: true; text: Media.artist; dim: true; size: 12.5 }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            spacing: 6
                            HoverButton { width: 34; height: 34; radius: 17; onClicked: Media.prev(); Icon { anchors.centerIn: parent; text: "fast_rewind"; fill: true; size: 22 } }
                            HoverButton { width: 40; height: 40; radius: 20; color: Theme.alpha(Theme.text, 0.12); onClicked: Media.toggle(); Icon { anchors.centerIn: parent; text: Media.playing ? "pause" : "play_arrow"; fill: true; size: 26 } }
                            HoverButton { width: 34; height: 34; radius: 17; onClicked: Media.next(); Icon { anchors.centerIn: parent; text: "fast_forward"; fill: true; size: 22 } }
                        }
                    }
                }
            }

            // Система
            Widget {
                id: wSystem
                key: "system"
                on: Config.o.wSystem
                defX: board.width - 48 - width
                defY: Media.hasTrack && Config.o.wMusic ? 188 : 40
                width: 340
                height: 120
                Row {
                    anchors.centerIn: parent
                    spacing: 22
                    Repeater {
                        model: [
                            { n: "ЦП", v: SysInfo.cpu, t: SysInfo.cpuTemp + "°" },
                            { n: "Видео", v: SysInfo.gpu, t: SysInfo.gpuTemp + "°" },
                            { n: "Память", v: SysInfo.ramUsed / Math.max(1, SysInfo.ramTotal), t: (SysInfo.ramUsed).toFixed(1) + " ГБ" }
                        ]
                        delegate: Column {
                            required property var modelData
                            spacing: 4
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 60
                                height: 60
                                Ring {
                                    anchors.centerIn: parent
                                    size: 60
                                    thickness: 6
                                    value: modelData.v
                                    color: modelData.v > 0.85 ? Theme.red : modelData.v > 0.6 ? Theme.orange : Theme.accent
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: Math.round(modelData.v * 100) + "%"
                                    size: 13
                                    weight: Font.Bold
                                }
                            }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n + " · " + modelData.t; size: 11; dim: true }
                        }
                    }
                }
            }

            // Экранное время
            Widget {
                id: wTime
                key: "screentime"
                on: Config.o.wScreenTime && Config.o.screenTime
                defX: board.width - 48 - width
                defY: wSystem.defY + 136
                width: 340
                height: 46 + Math.max(1, Math.min(4, ScreenTime.top.length)) * 34
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    RowLayout {
                        width: parent.width
                        Label { text: "Экранное время"; weight: Font.Bold; size: 14; Layout.fillWidth: true }
                        Label { text: ScreenTime.fmt(ScreenTime.total); size: 12.5; color: Theme.accent; weight: Font.DemiBold }
                    }
                    Label { visible: ScreenTime.top.length === 0; text: "Пока пусто — считаю…"; dim: true; size: 12 }
                    Repeater {
                        model: ScreenTime.top.slice(0, 4)
                        delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            spacing: 10
                            IconImage { implicitSize: 22; source: Quickshell.iconPath(modelData.icon, "application-x-executable") }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.name; size: 12; Layout.fillWidth: true }
                                    Label { text: ScreenTime.fmt(modelData.sec); size: 11; dim: true }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 4
                                    radius: 2
                                    color: Theme.alpha(Theme.text, 0.1)
                                    Rectangle {
                                        width: parent.width * modelData.sec / Math.max(1, ScreenTime.top[0].sec)
                                        height: parent.height
                                        radius: 2
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Заметка
            Widget {
                id: wNote
                key: "note"
                on: Config.o.wNote
                defX: board.width - 48 - width
                defY: wTime.defY + wTime.height + 16
                width: 340
                height: 150
                color: Qt.rgba(1, 0.86, 0.4, 0.16)
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    Row {
                        spacing: 6
                        Icon { text: "sticky_note_2"; size: 18; color: "#ffd66b"; fill: true }
                        Label { text: "Заметка"; weight: Font.Bold; size: 14 }
                    }
                    TextEdit {
                        id: note
                        width: parent.width
                        height: parent.height - 30
                        text: Config.o.note
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        selectionColor: Theme.alpha(Theme.accent, 0.5)
                        onTextChanged: noteSave.restart()
                        Timer {
                            id: noteSave
                            interval: 800
                            onTriggered: if (note.text !== Config.o.note) Config.o.note = note.text
                        }
                        // Клик по заметке — забираем клавиатуру
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onPressed: m => {
                                win.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                                note.forceActiveFocus();
                                m.accepted = false;
                            }
                        }
                        onActiveFocusChanged: if (!activeFocus) win.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                    }
                }
            }
        }
    }

    // Карточка виджета: стекло, появление, перетаскивание с запоминанием места
    component Widget: Glass {
        id: w

        required property string key
        property bool on: true
        property real defX: 0
        property real defY: 0
        readonly property var saved: (Config.o.widgetPos ?? {})[key]

        function place(): void {
            x = Qt.binding(() => saved ? Math.min(parent.width - width, Math.max(0, saved[0])) : defX);
            y = Qt.binding(() => saved ? Math.min(parent.height - height, Math.max(0, saved[1])) : defY);
        }
        Component.onCompleted: place()
        radius: 24
        visible: opacity > 0.01
        opacity: on ? 1 : 0
        scale: drag.drag.active ? 1.04 : hov.hovered ? 1.015 : on ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

        HoverHandler {
            id: hov
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            z: -1
            drag.target: w
            drag.threshold: 6
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
            onReleased: {
                if (!drag.active)
                    return;
                const p = Object.assign({}, Config.o.widgetPos ?? {});
                p[w.key] = [Math.round(w.x), Math.round(w.y)];
                Config.o.widgetPos = p;
                w.place();
            }
            // Двойной клик — вернуть на место по умолчанию
            onDoubleClicked: {
                const p = Object.assign({}, Config.o.widgetPos ?? {});
                delete p[w.key];
                Config.o.widgetPos = p;
                w.place();
            }
        }
    }
}
