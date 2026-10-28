import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// Spotlight: Super. Префиксы: = калькулятор, > команды, : эмодзи, ? веб, ~ файлы, ; буфер
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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sosna-spotlight"
    WlrLayershell.keyboardFocus: Ui.spotlightOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool alive: false
    visible: Ui.spotlightOpen || alive

    readonly property var modes: [
        { p: "", n: "Всё", g: "search" },
        { p: "=", n: "Счёт", g: "calculate" },
        { p: ">", n: "Команды", g: "terminal" },
        { p: ":", n: "Эмодзи", g: "mood" },
        { p: "?", n: "Веб", g: "travel_explore" },
        { p: "~", n: "Файлы", g: "folder" },
        { p: ";", n: "Буфер", g: "content_paste" }
    ]

    readonly property string text: input.text
    readonly property string prefix: text.length > 0 && "=>:?~;".includes(text[0]) ? text[0] : ""
    readonly property string query: prefix ? text.slice(1) : text
    readonly property bool grid: prefix === ":" || launchpad
    readonly property bool launchpad: prefix === "" && query.trim() === ""
    readonly property int cols: launchpad ? 7 : 10
    readonly property bool preview: (prefix === ";" || prefix === "~") && current && (current.image || current.full)

    property int index: 0
    readonly property var current: results[index] ?? null

    readonly property var results: {
        const q = query;
        switch (prefix) {
        case "=":
            return Launcher.calc && Launcher.calcFor === q.trim()
                ? [{ kind: "calc", glyph: "calculate", title: Launcher.calc, sub: q.trim() + "  ·  Enter — скопировать", run: () => Launcher.copy(Launcher.calc.replace(/^.*=\s*/, ""), Launcher.calc) }]
                : [];
        case ">":
            return Launcher.searchCommands(q, true);
        case ":":
            return Launcher.searchEmoji(q);
        case "?":
            return Launcher.webItems(q);
        case "~":
            return Launcher.fileItems(q);
        case ";":
            return Launcher.clipItems(q);
        }
        let res = [];
        if (Launcher.looksLikeMath(q) && Launcher.calc && Launcher.calcFor === q.trim())
            res.push({ kind: "calc", glyph: "calculate", title: Launcher.calc.replace(/^.*=\s*/, "= "), sub: "Калькулятор  ·  Enter — скопировать", run: () => Launcher.copy(Launcher.calc.replace(/^.*=\s*/, ""), Launcher.calc) });
        res = res.concat(Launcher.searchApps(q));
        if (q.trim())
            res = res.concat(Launcher.searchCommands(q, false).slice(0, 4));
        if (q.trim().length > 1)
            res.push({ kind: "web", glyph: "travel_explore", title: q.trim(), sub: "Искать в интернете", run: () => Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(q.trim())]) });
        return res;
    }

    onResultsChanged: index = Math.max(0, Math.min(index, results.length - 1))
    onQueryChanged: {
        index = 0;
        if (prefix === "=" || (prefix === "" && Launcher.looksLikeMath(query)))
            Launcher.compute(query);
        if (prefix === "~")
            Launcher.findFiles(query);
    }
    onPrefixChanged: {
        index = 0;
        if (prefix === ";")
            Launcher.loadClips();
        if (prefix === "=")
            Launcher.compute(query);
        if (prefix === "~")
            Launcher.findFiles(query);
    }

    function run(item, alt: bool): void {
        if (!item)
            return;
        Ui.spotlightOpen = false;
        if (alt && item.alt)
            item.alt();
        else
            item.run();
        if (item.kind === "clip")
            Island.show("text", { title: "Скопировано", body: item.image ? "Картинка" : item.title.slice(0, 40) }, 1500);
    }

    property var menuItem: null
    function openMenu(item, from: Item): void {
        const p = from.mapToItem(panel, from.width / 2, from.height / 2);
        appMenu.x = Math.min(panel.width - appMenu.width - 8, p.x);
        appMenu.y = p.y;
        menuItem = item;
        appMenu.open = true;
    }

    function move(d: int): void {
        if (results.length === 0)
            return;
        index = (index + d + results.length) % results.length;
    }

    function setMode(p: string): void {
        input.text = p + query;
        input.forceActiveFocus();
    }

    Connections {
        target: Ui
        function onSpotlightOpenChanged(): void {
            if (Ui.spotlightOpen) {
                closeTimer.stop();
                win.alive = true;
                input.text = Ui.spotlightPrefix;
                win.index = 0;
                appMenu.open = false;
                if (Ui.spotlightPrefix === ";")
                    Launcher.loadClips();
                input.forceActiveFocus();
            } else {
                closeTimer.restart();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 220
        onTriggered: win.alive = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ui.spotlightOpen = false
    }

    Glass {
        id: panel

        strong: true
        radius: 20
        width: win.preview || win.launchpad ? 860 : 700
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        x: (win.width - width) / 2
        y: Math.round(win.height * 0.18)
        height: 62 + (body.visible ? body.height + 1 : 0) + 38
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        clip: true

        opacity: Ui.spotlightOpen ? 1 : 0
        scale: Ui.spotlightOpen ? 1 : 0.94
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Ui.spotlightOpen ? 180 : 140 } }
        Behavior on scale { NumberAnimation { duration: Ui.spotlightOpen ? 320 : 160; easing.type: Ui.spotlightOpen ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.3 } }

        MouseArea {
            anchors.fill: parent
        }

        // ───── Поле ввода ─────
        Item {
            id: field
            width: parent.width
            height: 62

            Icon {
                id: lens
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                text: win.modes.find(m => m.p === win.prefix)?.g ?? "search"
                size: 24
                weight: 300
                color: win.prefix ? Theme.accent : Theme.text2
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            TextInput {
                id: input
                anchors.left: lens.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 23
                font.weight: Font.Light
                color: Theme.text
                selectionColor: Theme.alpha(Theme.accent, 0.5)
                selectedTextColor: Theme.text
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.accent
                    radius: 1
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                    }
                }
                focus: true

                Text {
                    visible: !input.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Поиск в Сосне  ·  " + Launcher.apps.length + " программ"
                    font: input.font
                    color: Theme.text3
                }

                Keys.onPressed: e => {
                    const cols = win.cols;
                    if (e.key === Qt.Key_Escape && appMenu.open) {
                        appMenu.open = false;
                    } else if (e.key === Qt.Key_Escape) {
                        if (input.text)
                            input.text = "";
                        else
                            Ui.spotlightOpen = false;
                    } else if (e.key === Qt.Key_Down) {
                        win.move(win.grid ? cols : 1);
                    } else if (e.key === Qt.Key_Up) {
                        win.move(win.grid ? -cols : -1);
                    } else if (win.grid && e.key === Qt.Key_Right && input.cursorPosition === input.text.length) {
                        win.move(1);
                    } else if (win.grid && e.key === Qt.Key_Left && input.cursorPosition === input.text.length) {
                        win.move(-1);
                    } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                        const i = win.modes.findIndex(m => m.p === win.prefix);
                        const n = win.modes.length;
                        win.setMode(win.modes[(i + (e.key === Qt.Key_Tab ? 1 : n - 1)) % n].p);
                    } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.AltModifier) && win.current?.pin) {
                        win.current.pin();
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        win.run(win.current, e.modifiers & Qt.ShiftModifier);
                    } else if (e.key === Qt.Key_Delete && win.current?.del) {
                        win.current.del();
                    } else if (e.key === Qt.Key_Backspace && input.text.length === 1 && win.prefix) {
                        input.text = "";
                    } else {
                        return;
                    }
                    e.accepted = true;
                }
            }
        }

        Rectangle {
            anchors.top: field.bottom
            width: parent.width
            height: 1
            color: Theme.hairline
            visible: body.visible
        }

        // ───── Результаты ─────
        Item {
            id: body
            anchors.top: field.bottom
            anchors.topMargin: 1
            width: parent.width
            visible: win.results.length > 0 || empty.visible
            height: win.launchpad ? Math.min(4, Math.ceil(win.results.length / 7)) * 100 + 20 : win.grid ? Math.min(6, Math.ceil(win.results.length / 10)) * 62 + 16 : Math.max(empty.visible ? 120 : 0, Math.min(8, win.results.length) * 50 + 12)

            ListView {
                id: list
                visible: !win.grid
                anchors.fill: parent
                anchors.margins: 6
                anchors.rightMargin: win.preview ? 330 : 6
                model: win.grid ? [] : win.results
                currentIndex: win.index
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 140
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: 11
                    color: Theme.accent
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: ListView.isCurrentItem
                    width: list.width
                    height: 50

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onPositionChanged: win.index = row.index
                        onClicked: m => {
                            if (m.button === Qt.RightButton && row.modelData.pin)
                                win.openMenu(row.modelData, row);
                            else if (m.button === Qt.MiddleButton && row.modelData.del)
                                row.modelData.del();
                            else
                                win.run(row.modelData, m.modifiers & Qt.ShiftModifier);
                        }
                    }

                    Item {
                        id: ic
                        x: 10
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        scale: row.sel ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                        IconImage {
                            anchors.fill: parent
                            visible: row.modelData.kind === "app"
                            source: visible ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                            asynchronous: true
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 7
                            visible: !!row.modelData.image
                            color: Theme.tile
                            Image {
                                anchors.fill: parent
                                source: parent.visible ? row.modelData.image : ""
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            visible: row.modelData.kind !== "app" && !row.modelData.image
                            color: row.sel ? Theme.alpha(Theme.inkOnAccent, 0.14) : Theme.tile
                            Icon {
                                anchors.centerIn: parent
                                text: row.modelData.glyph ?? "circle"
                                size: 19
                                color: row.sel ? Theme.inkOnAccent : Theme.text
                            }
                        }
                    }

                    Column {
                        anchors.left: ic.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Label {
                            width: parent.width
                            text: row.modelData.title
                            size: row.modelData.kind === "calc" ? 17 : 14
                            weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Medium
                            color: row.sel ? Theme.inkOnAccent : Theme.text
                            maximumLineCount: 1
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.sub ?? ""
                            size: 11.5
                            color: row.sel ? Theme.alpha(Theme.inkOnAccent, 0.7) : Theme.text3
                        }
                    }
                }
            }

            // Эмодзи — сеткой
            GridView {
                id: emojiGrid
                visible: win.grid
                anchors.fill: parent
                anchors.margins: 8
                cellWidth: width / win.cols
                cellHeight: win.launchpad ? 100 : 62
                model: win.grid ? win.results : []
                currentIndex: win.index
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                highlight: Rectangle {
                    radius: 12
                    color: Theme.alpha(Theme.accent, 0.35)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.8)
                }
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: emojiGrid.cellWidth
                    height: emojiGrid.cellHeight
                    Text {
                        visible: !win.launchpad
                        anchors.centerIn: parent
                        text: cell.modelData.emoji ?? ""
                        font.pixelSize: 30
                        scale: cellMouse.containsMouse ? 1.3 : cell.GridView.isCurrentItem ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    }
                    // Программа: значок + подпись
                    Column {
                        visible: win.launchpad
                        anchors.centerIn: parent
                        spacing: 6
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 52
                            source: win.launchpad ? Quickshell.iconPath(cell.modelData.icon, "application-x-executable") : ""
                            asynchronous: true
                            scale: cellMouse.containsMouse ? 1.18 : cell.GridView.isCurrentItem ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        }
                        Label {
                            width: emojiGrid.cellWidth - 10
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.title ?? ""
                            size: 11.5
                            color: cell.GridView.isCurrentItem ? Theme.text : Theme.text2
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: win.index = cell.index
                        onClicked: m => {
                            if (m.button === Qt.RightButton && cell.modelData.pin)
                                win.openMenu(cell.modelData, cell);
                            else
                                win.run(cell.modelData, false);
                        }
                    }
                }
            }

            // Пусто
            Column {
                id: empty
                anchors.centerIn: parent
                spacing: 8
                visible: win.results.length === 0 && (win.query.trim() !== "" || win.prefix !== "")
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Launcher.filesBusy && win.prefix === "~" ? "hourglass_top" : win.prefix === "=" ? "calculate" : "search_off"
                    size: 34
                    weight: 300
                    color: Theme.text3
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.prefix === "=" ? "Например: 15% от 2400, 100 usd to rub, sqrt(2)"
                        : win.prefix === "~" ? (win.query.trim().length < 2 ? "Начни писать имя файла" : Launcher.filesBusy ? "Ищу…" : "Ничего не найдено")
                        : win.prefix === ";" ? "Буфер пуст"
                        : "Ничего не найдено"
                    dim: true
                }
            }

            // Предпросмотр (буфер, картинки)
            Rectangle {
                visible: win.preview
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: 314
                radius: 12
                color: Qt.rgba(0.0, 0.0, 0.0, 0.18)
                border.width: 1
                border.color: Theme.hairline
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: !!win.current?.image
                    source: visible ? win.current.image : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(600, 600)
                    asynchronous: true
                    cache: false
                }
                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: !win.current?.image
                    text: win.current?.full ?? ""
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }

        // ───── Меню программы (правый клик) ─────
        MouseArea {
            anchors.fill: parent
            visible: appMenu.open
            z: 19
            onClicked: appMenu.open = false
        }
        Pop {
            id: appMenu
            z: 20
            origin: Item.TopLeft
            width: 220
            height: appMenuCol.implicitHeight + 10
            radius: 11
            Column {
                id: appMenuCol
                anchors.fill: parent
                anchors.margins: 5
                MenuRow {
                    width: parent.width
                    text: "Открыть"
                    icon: "open_in_new"
                    onClicked: {
                        appMenu.open = false;
                        win.run(win.menuItem, false);
                    }
                }
                MenuRow {
                    width: parent.width
                    text: DockModel.isPinned(win.menuItem?.id ?? "") ? "Убрать из Дока" : "Закрепить в Доке"
                    icon: DockModel.isPinned(win.menuItem?.id ?? "") ? "keep_off" : "keep"
                    hint: "Alt ↵"
                    onClicked: {
                        appMenu.open = false;
                        win.menuItem.pin();
                    }
                }
            }
        }

        // ───── Нижняя строка: режимы ─────
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 38
            color: Qt.rgba(0.0, 0.0, 0.0, 0.12)

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            Row {
                id: chips
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: win.modes
                    delegate: HoverButton {
                        id: chip
                        required property var modelData
                        readonly property bool on: win.prefix === modelData.p
                        width: chipRow.implicitWidth + 16
                        height: 26
                        radius: 13
                        hoverScale: 1.06
                        color: on ? Theme.alpha(Theme.accent, 0.25) : hovered ? Theme.tileHover : "transparent"
                        border.width: on ? 1 : 0
                        border.color: Theme.alpha(Theme.accent, 0.6)
                        onClicked: win.setMode(modelData.p)

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                visible: chip.modelData.p !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.p
                                font.family: Theme.mono
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: chip.on ? Theme.accent : Theme.text3
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.n
                                size: 12
                                color: chip.on ? Theme.text : Theme.text2
                            }
                        }
                    }
                }
            }

            Label {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, panel.width - chips.width - 44)
                horizontalAlignment: Text.AlignRight
                text: win.prefix === ":" ? (win.current?.title ?? "") : win.prefix === ";" ? "Del — удалить" : win.prefix === "~" ? "⇧↵ — в папке" : win.current?.pin ? "Alt↵ / ПКМ — в Док" : "Tab — режим"
                size: 11.5
                color: Theme.text3
            }
        }
    }
}
