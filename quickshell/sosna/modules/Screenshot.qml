import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Скриншоты: заморозка экрана + выделение области или окна (Super+Shift+S),
// затем миниатюра в правом нижнем углу, как на маке: клик — правка в satty.
Scope {
    // ───────────── Выбор области ─────────────
    LazyLoader {
        active: Shot.picking

        PanelWindow {
            id: picker

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
            WlrLayershell.namespace: "sosna-shot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Окна текущего рабочего стола: [{ x, y, w, h }] — для подсветки и выбора кликом.
            // Порядок — как на экране сверху вниз: закреплённые, плавающие, потом по последнему фокусу
            readonly property var windows: Hypr.wsWindows.map(t => t.lastIpcObject ?? {}).filter(o => o.at && o.size).sort((a, b) => (b.pinned - a.pinned) || (b.floating - a.floating) || ((a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99))).map(o => ({ x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1] }))

            property real sx: 0
            property real sy: 0
            property real ex: 0
            property real ey: 0
            property bool dragging: false
            property bool moved: false
            property var hoverWin: null

            readonly property rect sel: dragging && moved
                ? Qt.rect(Math.min(sx, ex), Math.min(sy, ey), Math.abs(ex - sx), Math.abs(ey - sy))
                : hoverWin ? Qt.rect(hoverWin.x, hoverWin.y, hoverWin.w, hoverWin.h) : Qt.rect(0, 0, 0, 0)
            readonly property bool hasSel: sel.width > 3 && sel.height > 3

            function winAt(x: real, y: real): var {
                return windows.find(r => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) ?? null;
            }

            function capture(r: rect): void {
                if (r.width < 4 || r.height < 4)
                    return;
                crop.sourceRect = Qt.rect(Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height));
                crop.width = Math.round(r.width);
                crop.height = Math.round(r.height);
                const path = Shot.newPath();
                crop.grabToImage(res => {
                    res.saveToFile(path);
                    Shot.picking = false;
                    Shot.finish(path);
                }, Qt.size(crop.width, crop.height));
            }

            Connections {
                target: Shot
                function onCaptureRect(r: rect): void {
                    picker.capture(r);
                }
            }

            // Пока кнопка зажата, Hyprland может не присылать движения мыши слою —
            // тогда рамку тянем по позиции курсора из сокета Hyprland (сервис Cursor)
            Connections {
                target: Cursor
                enabled: picker.dragging
                function onXChanged(): void {
                    picker.dragTo(Cursor.x - picker.screen.x, Cursor.y - picker.screen.y);
                }
                function onYChanged(): void {
                    picker.dragTo(Cursor.x - picker.screen.x, Cursor.y - picker.screen.y);
                }
            }

            function dragTo(x: real, y: real): void {
                ex = x;
                ey = y;
                if (Math.abs(x - sx) > 4 || Math.abs(y - sy) > 4)
                    moved = true;
            }

            ScreencopyView {
                id: frozen
                anchors.fill: parent
                captureSource: picker.screen
                live: false
            }

            // Вырезка из замороженного кадра — её и сохраняем
            ShaderEffectSource {
                id: crop
                sourceItem: frozen
                hideSource: false
                live: false
                x: sourceRect.x
                y: sourceRect.y
            }

            // Затемнение вокруг выделения (четыре полосы)
            Item {
                anchors.fill: parent
                opacity: frozen.hasContent ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                readonly property color shade: Qt.rgba(0, 0, 0, 0.42)
                readonly property rect r: picker.hasSel ? picker.sel : Qt.rect(0, 0, 0, 0)

                Rectangle { color: parent.shade; x: 0; y: 0; width: parent.width; height: parent.r.y }
                Rectangle { color: parent.shade; x: 0; y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y }
                Rectangle { color: parent.shade; x: 0; y: parent.r.y; width: parent.r.x; height: parent.r.height }
                Rectangle { color: parent.shade; x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height }

                // Рамка выделения
                Rectangle {
                    visible: picker.hasSel
                    x: parent.r.x - 1
                    y: parent.r.y - 1
                    width: parent.r.width + 2
                    height: parent.r.height + 2
                    color: "transparent"
                    radius: picker.dragging ? 2 : 12
                    border.width: 2
                    border.color: Theme.accent
                    Behavior on x { enabled: !picker.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !picker.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: !picker.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: !picker.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                // Размер
                Rectangle {
                    visible: picker.hasSel
                    x: Math.min(parent.width - width - 8, parent.r.x)
                    y: parent.r.y + parent.r.height + 8 + height > parent.height ? parent.r.y - height - 8 : parent.r.y + parent.r.height + 8
                    width: sizeLabel.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.7)
                    Label {
                        id: sizeLabel
                        anchors.centerIn: parent
                        text: Math.round(picker.sel.width) + " × " + Math.round(picker.sel.height)
                        size: 12
                        mono: true
                    }
                }
            }

            // Подсказка сверху
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 48
                width: hint.implicitWidth + 28
                height: 32
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.62)
                opacity: picker.dragging ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Label {
                    id: hint
                    anchors.centerIn: parent
                    text: "Выдели область или кликни по окну  ·  Enter — весь экран  ·  Esc — отмена"
                    size: 12.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                focus: true

                onPressed: m => {
                    if (m.button === Qt.RightButton) {
                        Shot.picking = false;
                        return;
                    }
                    picker.sx = picker.ex = m.x;
                    picker.sy = picker.ey = m.y;
                    picker.dragging = true;
                    picker.moved = false;
                }
                onPositionChanged: m => {
                    if (picker.dragging)
                        picker.dragTo(m.x, m.y);
                    else
                        picker.hoverWin = picker.winAt(m.x, m.y);
                }
                onReleased: m => {
                    if (!picker.dragging)
                        return;
                    // Конец выделения — точка отпускания (даже если движений по дороге не пришло)
                    picker.dragTo(m.x, m.y);
                    // Копия, а не ссылка: в Qt 6 picker.sel — «живая» ссылка, и после dragging = false
                    // она превратилась бы в окно под курсором
                    const s = picker.sel;
                    const r = Qt.rect(s.x, s.y, s.width, s.height);
                    picker.dragging = false;
                    if (picker.moved)
                        picker.capture(r);
                    else {
                        const w = picker.winAt(m.x, m.y);
                        picker.capture(w ? Qt.rect(w.x, w.y, w.w, w.h) : Qt.rect(0, 0, picker.width, picker.height));
                    }
                }

                Keys.onEscapePressed: Shot.picking = false
                Keys.onReturnPressed: picker.capture(Qt.rect(0, 0, picker.width, picker.height))
            }
        }
    }

    // ───────────── Миниатюра в углу ─────────────
    PanelWindow {
        id: thumbWin

        screen: Quickshell.screens[0]
        color: "transparent"
        anchors {
            bottom: true
            right: true
        }
        margins {
            right: 18
            bottom: 18
        }
        implicitWidth: 300
        implicitHeight: 220
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sosna-shotthumb"
        visible: shown || card.opacity > 0.01
        mask: Region {
            item: card
        }

        property bool shown: false
        property string path: ""

        Connections {
            target: Shot
            function onTickChanged(): void {
                thumbWin.path = Shot.last;
                thumbWin.shown = true;
                img.source = "";
                img.source = "file://" + Shot.last;
                hideTimer.restart();
            }
        }

        Timer {
            id: hideTimer
            interval: 6000
            onTriggered: if (!cardHover.hovered) thumbWin.shown = false; else restart()
        }

        Rectangle {
            id: card

            readonly property real ratio: img.implicitWidth > 0 ? img.implicitHeight / img.implicitWidth : 0.5625
            width: ratio > 1 ? Math.round(150 / ratio) + 12 : 252
            height: ratio > 1 ? 162 : Math.min(190, Math.round(240 * ratio) + 12)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            radius: 14
            color: Theme.glassStrong
            border.width: 1
            border.color: Theme.glassBorder

            opacity: thumbWin.shown ? 1 : 0
            scale: cardMouse.pressed ? 0.96 : cardHover.hovered ? 1.04 : 1
            transform: Translate {
                x: thumbWin.shown ? 0 : card.width + 40
                Behavior on x { NumberAnimation { duration: thumbWin.shown ? 420 : 260; easing.type: thumbWin.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 } }
            }
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            HoverHandler {
                id: cardHover
            }

            Image {
                id: img
                anchors.fill: parent
                anchors.margins: 6
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize: Qt.size(500, 500)
                layer.enabled: true
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    thumbWin.shown = false;
                    Shot.edit(thumbWin.path);
                }
            }

            // Кнопки при наведении
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 6
                opacity: cardHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Repeater {
                    model: [
                        { g: "edit", t: "Править", run: () => Shot.edit(thumbWin.path) },
                        { g: "folder_open", t: "Папка", run: () => Quickshell.execDetached(["thunar", thumbWin.path.replace(/\/[^\/]*$/, "")]) },
                        { g: "delete", t: "Удалить", run: () => Quickshell.execDetached(["gio", "trash", thumbWin.path]) }
                    ]
                    delegate: HoverButton {
                        required property var modelData
                        width: 30
                        height: 30
                        radius: 15
                        color: hovered ? Theme.accent : Qt.rgba(0, 0, 0, 0.6)
                        hoverScale: 1.15
                        onClicked: {
                            thumbWin.shown = false;
                            modelData.run();
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: parent.modelData.g
                            size: 16
                            color: parent.hovered ? Theme.inkOnAccent : "white"
                        }
                    }
                }
            }

            // Закрыть
            HoverButton {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 4
                width: 22
                height: 22
                radius: 11
                color: Qt.rgba(0.15, 0.15, 0.17, 0.95)
                border.width: 1
                border.color: Theme.glassBorder
                opacity: cardHover.hovered ? 1 : 0
                onClicked: thumbWin.shown = false
                Icon {
                    anchors.centerIn: parent
                    text: "close"
                    size: 13
                }
            }
        }
    }
}
