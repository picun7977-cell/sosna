import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// Строка меню: сосна, приложение, рабочие столы | трей, раскладка, звук, центр управления, часы
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property var modelData

        screen: modelData
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.barHeight
        exclusiveZone: Hypr.fullscreen ? 0 : Theme.barHeight
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sosna-bar"

        SystemClock {
            id: clock
            precision: Config.o.barSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        Item {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.barHeight
            y: Ui.entered ? 0 : -Theme.barHeight
            opacity: Ui.entered ? 1 : 0
            Behavior on y { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 500 } }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.07, 0.075, 0.086, 0.34)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }

            // ── Левая часть ──
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                HoverButton {
                    implicitWidth: 34
                    implicitHeight: 24
                    active: Ui.logoOpen
                    onClicked: Ui.toggle("logoOpen")
                    Pine {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                    }
                }

                HoverButton {
                    implicitWidth: appName.implicitWidth + 18
                    implicitHeight: 24
                    onClicked: Ui.toggle("missionOpen")
                    Label {
                        id: appName
                        anchors.centerIn: parent
                        text: Hypr.activeApp
                        weight: Font.Bold
                        width: Math.min(implicitWidth, 260)
                    }
                }

                // Рабочие столы — «таблетки»
                Item {
                    implicitWidth: pills.implicitWidth + 16
                    implicitHeight: 24
                    Layout.leftMargin: 4

                    Row {
                        id: pills
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: {
                                let max = 5;
                                for (const w of Hyprland.workspaces.values)
                                    if (w.id > max)
                                        max = w.id;
                                return Array.from({ length: max }, (_, i) => i + 1);
                            }

                            Rectangle {
                                required property int modelData
                                readonly property bool current: modelData === Hypr.wsId
                                readonly property bool busy: Hypr.toplevels.some(t => t.workspace?.id === modelData)

                                width: current ? 18 : pillArea.containsMouse ? 9 : 6
                                height: pillArea.containsMouse ? 9 : 6
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: current ? Theme.accent : Theme.alpha(Theme.text, busy ? 0.7 : 0.28)
                                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                Behavior on color { ColorAnimation { duration: Theme.normal } }

                                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                                MouseArea {
                                    id: pillArea
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hypr.focusWorkspace(parent.modelData)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: w => Hypr.dispatch(`hl.dsp.focus({ workspace = "${w.angleDelta.y > 0 ? "-1" : "+1"}" })`)
                    }
                }
            }

            // ── Правая часть ──
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // Индикаторы приватности
                Row {
                    spacing: 6
                    Layout.rightMargin: visible ? 8 : 0
                    visible: Audio.micUsers.length > 0 || Audio.screenUsers.length > 0 || Recorder.active

                    Rectangle {
                        visible: Audio.micUsers.length > 0
                        width: 8; height: 8; radius: 4
                        color: Theme.orange
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: Audio.micUsers.length > 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        visible: Audio.screenUsers.length > 0 || Recorder.active
                        width: 8; height: 8; radius: 4
                        color: Theme.green
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Трей
                Repeater {
                    model: SystemTray.items.values

                    HoverButton {
                        id: trayBtn
                        required property SystemTrayItem modelData
                        implicitWidth: 28
                        implicitHeight: 24
                        onClicked: m => {
                            if (m.button === Qt.RightButton || modelData.onlyMenu) {
                                const p = trayBtn.mapToItem(null, 0, trayBtn.height + 6);
                                Ui.openTray(modelData, p.x);
                            } else {
                                modelData.activate();
                            }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            source: trayBtn.modelData.icon
                            smooth: true
                        }
                    }
                }

                // Кабель: значок + скорость при активном трафике, наведение — подробности
                HoverButton {
                    id: netBtn
                    visible: Net.iface !== "" || Net.type !== "none"
                    implicitWidth: netRow.implicitWidth + 12
                    implicitHeight: 24
                    hoverScale: 1.06
                    onClicked: Ui.toggle("controlOpen")
                    Behavior on implicitWidth { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    readonly property bool busy: Net.rx > 300 * 1024 || Net.tx > 300 * 1024

                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: 4
                        Item {
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.centerIn: parent
                                text: Net.type === "wifi" ? "wifi" : Net.carrier ? "lan" : "lan"
                                size: 17
                                color: Net.carrier || Net.type === "wifi" ? Theme.text : Theme.text3
                            }
                            // Кабель выдернут — красный крестик
                            Rectangle {
                                visible: !Net.carrier && Net.type !== "wifi"
                                width: 9; height: 9; radius: 4.5
                                color: Theme.red
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: -1
                                Icon { anchors.centerIn: parent; text: "close"; size: 8; weight: 700; color: "white" }
                            }
                            // VPN — маленький щит
                            Rectangle {
                                visible: Net.vpn && Net.carrier
                                width: 9; height: 9; radius: 4.5
                                color: Theme.accent
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: -1
                                Icon { anchors.centerIn: parent; text: "shield"; size: 7; fill: true; color: Theme.inkOnAccent }
                            }
                        }
                        // Скорость показывается, только когда что-то качается
                        Column {
                            visible: netBtn.busy
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -2
                            Label { text: "↓ " + Net.rate(Net.rx); size: 8.5; mono: true; weight: Font.DemiBold }
                            Label { text: "↑ " + Net.rate(Net.tx); size: 8.5; mono: true; dim: true }
                        }
                    }

                    PopupWindow {
                        id: netPop
                        property bool alive: false
                        anchor.item: netBtn
                        anchor.rect.x: netBtn.width / 2 - implicitWidth / 2
                        anchor.rect.y: netBtn.height + 7
                        implicitWidth: 270
                        implicitHeight: netInfo.implicitHeight + 32
                        color: "transparent"
                        visible: netBtn.hovered || alive
                        onVisibleChanged: if (visible) alive = true
                        Timer {
                            running: !netBtn.hovered && netPop.alive
                            interval: 220
                            onTriggered: netPop.alive = false
                        }

                    Pop {
                        open: netBtn.hovered
                        origin: Item.Top
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 12
                        Column {
                            id: netInfo
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 5
                            Row {
                                spacing: 8
                                Icon { text: "lan"; size: 18; color: Net.carrier ? Theme.accent : Theme.red }
                                Label { anchors.verticalCenter: parent.verticalCenter; text: Net.carrier ? "Кабель подключён" : "Кабель отключён"; weight: Font.DemiBold }
                            }
                            Label { width: parent.width; text: Net.iface + (Net.speedText ? "  ·  " + Net.speedText : ""); size: 11.5; dim: true }
                            Label { width: parent.width; visible: Net.name !== ""; text: Net.name; size: 11.5; dim: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
                            Label { width: parent.width; visible: Net.vpn; text: "VPN: " + Net.vpnName; size: 11.5; color: Theme.accent }
                            Separator { width: parent.width }
                            Label { width: parent.width; text: "↓ " + Net.rate(Net.rx) + "    ↑ " + Net.rate(Net.tx); size: 12; mono: true }
                            Label { width: parent.width; text: "За сеанс: ↓ " + Net.size(Net.rxTotal) + "  ↑ " + Net.size(Net.txTotal); size: 11; dim: true; wrapMode: Text.Wrap }
                        }
                    }
                    }
                }

                // Кофе
                HoverButton {
                    implicitWidth: 28
                    implicitHeight: 24
                    onClicked: Idle.coffee = !Idle.coffee
                    Icon {
                        anchors.centerIn: parent
                        text: "coffee"
                        size: 17
                        fill: Idle.coffee
                        color: Idle.coffee ? Theme.accent : Theme.text
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }

                // Раскладка
                HoverButton {
                    implicitWidth: 34
                    implicitHeight: 24
                    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                    Rectangle {
                        anchors.centerIn: parent
                        width: lay.implicitWidth + 9
                        height: 16
                        radius: 5
                        color: Hypr.caps ? Theme.text : "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.55)
                        Label {
                            id: lay
                            anchors.centerIn: parent
                            text: Hypr.layout
                            mono: true
                            size: 10.5
                            weight: Font.DemiBold
                            color: Hypr.caps ? "#111" : Theme.text
                        }
                    }
                }

                // Громкость: колесо меняет, клик — центр управления
                HoverButton {
                    implicitWidth: 28
                    implicitHeight: 24
                    onClicked: Ui.toggle("controlOpen")
                    Icon {
                        anchors.centerIn: parent
                        size: 17
                        text: Audio.muted ? "volume_off" : Audio.volume < 0.01 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }

                // Центр управления
                HoverButton {
                    implicitWidth: 30
                    implicitHeight: 24
                    active: Ui.controlOpen
                    onClicked: Ui.toggle("controlOpen")
                    Icon {
                        anchors.centerIn: parent
                        size: 17
                        text: "toggle_on"
                    }
                }

                // Часы → Центр уведомлений
                HoverButton {
                    implicitWidth: clockText.implicitWidth + 18
                    implicitHeight: 24
                    active: Ui.notifOpen
                    onClicked: Ui.toggle("notifOpen")
                    Label {
                        id: clockText
                        anchors.centerIn: parent
                        weight: Font.DemiBold
                        text: {
                            const d = clock.date;
                            const s = d.toLocaleString(Qt.locale("ru_RU"), "ddd d MMM");
                            const t = Qt.formatTime(d, Config.o.barSeconds ? "hh:mm:ss" : "hh:mm");
                            return Config.o.barDate ? s.charAt(0).toUpperCase() + s.slice(1) + "   " + t : t;
                        }
                    }
                    Rectangle {
                        visible: Notifs.count > 0 && !Ui.notifOpen
                        width: 6; height: 6; radius: 3
                        color: Theme.accent
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 2
                    }
                }
            }
        }
    }
}
