import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// Остров-чёлка по центру строки меню
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    color: "transparent"
    anchors.top: true
    implicitWidth: 760
    implicitHeight: 420
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sosna-island"
    mask: Region {
        item: shape
    }
    // Клавиатура нужна только развёрнутому чату с Claude (фокус — по клику)
    WlrLayershell.keyboardFocus: win.chatOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool chatOpen: view === "work" && Island.expanded
    onChatOpenChanged: {
        Claude.hold = chatOpen;
        if (chatOpen)
            chatInput.forceActiveFocus();
    }

    readonly property string view: Island.view
    readonly property bool hidden: (Hypr.fullscreen && Config.o.islandHideFullscreen) || !Ui.entered || Session.locked
    readonly property bool lyr: Media.hasLyrics && Config.o.islandLyrics

    SystemClock {
        id: islandClock
        precision: SystemClock.Seconds
    }



    // Размер острова для каждого состояния
    readonly property size target: {
        switch (view) {
        case "brightness":
        case "volume":
            return Qt.size(330, 40);
        case "layout":
            return Qt.size(170, 34);
        case "caps":
            return Qt.size(200, 34);
        case "notif":
            return Qt.size(430, 80);
        case "claude":
            return Qt.size(380, 52);
        case "text":
            return Qt.size(Math.min(520, Math.max(300, textBody.implicitWidth + 90)), 58);
        case "color":
            return Qt.size(220, 40);
        case "rec":
            return Island.expanded ? Qt.size(300, 70) : Qt.size(200, 34);
        case "focus":
            return Island.expanded ? Qt.size(320, 96) : Qt.size(230, 38);
        case "abi":
            return Abi.state === "speaking" ? Qt.size(460, Math.min(130, abiText.implicitHeight + 40)) : Qt.size(340, 46);
        case "music":
            if (Island.expanded)
                return Qt.size(480, win.lyr ? 236 : 150);
            // С текстом песни ширина постоянная — иначе остров «дышит» на каждой строке
            if (win.lyr)
                return Qt.size(460, 34);
            return Qt.size(Math.max(220, Math.min(460, titleMeasure.implicitWidth + 104)), 34);
        case "work":
            return Island.expanded ? Qt.size(540, 380) : Qt.size(420, 36);
        case "actions":
            return Qt.size(440, 98);
        default:
            if (Island.expanded)
                return Qt.size(420, 116);
            switch (Island.scene) {
            case "weather":
                return Qt.size(Island.hovered ? 200 : 180, 32);
            case "pet":
                return Qt.size(Island.hovered ? 220 : 200, 34);
            }
            return Island.hovered ? Qt.size(176, 32) : Qt.size(150, 30);
        }
    }

    // Ширина названия трека (для компактного острова без текста песни)
    Text {
        id: titleMeasure
        visible: false
        text: Media.title
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Item {
        id: holder
        anchors.horizontalCenter: parent.horizontalCenter
        width: shape.width
        height: shape.height
        y: win.hidden ? -shape.height - 4 : 0
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Ear {
            anchors.right: shape.left
            r: Math.min(12, shape.height / 2)
        }
        Ear {
            anchors.left: shape.right
            mirrored: true
            r: Math.min(12, shape.height / 2)
        }

        Rectangle {
            id: shape
            color: Theme.island
            width: win.target.width
            height: win.target.height
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Math.min(height / 2, 30)
            bottomRightRadius: Math.min(height / 2, 30)
            clip: true

            Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
            Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                pressAndHoldInterval: 450
                property bool held: false
                onContainsMouseChanged: {
                    if (containsMouse) {
                        hoverDelay.restart();
                    } else {
                        hoverDelay.stop();
                        Island.hovered = false;
                    }
                }
                // Долгое нажатие — быстрые действия, как на айфоне
                onPressAndHold: {
                    held = true;
                    Island.pinnedOpen = false;
                    Island.show("actions", {}, 15000);
                }
                onClicked: m => {
                    if (held) {
                        held = false;
                        return;
                    }
                    if (win.view === "actions") {
                        Island.dismiss();
                    } else if (win.view === "notif") {
                        const n = Island.data.n;
                        if (m.button === Qt.LeftButton && n) {
                            const def = n.actions.find(a => a.identifier === "default") ?? n.actions[0];
                            if (def)
                                def.invoke();
                        }
                        Island.dismiss();
                    } else if (win.view === "claude" || win.view === "text" || win.view === "color" || win.view === "layout" || win.view === "caps") {
                        Island.dismiss();
                    } else if (win.chatOpen) {
                        // Клик по развёрнутому чату не сворачивает его — только кнопка или Esc
                        chatInput.forceActiveFocus();
                    } else if (win.view === "music" && m.button === Qt.MiddleButton) {
                        Media.toggle();
                    } else {
                        Island.pinnedOpen = !Island.pinnedOpen;
                    }
                }
                onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
            // Ушли мышью с быстрых действий — прячем (HoverHandler не теряет наведение над кнопками)
            HoverHandler {
                id: shapeHover
                onHoveredChanged: {
                    if (hovered)
                        actionsLeave.stop();
                    else if (win.view === "actions")
                        actionsLeave.restart();
                }
            }
            Timer {
                id: actionsLeave
                interval: 700
                onTriggered: if (win.view === "actions") Island.dismiss()
            }
            Timer {
                id: hoverDelay
                interval: 220
                onTriggered: Island.hovered = true
            }

            // ── Музыка, компактно: обложка | строка песни или название | полоски ──
            View {
                on: win.view === "music" && !Island.expanded
                Art {
                    id: artSmall
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    radius: 6
                }
                Lyric {
                    id: compactText
                    anchors.left: artSmall.right
                    anchors.leftMargin: 12
                    anchors.right: barsSmall.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.lyr && Media.currentLine ? Media.currentLine : Media.title
                    lyric: win.lyr && Media.currentLine !== ""
                    progress: Media.lineProgress
                }
                Bars {
                    id: barsSmall
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── Музыка, развёрнуто: плеер + текст песни ──
            View {
                on: win.view === "music" && Island.expanded
                Item {
                    anchors.fill: parent
                    anchors.margins: 18
                    anchors.topMargin: 16

                    Art {
                        id: artBig
                        size: 58
                        radius: 13
                    }
                    Column {
                        anchors.left: artBig.right
                        anchors.leftMargin: 14
                        anchors.right: ctrls.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: artBig.verticalCenter
                        spacing: 2
                        Label {
                            width: parent.width
                            text: Media.title
                            weight: Font.DemiBold
                            size: 15
                        }
                        Label {
                            width: parent.width
                            text: Media.artist
                            dim: true
                            size: 12.5
                        }
                    }
                    Row {
                        id: ctrls
                        anchors.right: parent.right
                        anchors.verticalCenter: artBig.verticalCenter
                        spacing: 6
                        IconBtn { icon: "fast_rewind"; onClicked: Media.prev() }
                        IconBtn { icon: Media.playing ? "pause" : "play_arrow"; big: true; onClicked: Media.toggle() }
                        IconBtn { icon: "fast_forward"; onClicked: Media.next() }
                    }

                    // Прогресс
                    Item {
                        id: progress
                        anchors.top: artBig.bottom
                        anchors.topMargin: 14
                        width: parent.width
                        height: 14
                        Label {
                            id: posL
                            text: Media.fmt(Media.position)
                            mono: true
                            size: 10
                            dim: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            id: lenL
                            text: "−" + Media.fmt(Media.length - Media.position)
                            mono: true
                            size: 10
                            dim: true
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            id: track
                            anchors.left: posL.right
                            anchors.right: lenL.left
                            anchors.margins: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: seekArea.containsMouse ? 6 : 4
                            radius: height / 2
                            color: Theme.alpha(Theme.text, 0.16)
                            Behavior on height { NumberAnimation { duration: Theme.fast } }
                            Rectangle {
                                width: parent.width * (Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.accent
                            }
                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: m => Media.seek(Media.length * Math.max(0, Math.min(1, (m.x - 6) / track.width)))
                            }
                        }
                    }

                    // Текст песни: текущая строка по центру, соседние — тусклее
                    ListView {
                        id: lyricsList
                        visible: win.lyr
                        anchors.top: progress.bottom
                        anchors.topMargin: 10
                        anchors.bottom: parent.bottom
                        width: parent.width
                        clip: true
                        interactive: false
                        model: Media.lyrics
                        currentIndex: Math.max(0, Media.line)
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        preferredHighlightBegin: height / 2 - 14
                        preferredHighlightEnd: height / 2 + 14
                        highlightMoveDuration: 520
                        highlightMoveVelocity: -1
                        spacing: 4

                        delegate: Text {
                            required property var modelData
                            required property int index
                            readonly property bool cur: index === Media.line
                            width: lyricsList.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: modelData.text
                            font.family: Theme.font
                            font.pixelSize: 15
                            font.weight: cur ? Font.Bold : Font.Medium
                            color: cur ? Theme.text : Theme.alpha(Theme.text, Math.abs(index - Media.line) === 1 ? 0.42 : 0.2)
                            scale: cur ? 1.0 : 0.92
                            Behavior on color { ColorAnimation { duration: 400 } }
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                    // Мягкое затухание краёв списка
                    Rectangle {
                        visible: lyricsList.visible
                        anchors.top: lyricsList.top
                        width: parent.width
                        height: 18
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.island }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    Rectangle {
                        visible: lyricsList.visible
                        anchors.bottom: lyricsList.bottom
                        width: parent.width
                        height: 18
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Theme.island }
                        }
                    }
                }
            }

            // ── Громкость ──
            View {
                on: win.view === "volume"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon {
                        text: Audio.muted ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                        size: 18
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.alpha(Theme.text, 0.16)
                        Rectangle {
                            width: parent.width * (Audio.muted ? 0 : Math.min(1, Audio.volume))
                            height: parent.height
                            radius: 3
                            color: Theme.text
                            Behavior on width { NumberAnimation { duration: 140 } }
                        }
                    }
                    Label {
                        text: Audio.muted ? "—" : Math.round(Audio.volume * 100)
                        mono: true
                        size: 11
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 22
                    }
                }
            }

            // ── Раскладка ──
            View {
                on: win.view === "brightness"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon {
                        text: Brightness.value < 0.4 ? "brightness_5" : "brightness_7"
                        color: Theme.orange
                        size: 18
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.alpha(Theme.text, 0.16)
                        Rectangle {
                            width: parent.width * Brightness.value
                            height: parent.height
                            radius: 3
                            color: Theme.text
                            Behavior on width { NumberAnimation { duration: 140 } }
                        }
                    }
                    Label {
                        text: Math.round(Brightness.value * 100)
                        mono: true
                        size: 11
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 22
                    }
                }
            }

            // ── Раскладка ──
            View {
                on: win.view === "layout"
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Label { text: Island.data.from ?? ""; mono: true; size: 12; dim: true }
                    Icon { text: "arrow_forward"; size: 14; color: Theme.text3 }
                    Label { text: Island.data.to ?? ""; mono: true; size: 12; weight: Font.Bold; color: Theme.accent }
                }
            }

            // ── Caps Lock ──
            View {
                on: win.view === "caps"
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { text: "keyboard_capslock"; size: 17; color: Island.data.on ? Theme.accent : Theme.text2 }
                    Label { text: Island.data.on ? "Caps Lock включён" : "Caps Lock выключен"; size: 12.5; weight: Font.DemiBold }
                }
            }

            // ── Уведомление ──
            View {
                on: win.view === "notif"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 20
                    anchors.topMargin: 10
                    anchors.bottomMargin: 8
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Theme.tile
                        IconImage {
                            anchors.fill: parent
                            source: {
                                const d = Island.data;
                                if (d.image)
                                    return d.image;
                                if (d.icon)
                                    return d.icon.startsWith("/") || d.icon.includes("://") ? d.icon : Quickshell.iconPath(d.icon, true);
                                return Quickshell.iconPath(DesktopEntries.heuristicLookup(d.app ?? "")?.icon ?? "", true);
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: Island.data.summary ?? ""
                                weight: Font.Bold
                                size: 13.5
                            }
                            Label {
                                text: (Island.data.app ?? "") + " · сейчас"
                                dim: true
                                size: 11
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: (Island.data.body ?? "").replace(/\n/g, " ")
                            dim: true
                            size: 12.5
                            weight: Font.Normal
                        }
                    }
                }
            }

            // ── Claude работает: звёздочка | что делает | токены ──
            View {
                on: win.view === "work" && !Island.expanded
                ClaudeMark {
                    id: workMark
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    spinning: Claude.working
                }
                Lyric {
                    anchors.left: workMark.right
                    anchors.leftMargin: 12
                    anchors.right: workTokens.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Claude.activity
                }
                Label {
                    id: workTokens
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Claude.tokens > 0 ? Claude.fmtTokens(Claude.tokens) : ""
                    mono: true
                    size: 11
                    dim: true
                }
            }

            // ── Чат с Claude (развёрнутый остров) ──
            View {
                on: win.chatOpen

                // Шапка
                RowLayout {
                    id: chatHead
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12
                    height: 28
                    spacing: 10
                    ClaudeMark {
                        size: 20
                        spinning: Claude.working
                    }
                    Label {
                        text: "Claude"
                        weight: Font.DemiBold
                        size: 14
                    }
                    Label {
                        Layout.fillWidth: true
                        text: Claude.activity
                        dim: true
                        size: 12
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: Claude.tokens > 0
                        text: Claude.fmtTokens(Claude.tokens) + " токенов"
                        mono: true
                        size: 11
                        dim: true
                    }
                    HoverButton {
                        width: 26
                        height: 26
                        radius: 13
                        color: hovered ? Theme.tileHover : "transparent"
                        onClicked: Island.pinnedOpen = false
                        Icon {
                            anchors.centerIn: parent
                            text: "expand_less"
                            size: 18
                        }
                    }
                }

                // Переписка
                ListView {
                    id: chatList
                    anchors.top: chatHead.bottom
                    anchors.bottom: chatBox.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    clip: true
                    spacing: 8
                    model: Claude.messages
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    onVisibleChanged: if (visible) Qt.callLater(positionViewAtEnd)

                    delegate: Item {
                        id: msg
                        required property var modelData
                        readonly property bool mine: modelData.role === "user"
                        width: chatList.width
                        height: bubble.height

                        Rectangle {
                            id: bubble
                            anchors.right: msg.mine ? parent.right : undefined
                            anchors.left: msg.mine ? undefined : parent.left
                            width: msgText.width + 22
                            height: msgText.height + 14
                            radius: 14
                            color: msg.mine ? Theme.alpha(Theme.accent, 0.32) : Theme.tile
                            Text {
                                id: msgText
                                x: 11
                                y: 7
                                width: Math.min(implicitWidth, chatList.width * 0.84)
                                text: msg.modelData.text
                                textFormat: msg.mine ? Text.PlainText : Text.MarkdownText
                                wrapMode: Text.Wrap
                                color: Theme.text
                                linkColor: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 13
                                onLinkActivated: l => Qt.openUrlExternally(l)
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: chatList.count === 0
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: Claude.sid ? "Напиши Claude — сообщение уйдёт в открытую сессию Claude Code" : "Claude Code не запущен"
                        dim: true
                        size: 12.5
                    }
                }

                // Поле ввода
                Rectangle {
                    id: chatBox
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    height: 38
                    radius: 19
                    color: Theme.tile
                    border.width: chatInput.activeFocus ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.6)

                    TextInput {
                        id: chatInput
                        anchors.left: parent.left
                        anchors.right: sendBtn.left
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: Claude.sid !== ""
                        color: Theme.text
                        selectionColor: Theme.alpha(Theme.accent, 0.5)
                        font.family: Theme.font
                        font.pixelSize: 13
                        clip: true
                        Keys.onReturnPressed: {
                            Claude.send(text);
                            text = "";
                        }
                        Keys.onEnterPressed: {
                            Claude.send(text);
                            text = "";
                        }
                        Keys.onEscapePressed: Island.pinnedOpen = false

                        Label {
                            visible: !chatInput.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Сообщение для Claude…"
                            dim: true
                            size: 13
                        }
                    }

                    HoverButton {
                        id: sendBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        enabled: chatInput.text.trim() !== ""
                        opacity: enabled ? 1 : 0.4
                        color: Theme.accent
                        onClicked: {
                            Claude.send(chatInput.text);
                            chatInput.text = "";
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: "arrow_upward"
                            size: 17
                            color: Theme.inkOnAccent
                        }
                    }
                }
            }

            // ── Claude закончил ход ──
            View {
                on: win.view === "claude"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12
                    Icon {
                        text: Island.data.error ? "error" : "auto_awesome"
                        size: 19
                        fill: true
                        color: Island.data.error ? Theme.red : Theme.accent
                        RotationAnimation on rotation {
                            running: win.view === "claude" && !Island.data.error
                            from: -20; to: 0; duration: 700; easing.type: Easing.OutBack
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Label {
                            Layout.fillWidth: true
                            text: Island.data.title ?? "Claude закончил"
                            weight: Font.DemiBold
                            size: 13
                        }
                        Rectangle {
                            visible: (Island.data.ctx ?? -1) >= 0
                            Layout.fillWidth: true
                            height: 3
                            radius: 2
                            color: Theme.alpha(Theme.text, 0.14)
                            Rectangle {
                                width: parent.width * Math.min(1, (Island.data.ctx ?? 0) / 100)
                                height: 3
                                radius: 2
                                color: (Island.data.ctx ?? 0) >= 90 ? Theme.orange : Theme.accent
                            }
                        }
                    }
                    Label {
                        visible: (Island.data.ctx ?? -1) >= 0
                        text: (Island.data.ctx ?? 0) + "%"
                        mono: true
                        size: 11
                        dim: true
                    }
                }
            }

            // ── Произвольный текст (запись сохранена, фокус окончен…) ──
            View {
                on: win.view === "text"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 20
                    spacing: 12
                    Icon {
                        text: Island.data.icon ?? "info"
                        size: 20
                        color: Island.data.warn ? Theme.red : Theme.accent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            Layout.fillWidth: true
                            text: Island.data.title ?? ""
                            weight: Font.DemiBold
                        }
                        Label {
                            id: textBody
                            Layout.fillWidth: true
                            text: Island.data.body ?? ""
                            dim: true
                            size: 12
                            visible: text.length > 0
                        }
                    }
                }
            }

            // ── Пипетка ──
            View {
                on: win.view === "color"
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: Island.data.hex ?? "#000"
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.3)
                    }
                    Label { text: (Island.data.hex ?? "").toUpperCase(); mono: true; size: 12.5; weight: Font.DemiBold }
                    Label { text: "скопирован"; size: 12; dim: true }
                }
            }

            // ── Запись экрана ──
            View {
                on: win.view === "rec"
                Row {
                    x: 16
                    height: 34
                    spacing: 9
                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: Theme.red
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: Recorder.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.fmt(Recorder.elapsed)
                        mono: true
                        size: 12
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    y: 6
                    width: 22; height: 22; radius: 11
                    color: stopArea.containsMouse ? Theme.alpha(Theme.text, 0.24) : Theme.alpha(Theme.text, 0.12)
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 2; color: Theme.text }
                    MouseArea {
                        id: stopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Recorder.toggle()
                    }
                }
                Label {
                    visible: Island.expanded
                    x: 16
                    y: 40
                    text: "Идёт запись экрана · клик по ■ — стоп"
                    dim: true
                    size: 12
                }
            }

            // ── Фокус-таймер ──
            View {
                on: win.view === "focus"
                Ring {
                    id: ring
                    x: 14
                    y: 8
                    size: 22
                    value: Focus.progress
                }
                Label {
                    anchors.left: ring.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: ring.verticalCenter
                    text: Focus.label
                    weight: Font.DemiBold
                    size: 12.5
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: ring.verticalCenter
                    text: Focus.fmt()
                    mono: true
                    size: 13
                }
                Row {
                    visible: Island.expanded
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 50
                    spacing: 8
                    Chip { text: "+5 мин"; onClicked: { Focus.left += 300; Focus.total += 300; } }
                    Chip { text: "Стоп"; onClicked: Focus.stop() }
                }
            }

            // ── Эби ──
            View {
                on: win.view === "abi"
                Icon {
                    id: abiIcon
                    x: 18
                    y: 13
                    text: Abi.state === "speaking" ? "graphic_eq" : "mic"
                    size: 19
                    fill: true
                    color: Theme.accent
                }
                Label {
                    anchors.left: abiIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: abiIcon.verticalCenter
                    text: Abi.state === "listening" ? "Эби слушает…" : Abi.state === "thinking" ? "Эби думает…" : "Эби"
                    weight: Font.DemiBold
                    size: 13
                }
                Row {
                    visible: Abi.state !== "speaking"
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: abiIcon.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 8
                        Rectangle {
                            required property int index
                            width: 3
                            radius: 2
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            SequentialAnimation on height {
                                running: win.view === "abi"
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 70 }
                                NumberAnimation { to: Abi.state === "thinking" ? 8 : 20; duration: 280 + index * 30; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 5; duration: 300 + index * 20; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
                Text {
                    id: abiText
                    visible: Abi.state === "speaking"
                    x: 18
                    y: 38
                    width: parent.width - 36
                    text: Abi.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Theme.text2
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            // ── Покой ──
            // ── Покой: точка (если сцены выключены) ──
            View {
                on: win.view === "idle" && !Island.expanded && Island.scene === "dot"
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.alpha(Theme.text, Island.hovered ? 0.35 : 0)
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }

            // ── Погода ──
            View {
                on: win.view === "idle" && !Island.expanded && Island.scene === "weather"
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: Weather.icon; size: 17; fill: true; color: Theme.accent }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Weather.signed(Weather.temp); weight: Font.Bold; size: 13 }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Weather.desc; dim: true; size: 12 }
                }
            }

            // ── Сосенка-тамагочи: растёт от экранного времени, спит, когда ты отошёл ──
            View {
                id: pet
                on: win.view === "idle" && !Island.expanded && Island.scene === "pet"
                readonly property real hours: ScreenTime.total / 3600
                readonly property real grow: hours < 1 ? 0.62 : hours < 3 ? 0.78 : hours < 6 ? 0.92 : 1.05
                readonly property bool sleepy: ScreenTime.idle
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Item {
                        width: 22
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        Pine {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 22
                            height: 22
                            scale: pet.grow
                            transformOrigin: Item.Bottom
                            color: pet.sleepy ? Theme.text3 : Theme.green
                            SequentialAnimation on rotation {
                                running: pet.on && !pet.sleepy
                                loops: Animation.Infinite
                                NumberAnimation { to: 5; duration: 1400; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -5; duration: 1400; easing.type: Easing.InOutSine }
                            }
                        }
                        Label {
                            visible: pet.sleepy
                            x: 16
                            y: -4
                            text: "z"
                            size: 10
                            dim: true
                        }
                        Label {
                            visible: pet.hours >= 6 && !pet.sleepy
                            x: 16
                            y: -4
                            text: "✦"
                            size: 9
                            color: Theme.orange
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pet.sleepy ? "Сосенка спит" : pet.hours < 1 ? "Росток" : pet.hours < 3 ? "Сосенка растёт" : pet.hours < 6 ? "Сосна крепнет" : "Сосна в силе"
                        size: 12
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ScreenTime.fmt(ScreenTime.total)
                        size: 11
                        dim: true
                    }
                }
            }

            // ── Клик в покое: карточка «Сегодня» ──
            View {
                on: win.view === "idle" && Island.expanded
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    anchors.topMargin: 22
                    spacing: 18
                    Column {
                        Text {
                            text: Qt.formatTime(islandClock.date, "hh:mm")
                            font.family: Theme.font
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                            color: Theme.text
                        }
                        Label {
                            text: {
                                const s = islandClock.date.toLocaleString(Qt.locale("ru_RU"), "dddd, d MMM");
                                return s.charAt(0).toUpperCase() + s.slice(1);
                            }
                            size: 12
                            color: Theme.accent
                        }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.hairline }
                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Row {
                            spacing: 6
                            visible: Weather.ready
                            Icon { text: Weather.icon; size: 18; fill: true; color: Theme.accent }
                            Label { text: Weather.signed(Weather.temp) + "  " + Weather.desc; size: 13; weight: Font.DemiBold }
                        }
                        Row {
                            spacing: 6
                            Icon { text: "hourglass_bottom"; size: 16; color: Theme.text2 }
                            Label { text: "Экран: " + ScreenTime.fmt(ScreenTime.total); size: 12; dim: true }
                        }
                        Row {
                            spacing: 6
                            visible: Island.countdown() > 0
                            Icon { text: "event"; size: 16; color: Theme.text2 }
                            Label { text: Config.o.countdownTitle + " — через " + Island.countdown() + " дн."; size: 12; dim: true }
                        }
                    }
                }
            }

            // ── Быстрые действия (долгое нажатие) ──
            View {
                on: win.view === "actions"
                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    spacing: 6
                    Repeater {
                        model: [
                            { g: "screenshot_region", t: "Снимок", run: () => Shot.pick() },
                            { g: "radio_button_checked", t: Recorder.active ? "Стоп" : "Запись", on: Recorder.active, run: () => Recorder.toggle() },
                            { g: "timer", t: "Фокус", on: Focus.running, run: () => Focus.toggle() },
                            { g: "colorize", t: "Пипетка", run: () => Shot.pickColor() },
                            { g: "coffee", t: "Кофе", on: Idle.coffee, run: () => Idle.coffee = !Idle.coffee },
                            { g: "do_not_disturb_on", t: "Тишина", on: Notifs.dnd, run: () => Notifs.dnd = !Notifs.dnd },
                            { g: "lock", t: "Замок", run: () => Session.lock() }
                        ]
                        delegate: Column {
                            id: qa
                            required property var modelData
                            required property int index
                            spacing: 5
                            opacity: 0
                            Component.onCompleted: appear.start()
                            // Появляются по очереди
                            SequentialAnimation {
                                id: appear
                                PauseAnimation { duration: qa.index * 35 }
                                NumberAnimation { target: qa; property: "opacity"; to: 1; duration: 180 }
                            }
                            HoverButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44
                                height: 44
                                radius: 22
                                hoverScale: 1.15
                                color: qa.modelData.on ? Theme.accent : hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                                onClicked: {
                                    Island.dismiss();
                                    qa.modelData.run();
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    text: qa.modelData.g
                                    size: 20
                                    fill: !!qa.modelData.on
                                    color: qa.modelData.on ? Theme.inkOnAccent : Theme.text
                                }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qa.modelData.t
                                size: 10.5
                                dim: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Мелкие компоненты острова ──
    component View: Item {
        property bool on: false
        anchors.fill: parent
        opacity: on ? 1 : 0
        visible: opacity > 0
        scale: on ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: on ? 260 : 120 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    component Art: ClippingRectangle {
        id: artRoot
        property real size: 22
        width: size
        height: size
        color: Theme.tile
        Image {
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(128, 128)
            asynchronous: true
        }
        Icon {
            anchors.centerIn: parent
            visible: !Media.art
            text: "music_note"
            size: artRoot.size * 0.6
            color: Theme.text2
        }
    }

    component Bars: Row {
        spacing: 2
        height: 18
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 3
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                height: Media.playing ? 4 + 14 * (Cava.bars[index] ?? 0) : 4
                color: Theme.accent
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }

    component IconBtn: Rectangle {
        property string icon
        property bool big: false
        signal clicked
        width: big ? 38 : 32
        height: width
        radius: width / 2
        color: ib.containsMouse ? Theme.alpha(Theme.text, 0.12) : "transparent"
        Icon {
            anchors.centerIn: parent
            text: parent.icon
            size: parent.big ? 28 : 22
            fill: true
        }
        MouseArea {
            id: ib
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component Chip: Rectangle {
        property alias text: chipL.text
        signal clicked
        width: chipL.implicitWidth + 22
        height: 26
        radius: 13
        color: chipA.containsMouse ? Theme.alpha(Theme.text, 0.2) : Theme.alpha(Theme.text, 0.1)
        Label {
            id: chipL
            anchors.centerIn: parent
            size: 12
        }
        MouseArea {
            id: chipA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
