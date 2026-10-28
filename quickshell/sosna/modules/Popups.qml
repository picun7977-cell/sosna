import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import qs.services
import qs.components

// Всплывающие панели строки меню: меню сосны, Центр управления, Центр уведомлений,
// «Об этой Сосне», выбор обоев и меню значков трея. Клик мимо — закрыть.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "sosna-popup"
    WlrLayershell.keyboardFocus: Ui.popupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Держим окно ещё немного после закрытия, чтобы доиграла анимация
    property bool alive: false
    visible: Ui.popupOpen || alive
    onVisibleChanged: if (visible) alive = true
    Connections {
        target: Ui
        function onPopupOpenChanged(): void {
            if (!Ui.popupOpen)
                closeTimer.restart();
            else
                win.alive = true;
        }
    }
    Timer {
        id: closeTimer
        interval: 260
        onTriggered: win.alive = false
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: Theme.barHeight
        onClicked: Ui.closePopups()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.closePopups()

        // ───────────── Меню сосны ─────────────
        Pop {
            id: logo
            open: Ui.logoOpen
            origin: Item.TopLeft
            x: 8
            y: Theme.barHeight + 4
            width: 250
            height: logoCol.implicitHeight + 10
            radius: 12

            Column {
                id: logoCol
                anchors.fill: parent
                anchors.margins: 5
                MenuRow { width: parent.width; text: "Об этой Сосне"; icon: "info"; onClicked: { Ui.closePopups(); Ui.aboutOpen = true; } }
                Separator { width: parent.width }
                MenuRow { width: parent.width; text: "Обои…"; icon: "wallpaper"; onClicked: { Ui.closePopups(); Ui.wallOpen = true; } }
                MenuRow { width: parent.width; text: "Центр управления"; icon: "tune"; onClicked: Ui.toggle("controlOpen") }
                MenuRow { width: parent.width; text: "Настройки Сосны…"; icon: "settings"; hint: "Super ,"; onClicked: Ui.openSettings("") }
                MenuRow { width: parent.width; text: "Звук…"; icon: "graphic_eq"; onClicked: Ui.openSound() }
                MenuRow { width: parent.width; text: "Mission Control"; icon: "grid_view"; hint: "Super Tab"; onClicked: Ui.toggle("missionOpen") }
                Separator { width: parent.width }
                MenuRow { width: parent.width; text: "Сон"; icon: "bedtime"; onClicked: Session.suspend() }
                MenuRow { width: parent.width; text: "Перезагрузить…"; icon: "restart_alt"; onClicked: { Ui.closePopups(); Ui.powerAsk = true; win.powerAction = "reboot"; } }
                MenuRow { width: parent.width; text: "Выключить…"; icon: "power_settings_new"; onClicked: { Ui.closePopups(); Ui.powerAsk = true; win.powerAction = "poweroff"; } }
                Separator { width: parent.width }
                MenuRow { width: parent.width; text: "Заблокировать экран"; icon: "lock"; hint: "Super L"; onClicked: Session.lock() }
                MenuRow { width: parent.width; text: "Завершить сеанс"; icon: "logout"; onClicked: Session.logout() }
            }
        }

        // ───────────── Подтверждение выключения ─────────────
        property string dummy
        Pop {
            id: power
            open: Ui.powerAsk
            origin: Item.Center
            anchors.centerIn: parent
            width: 340
            height: 190
            radius: 22
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8
                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: win.powerAction === "reboot" ? "restart_alt" : "power_settings_new"
                    size: 34
                    color: Theme.accent
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: win.powerAction === "reboot" ? "Перезагрузить компьютер?" : "Выключить компьютер?"
                    weight: Font.Bold
                    size: 15
                }
                RowLayout {
                    Layout.topMargin: 10
                    Layout.fillWidth: true
                    spacing: 10
                    Btn { Layout.fillWidth: true; text: "Отмена"; onClicked: Ui.powerAsk = false }
                    Btn {
                        Layout.fillWidth: true
                        text: win.powerAction === "reboot" ? "Перезагрузить" : "Выключить"
                        primary: true
                        onClicked: win.powerAction === "reboot" ? Session.reboot() : Session.poweroff()
                    }
                }
            }
        }

        // ───────────── Центр управления ─────────────
        Pop {
            id: cc
            open: Ui.controlOpen
            origin: Item.TopRight
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: Theme.barHeight + 6
            width: 360
            height: ccGrid.implicitHeight + 24
            radius: 24

            GridLayout {
                id: ccGrid
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                // Сеть / VPN / Bluetooth
                Tile {
                    Layout.rowSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 146
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 0
                        Toggle {
                            icon: Net.type === "wifi" ? "wifi" : Net.type === "ethernet" ? "lan" : "signal_disconnected"
                            on: Net.type !== "none"
                            title: Net.type === "wifi" ? "Wi‑Fi" : Net.type === "ethernet" ? "Ethernet" : "Нет сети"
                            sub: Net.type === "none" ? "Отключено" : "Подключено"
                            onClicked: Quickshell.execDetached(["nm-connection-editor"])
                        }
                        Toggle {
                            icon: "shield"
                            on: Net.vpn
                            title: "VPN"
                            sub: Net.vpn ? Net.vpnName : "Выкл."
                            onClicked: Quickshell.execDetached(["sh", "-c", "pgrep -x Throne >/dev/null || Throne"])
                        }
                        Toggle {
                            icon: "bluetooth"
                            on: Bluetooth.defaultAdapter?.enabled ?? false
                            title: "Bluetooth"
                            sub: !Bluetooth.defaultAdapter ? "Нет адаптера" : Bluetooth.defaultAdapter.enabled ? "Вкл." : "Выкл."
                            onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    active: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                    Toggle {
                        anchors.fill: parent
                        anchors.margins: 10
                        icon: "dark_mode"
                        on: Notifs.dnd
                        title: "Не беспокоить"
                        sub: Notifs.dnd ? "Вкл." : "Выкл."
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    active: Idle.coffee
                    onClicked: Idle.coffee = !Idle.coffee
                    Toggle {
                        anchors.fill: parent
                        anchors.margins: 10
                        icon: "coffee"
                        on: Idle.coffee
                        title: "Кофе"
                        sub: Idle.coffee ? "Не засыпать" : "Сон через 10 мин"
                        onClicked: Idle.coffee = !Idle.coffee
                    }
                }

                // Звук
                Tile {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9
                        RowLayout {
                            Label { text: "Звук"; weight: Font.DemiBold; size: 13; Layout.fillWidth: true }
                            Label { text: Audio.sinkName; dim: true; size: 11.5; Layout.maximumWidth: 180 }
                            // Свои настройки звука: устройства и громкость программ
                            HoverButton {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                onClicked: Ui.openSound()
                                Icon { anchors.centerIn: parent; text: "chevron_right"; size: 18 }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            value: Audio.muted ? 0 : Audio.volume
                            icon: Audio.muted ? "volume_off" : "volume_up"
                            onMoved: v => Audio.setVolume(v)
                        }
                        Slider {
                            Layout.fillWidth: true
                            value: Audio.micMuted ? 0 : Audio.micVolume
                            icon: Audio.micMuted ? "mic_off" : "mic"
                            onMoved: v => Audio.setMic(v)
                        }
                    }
                }

                // Яркость монитора (DDC/CI)
                Tile {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9
                        RowLayout {
                            Label { text: "Яркость"; weight: Font.DemiBold; size: 13; Layout.fillWidth: true }
                            Label { text: Brightness.bus < 0 ? (Brightness.ready ? "" : "Ищу монитор…") : Math.round(Brightness.value * 100) + "%"; dim: true; mono: true; size: 11 }
                        }
                        Slider {
                            Layout.fillWidth: true
                            value: Brightness.value
                            icon: Brightness.value < 0.4 ? "brightness_5" : "brightness_7"
                            onMoved: v => Brightness.set(v)
                        }
                    }
                }

                // Что играет
                Tile {
                    visible: Media.hasTrack
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        ClippingRectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 10
                            color: Theme.tile
                            Image {
                                anchors.fill: parent
                                source: Media.art
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(96, 96)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label { Layout.fillWidth: true; text: Media.title; weight: Font.DemiBold; size: 13 }
                            Label { Layout.fillWidth: true; text: Media.artist; dim: true; size: 11.5 }
                        }
                        RoundIcon { icon: Media.playing ? "pause" : "play_arrow"; onClicked: Media.toggle() }
                        RoundIcon { icon: "fast_forward"; onClicked: Media.next() }
                    }
                }

                // Быстрые кнопки
                RowLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 0
                    Quick { icon: "screenshot_region"; tip: "Скриншот"; onClicked: { Ui.closePopups(); Shot.pick(); } }
                    Quick { icon: Recorder.active ? "stop_circle" : "radio_button_checked"; tip: "Запись"; hot: Recorder.active; onClicked: { Ui.closePopups(); Recorder.toggle(); } }
                    Quick { icon: "colorize"; tip: "Пипетка"; onClicked: { Ui.closePopups(); Shot.pickColor(); } }
                    Quick { icon: "timer"; tip: "Фокус"; hot: Focus.running; onClicked: Focus.toggle() }
                    Quick { icon: "wallpaper"; tip: "Обои"; onClicked: { Ui.closePopups(); Ui.wallOpen = true; } }
                    Quick { icon: "content_paste"; tip: "Буфер"; onClicked: Ui.spotlight(";") }
                }

                // Пользователь
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.hairline
                }
                RowLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    spacing: 10
                    ClippingRectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Theme.accent
                        Image {
                            anchors.fill: parent
                            source: Config.avatar
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(68, 68)
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { text: Config.userName; weight: Font.DemiBold; size: 13 }
                        Label { id: uptimeL; text: "—"; dim: true; mono: true; size: 10.5 }
                    }
                    RoundIcon { icon: "lock"; small: true; onClicked: Session.lock() }
                    RoundIcon { icon: "power_settings_new"; small: true; onClicked: { Ui.closePopups(); win.powerAction = "poweroff"; Ui.powerAsk = true; } }
                }
            }

            Process {
                running: Ui.controlOpen
                command: ["sh", "-c", "uptime -p | sed 's/up //; s/ hours\\?/ ч/; s/ minutes\\?/ мин/; s/ days\\?/ дн/; s/,//g'"]
                stdout: StdioCollector { onStreamFinished: uptimeL.text = "в сети " + text.trim() }
            }
        }

        // ───────────── Центр уведомлений ─────────────
        Pop {
            id: nc
            open: Ui.notifOpen
            origin: Item.TopRight
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: Theme.barHeight + 6
            width: 380
            height: Math.min(win.height - Theme.barHeight - 20, ncCol.implicitHeight + 24)
            radius: 24

            ColumnLayout {
                id: ncCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Календарь
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cal.implicitHeight + 24
                    Calendar {
                        id: cal
                        anchors.fill: parent
                        anchors.margins: 12
                    }
                }

                // Погода
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        Icon { text: Weather.icon; size: 30; color: Theme.accent }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: Weather.city; weight: Font.DemiBold; size: 13 }
                            Label { text: Weather.desc + " · макс. " + Weather.signed(Weather.max) + ", мин. " + Weather.signed(Weather.min); dim: true; size: 11.5 }
                        }
                        Label { text: Weather.signed(Weather.temp); size: 24; weight: Font.Medium }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Label { text: "Уведомления"; weight: Font.Bold; size: 14; Layout.fillWidth: true }
                    Label {
                        visible: Notifs.count > 0
                        text: "Очистить"
                        size: 12
                        color: clearA.containsMouse ? Theme.text : Theme.accent
                        MouseArea { id: clearA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clear() }
                    }
                }

                Label {
                    visible: Notifs.count === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: "Нет новых уведомлений"
                    dim: true
                    size: 12.5
                }

                ListView {
                    id: nlist
                    visible: Notifs.count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 520)
                    clip: true
                    spacing: 8
                    model: Notifs.list
                    add: Transition { NumberAnimation { properties: "opacity,scale"; from: 0.6; to: 1; duration: 260; easing.type: Easing.OutBack } }
                    remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 180 } }
                    displaced: Transition { NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic } }

                    delegate: Tile {
                        id: card
                        required property var modelData
                        width: nlist.width
                        height: nrow.implicitHeight + 22
                        onClicked: {
                            const def = modelData.actions.find(a => a.identifier === "default") ?? modelData.actions[0];
                            if (def)
                                def.invoke();
                            modelData.dismiss();
                        }
                        RowLayout {
                            id: nrow
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 11
                            IconImage {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                source: card.modelData.image || (card.modelData.appIcon ? (card.modelData.appIcon.startsWith("/") ? card.modelData.appIcon : Quickshell.iconPath(card.modelData.appIcon, true)) : Quickshell.iconPath(DesktopEntries.heuristicLookup(card.modelData.appName)?.icon ?? "dialog-information", true))
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: card.modelData.summary; weight: Font.DemiBold; size: 13; Layout.fillWidth: true }
                                    Label { text: win.ago(Notifs.times[card.modelData.id]); dim: true; size: 11 }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.body
                                    visible: text.length > 0
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    color: Theme.text2
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                                Label { text: card.modelData.appName; size: 10.5; color: Theme.text3 }
                            }
                        }
                        // Крестик при наведении
                        Rectangle {
                            visible: card.hovered
                            x: -6; y: -6
                            width: 20; height: 20; radius: 10
                            color: Theme.glassStrong
                            border.width: 1
                            border.color: Theme.glassBorder
                            Icon { anchors.centerIn: parent; text: "close"; size: 13 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.modelData.dismiss() }
                        }
                    }
                }
            }
        }

        // ───────────── Об этой Сосне ─────────────
        Pop {
            id: about
            open: Ui.aboutOpen
            origin: Item.Center
            anchors.centerIn: parent
            width: 560
            height: 300
            radius: 22

            Row {
                x: 18; y: 16
                spacing: 8
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#ff5f57"
                    Icon { anchors.centerIn: parent; text: "close"; size: 9; color: "#4d0000"; visible: closeA.containsMouse }
                    MouseArea { id: closeA; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: Ui.aboutOpen = false }
                }
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.alpha(Theme.text, 0.2) }
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.alpha(Theme.text, 0.2) }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 34
                anchors.topMargin: 44
                spacing: 30
                Pine {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 130
                    color: Theme.accent
                    stroke: 3.2
                    SequentialAnimation on rotation {
                        running: Ui.aboutOpen
                        loops: Animation.Infinite
                        NumberAnimation { from: -2; to: 2; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 2; to: -2; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { text: "Сосна"; size: 30; weight: Font.Bold }
                    Label { text: "Версия 1.0 · октябрь 2026"; dim: true; size: 12.5; Layout.bottomMargin: 12 }
                    Repeater {
                        model: win.specs
                        RowLayout {
                            required property var modelData
                            spacing: 10
                            Label { text: modelData[0]; dim: true; size: 12; Layout.preferredWidth: 84 }
                            Label { text: modelData[1]; mono: true; size: 11.5; Layout.fillWidth: true }
                        }
                    }
                }
            }
            Process {
                running: Ui.aboutOpen
                command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //; s/(R)//g; s/(TM)//g; s/ CPU//; s/Intel Core/Intel Core/'; nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sed 's/NVIDIA //' || echo —; free -g | awk '/Mem/{print $2+2\" ГБ\"}'; hyprctl monitors -j | python3 -c \"import json,sys;m=json.load(sys.stdin)[0];print(f\\\"{m['width']}×{m['height']} · {round(m['refreshRate'])} Гц\\\")\"; uname -r; hyprctl version -j | python3 -c \"import json,sys;print('Hyprland '+json.load(sys.stdin)['tag'].lstrip('v'))\""]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = text.trim().split("\n");
                        win.specs = [["Процессор", l[0] ?? "—"], ["Графика", l[1] ?? "—"], ["Память", l[2] ?? "—"], ["Экран", l[3] ?? "—"], ["Ядро", l[4] ?? "—"], ["Композитор", l[5] ?? "—"]];
                    }
                }
            }
        }

        // ───────────── Обои ─────────────
        Pop {
            id: walls
            open: Ui.wallOpen
            origin: Item.Center
            anchors.centerIn: parent
            width: 900
            height: 600
            radius: 22
            onOpenChanged: if (open) Wall.refreshList()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                RowLayout {
                    Label { text: "Обои"; size: 18; weight: Font.Bold; Layout.fillWidth: true }
                    Label { text: "Видео-обои из «Live» включаются сами"; dim: true; size: 12 }
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: width / 4
                    cellHeight: cellWidth * 0.62
                    model: Wall.all
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: wcell
                        required property string modelData
                        required property int index
                        readonly property bool cur: modelData === Wall.path
                        width: grid.cellWidth
                        height: grid.cellHeight
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 12
                            color: Theme.tile
                            border.width: wcell.cur ? 3 : 0
                            border.color: Theme.accent
                            scale: wA.containsMouse ? 1.05 : 1
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                            Image {
                                anchors.fill: parent
                                source: "file://" + wcell.modelData
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(320, 200)
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                            }
                            Rectangle {
                                visible: wcell.modelData.includes("/Live/")
                                x: 8; y: 8
                                width: 40; height: 20; radius: 10
                                color: Theme.glassStrong
                                Label { anchors.centerIn: parent; text: "LIVE"; size: 9.5; weight: Font.Bold }
                            }
                        }
                        MouseArea {
                            id: wA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wall.set(wcell.modelData)
                        }
                    }
                }
            }
        }

        // ───────────── Меню значка трея ─────────────
        Pop {
            id: tray
            open: Ui.trayItem !== null
            origin: Item.Top
            x: Math.max(8, Math.min(win.width - width - 8, Ui.trayX - width / 2))
            y: Theme.barHeight + 4
            width: 260
            height: trayCol.implicitHeight + 10
            radius: 12

            QsMenuOpener {
                id: trayMenu
                menu: Ui.trayItem?.menu ?? null
            }

            Column {
                id: trayCol
                anchors.fill: parent
                anchors.margins: 5
                Label {
                    visible: (trayMenu.children?.values?.length ?? 0) === 0
                    width: parent.width
                    height: 30
                    leftPadding: 10
                    text: "У этого значка нет меню"
                    dim: true
                    size: 12.5
                }
                Repeater {
                    model: trayMenu.children
                    TrayEntry {
                        required property var modelData
                        entry: modelData
                        width: trayCol.width
                    }
                }
            }
        }
    }

    property string powerAction: "poweroff"
    property var specs: []

    function ago(t): string {
        if (!t)
            return "";
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1)
            return "сейчас";
        if (m < 60)
            return m + " мин";
        return Math.floor(m / 60) + " ч";
    }

    // ── Компоненты ──
    component Tile: Rectangle {
        id: tile
        property bool active: false
        property alias hovered: tileA.containsMouse
        default property alias content: inner.data
        signal clicked
        radius: 16
        color: active ? Theme.alpha(Theme.accent, 0.22) : tileA.containsMouse ? Theme.tileHover : Theme.tile
        border.width: 1
        border.color: active ? Theme.alpha(Theme.accent, 0.3) : Theme.alpha(Theme.text, 0.06)
        scale: tileA.pressed ? 0.97 : tileA.containsMouse ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        MouseArea {
            id: tileA
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
        Item {
            id: inner
            anchors.fill: parent
        }
    }

    component Toggle: Item {
        id: tg
        property string icon
        property bool on: false
        property string title
        property string sub
        signal clicked
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 44
        RowLayout {
            anchors.fill: parent
            spacing: 9
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: tg.on ? Theme.accent : Theme.alpha(Theme.text, 0.14)
                scale: tgA.pressed ? 0.88 : tgA.containsMouse ? 1.12 : 1
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Icon {
                    anchors.centerIn: parent
                    text: tg.icon
                    size: 17
                    fill: tg.on
                    color: tg.on ? Theme.inkOnAccent : Theme.text
                }
                MouseArea {
                    id: tgA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tg.clicked()
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: tg.title; weight: Font.DemiBold; size: 12.5 }
                Label { Layout.fillWidth: true; text: tg.sub; dim: true; size: 11 }
            }
        }
    }

    component RoundIcon: Rectangle {
        id: ri
        property string icon
        property bool small: false
        signal clicked
        Layout.preferredWidth: small ? 32 : 36
        Layout.preferredHeight: small ? 32 : 36
        radius: width / 2
        color: riA.containsMouse ? Theme.alpha(Theme.text, 0.16) : Theme.alpha(Theme.text, small ? 0.08 : 0)
        scale: riA.pressed ? 0.88 : riA.containsMouse ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Icon { anchors.centerIn: parent; text: ri.icon; size: ri.small ? 17 : 24; fill: true }
        MouseArea { id: riA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ri.clicked() }
    }

    component Quick: Item {
        id: q
        property string icon
        property string tip
        property bool hot: false
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 64
        Rectangle {
            id: qc
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44; height: 44; radius: 22
            color: q.hot ? Theme.accent : qA.containsMouse ? Theme.tileHover : Theme.tile
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.06)
            scale: qA.pressed ? 0.88 : qA.containsMouse ? 1.14 : 1
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            Icon { anchors.centerIn: parent; text: q.icon; size: 20; color: q.hot ? Theme.inkOnAccent : Theme.text }
        }
        Label {
            anchors.top: qc.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            text: q.tip
            size: 10.5
            dim: true
            opacity: qA.containsMouse ? 1 : 0.7
        }
        MouseArea { id: qA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: q.clicked() }
    }

    component Btn: Rectangle {
        id: b
        property string text
        property bool primary: false
        signal clicked
        implicitHeight: 34
        radius: 10
        color: primary ? (bA.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : (bA.containsMouse ? Theme.tileHover : Theme.tile)
        scale: bA.pressed ? 0.95 : bA.containsMouse ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Label { anchors.centerIn: parent; text: b.text; weight: Font.DemiBold; size: 13; color: b.primary ? Theme.inkOnAccent : Theme.text }
        MouseArea { id: bA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    component Calendar: ColumnLayout {
        id: calRoot
        property date today: new Date()
        property int offset: 0
        readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: {
                    const m = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
                    return m[calRoot.shown.getMonth()] + " " + calRoot.shown.getFullYear();
                }
                weight: Font.Bold
                size: 13.5
                color: Theme.accent
            }
            RoundIcon { icon: "chevron_left"; small: true; onClicked: calRoot.offset-- }
            RoundIcon { icon: "chevron_right"; small: true; onClicked: calRoot.offset++ }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 0
            Repeater {
                model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                Label {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: 10.5
                    color: Theme.text3
                    weight: Font.DemiBold
                }
            }
            Repeater {
                model: {
                    const first = calRoot.shown;
                    const lead = (first.getDay() + 6) % 7;
                    const days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
                    const cells = [];
                    for (let i = 0; i < 42; i++) {
                        const d = i - lead + 1;
                        cells.push(d >= 1 && d <= days ? d : 0);
                    }
                    return cells;
                }
                Item {
                    required property int modelData
                    required property int index
                    readonly property bool isToday: modelData > 0 && calRoot.offset === 0 && modelData === calRoot.today.getDate()
                    Layout.fillWidth: true
                    implicitHeight: 26
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 24; radius: 12
                        color: parent.isToday ? Theme.accent : "transparent"
                    }
                    Label {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData : ""
                        size: 12
                        weight: parent.isToday ? Font.Bold : Font.Medium
                        color: parent.isToday ? Theme.inkOnAccent : (index % 7 >= 5 ? Theme.text2 : Theme.text)
                    }
                }
            }
        }
    }
}
