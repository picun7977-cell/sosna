import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// Док: увеличение под курсором, прыжок при запуске, правый клик — закрепить, перетаскивание — порядок,
// наведение на запущенное — превью окон. Прячется, когда на столе есть окна; вызывается подводом мыши к низу.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    color: "transparent"
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 300
    // Док не прячется — окна не заходят под него
    exclusionMode: Config.o.dockAutohide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: Config.o.dockAutohide || Hypr.fullscreen ? 0 : base + 30
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "sosna-dock"

    readonly property real base: Config.o.dockIcon
    readonly property real maxScale: Config.o.dockMagnify ? Config.o.dockMaxScale : 1
    // Насколько вытянуть значок вверх, чтобы убрать его из дока
    readonly property real removeAt: 90

    // Правая часть дока: «Загрузки», свои папки, корзина (её убрать нельзя, как на маке)
    readonly property var extras: {
        const res = [];
        if (Config.o.dockDownloads)
            res.push({ key: "downloads", path: Quickshell.env("HOME") + "/Downloads", icon: "folder-download", label: "Загрузки" });
        for (const p of Config.o.dockFolders ?? [])
            res.push({ key: p, path: p, icon: folderIcon(p), label: p.replace(/\/$/, "").split("/").pop() || p });
        return res;
    }

    function folderIcon(p: string): string {
        const name = p.replace(/\/$/, "").split("/").pop();
        const map = { "Documents": "folder-documents", "Документы": "folder-documents", "Pictures": "folder-pictures", "Изображения": "folder-pictures",
            "Music": "folder-music", "Музыка": "folder-music", "Videos": "folder-videos", "Видео": "folder-videos", "Desktop": "user-desktop",
            "Screenshots": "folder-pictures", "Wallpapers": "folder-pictures", "Downloads": "folder-download", "Загрузки": "folder-download" };
        if (p === Quickshell.env("HOME"))
            return "user-home";
        return map[name] ?? (/\.(desktop)$/.test(p) ? "application-x-executable" : "folder");
    }

    function removeExtra(key: string): void {
        if (key === "downloads")
            Config.o.dockDownloads = false;
        else
            Config.o.dockFolders = (Config.o.dockFolders ?? []).filter(p => p !== key);
    }

    // Добавить из перетаскивания (Thunar и т. п.): .desktop — закрепить программу, остальное — папкой/файлом справа
    function addPaths(urls: var): void {
        const folders = (Config.o.dockFolders ?? []).slice();
        for (const u of urls) {
            const path = decodeURIComponent(String(u).replace(/^file:\/\//, ""));
            if (path.endsWith(".desktop")) {
                DockModel.pin(path.split("/").pop().replace(/\.desktop$/, ""));
            } else if (!folders.includes(path)) {
                folders.push(path);
            }
        }
        Config.o.dockFolders = folders;
    }

    // «Пуф» — облачко там, где значок отпустили
    function poof(gx: real, gy: real): void {
        poofFx.x = gx - poofFx.width / 2;
        poofFx.y = gy - poofFx.height / 2;
        poofAnim.restart();
        Sounds.play("poof");
    }
    // Увеличение считаем по «спокойной» раскладке (без увеличения), иначе петля привязок
    readonly property real restW: base + 8
    readonly property real restWidth: (DockModel.ids.length + extras.length + 1) * restW + 13
    property real mouseX: -1000
    property real smoothX: mouseX
    Behavior on smoothX { enabled: dockHover.containsMouse; SmoothedAnimation { velocity: 2400; duration: 90 } }
    property Item hoverSlot: null
    onHoverSlotChanged: {
        tip.target = hoverSlot;
        if (hoverSlot)
            tip.text = hoverSlot.label;
        if (hoverSlot && hoverSlot.running && !preview.open)
            previewTimer.restart();
        else
            previewTimer.stop();
        if (preview.open && hoverSlot && hoverSlot.item && hoverSlot.item !== previewItem && hoverSlot.running) {
            previewItem = hoverSlot.item;
            previewX = hoverSlot.mapToItem(null, hoverSlot.width / 2, 0).x;
        }
    }
    Timer {
        id: previewTimer
        interval: 750
        onTriggered: {
            if (!win.hoverSlot || !win.hoverSlot.item)
                return;
            win.previewItem = win.hoverSlot.item;
            win.previewX = win.hoverSlot.mapToItem(null, win.hoverSlot.width / 2, 0).x;
            preview.open = true;
            tip.target = null;
        }
    }
    property bool hovering: dockHover.containsMouse || edge.containsMouse || menu.open || preview.open || stack.open
    property var menuItem: null
    property var previewItem: null
    property real previewX: 0
    property string dragId: ""
    property real dragDx: 0
    property real dragDy: 0
    readonly property bool dragRemove: dragId !== "" && dragDy < -removeAt

    readonly property bool shown: Ui.entered && !Hypr.fullscreen && !Session.locked && !Ui.missionOpen
        && (!Config.o.dockAutohide || Hypr.wsEmpty || hovering || Ui.dockReveal || dragId !== "")

    mask: Region {
        item: shown ? dockHover : edgeStrip
        Region { item: menu.visible ? menu : null }
        Region { item: preview.visible ? preview : null }
        Region { item: stack.visible ? stack : null }
        Region { item: tip.visible ? tip : null }
    }

    onShownChanged: if (!shown) {
        menu.open = false;
        preview.open = false;
        stack.open = false;
    }

    // Узкая полоса у нижнего края — подвёл мышь, док выехал
    Item {
        id: edgeStrip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.width
        height: 4
        MouseArea {
            id: edge
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // Позиция мыши для увеличения: обновляют и фон дока, и сами значки
    function track(item: Item, mx: real, my: real): void {
        const p = item.mapToItem(null, mx, my);
        mouseX = p.x - (width / 2 - restWidth / 2);
    }

    function scaleFor(cx: real): real {
        if (!dockHover.containsMouse || dragId !== "")
            return 1;
        const d = Math.abs(cx - smoothX);
        return 1 + (maxScale - 1) * Math.exp(-(d * d) / (2 * 78 * 78));
    }

    Glass {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.shown ? win.height - height - 8 : win.height + 12
        width: row.width + 20
        height: win.base + 22
        radius: 24
        color: Qt.rgba(0.118, 0.122, 0.141, 0.42)
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        MouseArea {
            id: dockHover
            anchors.fill: parent
            anchors.topMargin: -40
            anchors.bottomMargin: -12
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            z: 10
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            // Один слой наведения поверх значков: клики проходят насквозь, а позиция мыши известна всегда.
            // Координата — в «спокойной» раскладке от центра экрана, иначе док дёргается.
            onPositionChanged: m => {
                win.track(dockHover, m.x, m.y);
                const p = mapToItem(row, m.x, m.y);
                const c = row.childAt(Math.max(0, Math.min(row.width - 1, p.x)), row.height - 4);
                win.hoverSlot = c && c.label !== undefined ? c : null;
            }
            onExited: {
                win.mouseX = -1000;
                win.hoverSlot = null;
            }
        }

        // Перетащили файлы/папки/ярлыки из файлового менеджера — добавляем в док
        DropArea {
            anchors.fill: parent
            anchors.topMargin: -30
            keys: ["text/uri-list"]
            onDropped: d => {
                if (d.hasUrls)
                    win.addPaths(d.urls);
            }
        }

        Row {
            id: row
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: DockModel.ids
                }

                Item {
                    id: slot

                    required property string modelData
                    required property int index
                    readonly property var item: DockModel.get(modelData)
                    readonly property real cx: x + width / 2
                    readonly property real s: win.scaleFor(index * win.restW + win.restW / 2)
                    readonly property bool running: item.windows.length > 0
                    readonly property bool dragging: win.dragId === modelData
                    readonly property string label: item.entry?.name ?? Hypr.prettify(modelData)

                    width: win.base * s + 8
                    height: win.base * win.maxScale + 8
                    Behavior on width { enabled: !dockHover.containsMouse; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // Разделитель между закреплёнными и прочими
                    Rectangle {
                        visible: !slot.item.pinned && slot.index > 0 && DockModel.get(DockModel.ids[slot.index - 1]).pinned
                        x: -1
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: 1
                        height: win.base - 6
                        color: Theme.alpha(Theme.text, 0.2)
                    }

                    Item {
                        id: iconBox
                        width: win.base * slot.s
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: slot.dragging ? win.dragDx : 0
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6 + bounce.offset + (slot.dragging ? Math.max(0, -win.dragDy) : 0)
                        z: slot.dragging ? 10 : 0

                        RemoveBadge {
                            on: slot.dragging && win.dragRemove
                        }

                        QtObject {
                            id: bounce
                            property real offset: 0
                        }
                        SequentialAnimation {
                            running: DockModel.isLaunching(slot.item.id)
                            loops: Animation.Infinite
                            onStopped: bounce.offset = 0
                            NumberAnimation { target: bounce; property: "offset"; to: 22; duration: 300; easing.type: Easing.OutQuad }
                            NumberAnimation { target: bounce; property: "offset"; to: 0; duration: 300; easing.type: Easing.InQuad }
                            PauseAnimation { duration: 60 }
                        }

                        // Фиксированное разрешение: при увеличении картинка не перезагружается и не мигает
                        Image {
                            anchors.fill: parent
                            source: Quickshell.iconPath(slot.item.entry?.icon ?? slot.item.id, "application-x-executable")
                            sourceSize: Qt.size(128, 128)
                            smooth: true
                            mipmap: true
                            opacity: slot.dragging && win.dragRemove ? 0.55 : area.pressed && !slot.dragging ? 0.7 : 1
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }

                    // Точка «запущено»
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.alpha(Theme.text, 0.8)
                        opacity: slot.running ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        property real pressX: 0
                        property real pressY: 0
                        property bool moved: false

                        Component.onDestruction: {
                            if (win.hoverSlot === slot)
                                win.hoverSlot = null;
                            if (tip.target === slot)
                                tip.target = null;
                        }
                        onPressed: m => {
                            pressX = m.x;
                            pressY = m.y;
                            moved = false;
                        }
                        onPositionChanged: m => {
                            win.track(area, m.x, m.y);
                            if (!pressed || !slot.item.pinned || m.buttons !== Qt.LeftButton)
                                return;
                            if (!moved && (Math.abs(m.x - pressX) > 8 || Math.abs(m.y - pressY) > 8)) {
                                moved = true;
                                win.dragId = slot.item.id;
                                tip.target = null;
                                previewTimer.stop();
                                preview.open = false;
                            }
                            if (moved) {
                                win.dragDx = m.x - pressX;
                                win.dragDy = m.y - pressY;
                            }
                        }
                        onReleased: m => {
                            if (moved && win.dragRemove) {
                                // Вытащили из дока — «пуф», и значка нет (окна программы остаются)
                                const g = iconBox.mapToItem(null, iconBox.width / 2, iconBox.height / 2);
                                const id = slot.item.id;
                                win.dragId = "";
                                win.dragDx = win.dragDy = 0;
                                win.poof(g.x, g.y);
                                DockModel.unpin(id);
                            } else if (moved) {
                                // куда бросили: ближайший слот среди закреплённых
                                const dropX = slot.cx + win.dragDx;
                                let best = 0, bestD = 1e9, i = 0;
                                for (const child of row.children) {
                                    if (!child.item || !child.item.pinned)
                                        continue;
                                    const d = Math.abs(child.cx - dropX);
                                    if (d < bestD) {
                                        bestD = d;
                                        best = i;
                                    }
                                    i++;
                                }
                                DockModel.move(slot.item.id, best);
                                win.dragId = "";
                                win.dragDx = win.dragDy = 0;
                            }
                        }
                        onClicked: m => {
                            if (moved)
                                return;
                            previewTimer.stop();
                            preview.open = false;
                            if (m.button === Qt.RightButton) {
                                win.menuItem = slot.item;
                                menu.anchorX = slot.mapToItem(null, slot.width / 2, 0).x;
                                menu.open = true;
                                tip.target = null;
                            } else if (m.button === Qt.MiddleButton) {
                                DockModel.launch(slot.item);
                            } else {
                                DockModel.activate(slot.item);
                            }
                        }


                    }
                }
            }

            // Разделитель перед «Загрузками» и корзиной
            Item {
                width: 13
                height: win.base * win.maxScale + 8
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1
                    height: win.base - 6
                    color: Theme.alpha(Theme.text, 0.2)
                }
            }

            Repeater {
                model: win.extras
                delegate: Extra {
                    required property var modelData
                    required property int index
                    key: modelData.key
                    restIndex: index
                    icon: modelData.icon
                    label: modelData.label
                    onActivated: {
                        stack.path = modelData.path;
                        stack.title = modelData.label;
                        stackProc.running = false;
                        stackProc.running = true;
                        stack.anchorX = mapToItem(null, width / 2, 0).x;
                        stack.open = !stack.open;
                    }
                    onSecondary: {
                        win.menuItem = { folder: modelData };
                        menu.anchorX = mapToItem(null, width / 2, 0).x;
                        menu.open = true;
                    }
                }
            }
            Extra {
                id: trash
                key: "trash"
                restIndex: win.extras.length
                icon: trashCount > 0 ? "user-trash-full" : "user-trash"
                label: trashCount > 0 ? "Корзина · " + trashCount : "Корзина"
                property int trashCount: 0
                onActivated: Quickshell.execDetached(["thunar", "trash:///"])
                onSecondary: {
                    win.menuItem = { trash: true };
                    menu.anchorX = mapToItem(null, width / 2, 0).x;
                    menu.open = true;
                }
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
                if (p)
                    win.addPaths(["file://" + p]);
            }
        }
    }

    // Облачко «пуф»
    Item {
        id: poofFx
        width: 90
        height: 90
        z: 100
        visible: poofAnim.running
        property real k: 0
        Repeater {
            model: 7
            delegate: Rectangle {
                required property int index
                readonly property real a: index / 7 * Math.PI * 2
                width: 26 + (index % 3) * 8
                height: width
                radius: width / 2
                color: Qt.rgba(0.95, 0.95, 0.97, 0.9 * (1 - poofFx.k))
                x: poofFx.width / 2 - width / 2 + Math.cos(a) * 30 * poofFx.k
                y: poofFx.height / 2 - height / 2 + Math.sin(a) * 30 * poofFx.k
                scale: 0.4 + poofFx.k * 0.9
            }
        }
        NumberAnimation {
            id: poofAnim
            target: poofFx
            property: "k"
            from: 0
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    // Счётчик корзины
    Process {
        id: trashProc
        command: ["sh", "-c", "ls -A \"$HOME/.local/share/Trash/files\" 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: trash.trashCount = parseInt(text) || 0
        }
    }
    Timer {
        running: win.shown
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: trashProc.running = true
    }

    // ── Подсказка с именем ──
    Glass {
        id: tip
        property Item target: null
        property alias text: tipL.text
        visible: opacity > 0.01
        opacity: target !== null && dockHover.containsMouse && win.shown && !menu.open && !preview.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        width: tipL.implicitWidth + 22
        height: 26
        radius: 9
        strong: true
        x: target ? target.mapToItem(null, target.width / 2, 0).x - width / 2 : x
        Behavior on x { enabled: tip.opacity > 0.5; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        y: dock.y - height - 8 - win.base * (win.maxScale - 1)
        Label {
            id: tipL
            anchors.centerIn: parent
            size: 12.5
        }
    }

    // ── Контекстное меню значка ──
    Pop {
        id: menu
        property real anchorX: 0
        radius: 12
        width: 230
        height: menuCol.implicitHeight + 10
        x: Math.max(8, Math.min(win.width - width - 8, anchorX - width / 2))
        y: dock.y - height - 10

        Column {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 5

            MenuRow {
                visible: !!win.menuItem?.folder
                text: "Открыть в Файлах"
                icon: "folder_open"
                onClicked: Quickshell.execDetached(["thunar", win.menuItem.folder.path])
            }
            MenuRow {
                visible: !!win.menuItem?.folder
                text: "Убрать из Дока"
                icon: "remove_circle"
                onClicked: win.removeExtra(win.menuItem.folder.key)
            }
            MenuRow {
                visible: !!win.menuItem?.folder || !!win.menuItem?.trash
                text: "Добавить папку…"
                icon: "create_new_folder"
                onClicked: folderPick.running = true
            }
            MenuRow {
                visible: !!win.menuItem?.folder || !!win.menuItem?.trash
                text: "Добавить программу…"
                icon: "apps"
                onClicked: Ui.spotlight("")
            }
            MenuRow {
                visible: !win.menuItem?.trash && !win.menuItem?.folder
                text: DockModel.isPinned(win.menuItem?.id ?? "") ? "Открепить от Дока" : "Закрепить в Доке"
                icon: DockModel.isPinned(win.menuItem?.id ?? "") ? "keep_off" : "keep"
                onClicked: {
                    const id = win.menuItem.id;
                    DockModel.isPinned(id) ? DockModel.unpin(id) : DockModel.pin(id);
                }
            }
            MenuRow {
                visible: !win.menuItem?.trash && !win.menuItem?.folder && !!win.menuItem?.entry
                text: "Новое окно"
                icon: "add"
                onClicked: DockModel.launch(win.menuItem)
            }
            MenuRow {
                visible: !win.menuItem?.trash && !win.menuItem?.folder
                text: "Настройки Дока…"
                icon: "settings"
                onClicked: Ui.openSettings("dock")
            }
            MenuRow {
                visible: (win.menuItem?.windows?.length ?? 0) > 0
                text: "Показать все окна"
                icon: "grid_view"
                onClicked: Ui.toggle("missionOpen")
            }
            Rectangle {
                visible: (win.menuItem?.windows?.length ?? 0) > 0
                width: parent.width
                height: 9
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Theme.hairline
                }
            }
            MenuRow {
                visible: (win.menuItem?.windows?.length ?? 0) > 0
                text: (win.menuItem?.windows?.length ?? 0) > 1 ? "Закрыть все окна" : "Закрыть"
                icon: "close"
                onClicked: {
                    for (const w of win.menuItem.windows)
                        Hypr.closeWindow(w.address);
                }
            }
            MenuRow {
                visible: !!win.menuItem?.trash
                text: "Открыть корзину"
                icon: "folder_open"
                onClicked: Quickshell.execDetached(["thunar", "trash:///"])
            }
            MenuRow {
                visible: !!win.menuItem?.trash
                text: "Очистить корзину"
                icon: "delete_forever"
                onClicked: Quickshell.execDetached(["gio", "trash", "--empty"])
            }
        }

        // Клик мимо меню — закрыть (меню живёт в слое дока, поэтому ждём ухода мыши)
        Timer {
            running: menu.open && !menuHover.containsMouse
            interval: 1600
            onTriggered: menu.open = false
        }
        MouseArea {
            id: menuHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    // ── Превью окон приложения ──
    Pop {
        id: preview
        radius: 16
        width: prow.implicitWidth + 16
        height: 156
        x: Math.max(8, Math.min(win.width - width - 8, win.previewX - width / 2))
        y: dock.y - height - 10

        Row {
            id: prow
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: preview.open ? (win.previewItem?.windows ?? []) : []
                Item {
                    id: pv
                    required property var modelData
                    width: 200
                    height: 140
                    ClippingRectangle {
                        width: 200
                        height: 112
                        radius: 9
                        color: Theme.tile
                        border.width: pvA.containsMouse ? 2 : 0
                        border.color: Theme.accent
                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: pv.modelData.wayland ?? null
                            live: true
                            constraintSize: Qt.size(400, 224)
                        }
                    }
                    Label {
                        y: 118
                        width: parent.width
                        text: pv.modelData.title
                        size: 11.5
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        id: pvA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hypr.focusWindow(pv.modelData.address);
                            preview.open = false;
                        }
                    }
                }
            }
        }
        MouseArea {
            id: prevHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        Timer {
            running: preview.open && !prevHover.containsMouse && !dockHover.containsMouse
            interval: 500
            onTriggered: preview.open = false
        }
    }

    // ── Стопка «Загрузки» ──
    Pop {
        id: stack
        property real anchorX: 0
        property var files: []
        property string path: Quickshell.env("HOME") + "/Downloads"
        property string title: "Загрузки"
        radius: 16
        width: 300
        height: stackCol.implicitHeight + 16
        x: Math.max(8, Math.min(win.width - width - 8, anchorX - width / 2))
        y: dock.y - height - 10

        Column {
            id: stackCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2
            Label {
                text: stack.title
                weight: Font.Bold
                size: 12
                dim: true
                leftPadding: 8
                bottomPadding: 4
            }
            Repeater {
                model: stack.files
                MenuRow {
                    required property string modelData
                    width: stackCol.width
                    text: modelData
                    icon: /\.(png|jpe?g|webp|gif)$/i.test(modelData) ? "image" : /\.(mp4|mkv|webm)$/i.test(modelData) ? "movie" : /\.(mp3|flac|ogg|wav)$/i.test(modelData) ? "music_note" : /\.(zip|tar|gz|7z|rar|zst)$/i.test(modelData) ? "folder_zip" : "draft"
                    onClicked: Quickshell.execDetached(["xdg-open", stack.path + "/" + modelData])
                }
            }
            MenuRow {
                width: stackCol.width
                text: "Открыть в Файлах"
                icon: "folder_open"
                onClicked: Quickshell.execDetached(["thunar", stack.path])
            }
        }
        MouseArea {
            id: stackHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        Timer {
            running: stack.open && !stackHover.containsMouse && !dockHover.containsMouse
            interval: 900
            onTriggered: stack.open = false
        }
    }
    Process {
        id: stackProc
        command: ["sh", "-c", "if [ -d \"$0\" ]; then ls -t \"$0\" 2>/dev/null | head -8; fi", stack.path]
        stdout: StdioCollector {
            onStreamFinished: stack.files = text.trim().split("\n").filter(s => s.length)
        }
    }

    // ── Компоненты ──
    component MenuRow: Rectangle {
        id: mr
        property string text
        property string icon
        signal clicked
        width: parent ? parent.width : 200
        height: visible ? 30 : 0
        radius: 7
        color: mra.containsMouse ? Theme.accent : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 9
            Icon {
                text: mr.icon
                size: 16
                color: mra.containsMouse ? Theme.inkOnAccent : Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: mr.text
                size: 13
                color: mra.containsMouse ? Theme.inkOnAccent : Theme.text
            }
        }
        MouseArea {
            id: mra
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                mr.clicked();
                menu.open = false;
                stack.open = false;
            }
        }
    }

    component Extra: Item {
        id: ex
        property string key
        property string icon
        property string label
        readonly property bool running: false
        readonly property var item: null
        signal activated
        signal secondary
        property int restIndex: 0
        readonly property real cx: x + width / 2
        readonly property real s: win.scaleFor((DockModel.ids.length + restIndex) * win.restW + 13 + win.restW / 2)
        property real dx: 0
        property real dy: 0
        property bool moved: false
        readonly property bool removing: moved && dy < -win.removeAt && key !== "trash"
        width: win.base * s + 8
        height: win.base * win.maxScale + 8
        Behavior on width { enabled: !dockHover.containsMouse; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Image {
            id: exImg
            width: win.base * ex.s
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: ex.moved ? ex.dx : 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6 + (ex.moved ? Math.max(0, -ex.dy) : 0)
            source: Quickshell.iconPath(ex.icon, "folder")
            sourceSize: Qt.size(128, 128)
            smooth: true
            mipmap: true
            opacity: ex.removing ? 0.55 : 1
            Behavior on anchors.horizontalCenterOffset { enabled: !ex.moved; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on anchors.bottomMargin { enabled: !ex.moved; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            RemoveBadge {
                on: ex.removing
            }
        }
        MouseArea {
            id: exArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            property real px: 0
            property real py: 0
            onPressed: m => {
                px = m.x;
                py = m.y;
                ex.moved = false;
            }
            onPositionChanged: m => {
                win.track(exArea, m.x, m.y);
                if (!pressed || m.buttons !== Qt.LeftButton || ex.key === "trash")
                    return;
                if (!ex.moved && (Math.abs(m.x - px) > 8 || Math.abs(m.y - py) > 8)) {
                    ex.moved = true;
                    win.dragId = "extra:" + ex.key;
                    stack.open = false;
                }
                if (ex.moved) {
                    ex.dx = m.x - px;
                    ex.dy = m.y - py;
                }
            }
            onReleased: {
                if (!ex.moved)
                    return;
                const remove = ex.removing;
                const key = ex.key;
                const g = exImg.mapToItem(null, exImg.width / 2, exImg.height / 2);
                ex.moved = false;
                ex.dx = ex.dy = 0;
                win.dragId = "";
                // Значок исчезнет вместе с делегатом — поэтому убираем последним
                if (remove) {
                    win.poof(g.x, g.y);
                    win.removeExtra(key);
                }
            }
            onClicked: m => {
                if (ex.moved)
                    return;
                m.button === Qt.RightButton ? ex.secondary() : ex.activated();
            }
        }
    }

    // Плашка «Удалить» над вытаскиваемым значком
    component RemoveBadge: Rectangle {
        property bool on: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: rmL.implicitWidth + 18
        height: 22
        radius: 11
        color: Qt.rgba(0.1, 0.1, 0.12, 0.85)
        border.width: 1
        border.color: Theme.glassBorder
        opacity: on ? 1 : 0
        scale: on ? 1 : 0.7
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Label {
            id: rmL
            anchors.centerIn: parent
            text: "Удалить"
            size: 11.5
        }
    }
}
