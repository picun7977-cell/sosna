import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// Mission Control (Super+Tab, горячий угол): окна выезжают со своих мест в сетку с живыми превью,
// сверху — рабочие столы. Клик по окну — перейти, перетащить на стол — переместить, × или средняя кнопка — закрыть.
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
    WlrLayershell.namespace: "sosna-mission"
    WlrLayershell.keyboardFocus: Ui.missionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool alive: false
    visible: Ui.missionOpen || alive
    property real t: 0          // 0 — окна на своих местах, 1 — в сетке
    Behavior on t { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    property int ws: Hypr.wsId
    property int startWs: 1
    // Пока открыт — следим за столом (переключили колесом/клавишами)
    Connections {
        target: Hypr
        function onWsIdChanged(): void {
            if (Ui.missionOpen && Hypr.wsId > 0)
                win.ws = Hypr.wsId;
        }
    }
    property var dragging: null

    readonly property var wins: Hypr.toplevels.filter(tl => tl.workspace?.id === ws && tl.lastIpcObject?.at)
    readonly property var workspaces: {
        const used = Hypr.toplevels.map(tl => tl.workspace?.id ?? 0).filter(id => id > 0);
        const max = Math.max(Hypr.wsId, ...used, 1);
        const res = [];
        for (let i = 1; i <= Math.min(10, max + 1); i++)
            res.push(i);
        return res;
    }

    Connections {
        target: Ui
        function onMissionOpenChanged(): void {
            if (Ui.missionOpen) {
                Hyprland.refreshToplevels();
                closeTimer.stop();
                win.ws = Hypr.wsId;
                win.startWs = Hypr.wsId;
                win.alive = true;
                win.t = 0;
                openTimer.restart();
            } else {
                win.t = 0;
                closeTimer.restart();
                // Закрыли без выбора окна — остаёмся на выбранном столе
                if (!focusLater.running && !closeLater.running && win.ws !== win.startWs)
                    wsLater.restart();
            }
        }
    }
    // Ждём свежие координаты окон от Hyprland, потом разлетаемся в сетку
    Timer {
        id: openTimer
        interval: 70
        onTriggered: win.t = 1
    }
    Timer {
        id: closeTimer
        interval: 430
        onTriggered: win.alive = false
    }

    // Окно с другого стола: сначала переключаем стол под плотным фоном (анимация сдвига Hyprland
    // не видна), потом закрываемся, а в конце ещё раз фокусируем окно — при закрытии Hyprland
    // возвращает фокус на прошлое окно и перекинул бы обратно.
    function pick(tl): void {
        focusLater.addr = tl.address;
        const other = (tl.workspace?.id ?? win.ws) !== Hypr.wsId;
        if (other) {
            Hypr.focusWindow(tl.address);
            closeLater.restart();
        } else {
            focusLater.restart();
            Ui.missionOpen = false;
        }
    }

    Timer {
        id: closeLater
        interval: 320
        onTriggered: {
            focusLater.restart();
            Ui.missionOpen = false;
        }
    }

    Timer {
        id: focusLater
        property string addr
        interval: 90
        onTriggered: Hypr.focusWindow(addr)
    }

    Timer {
        id: wsLater
        interval: 90
        onTriggered: if (Hypr.wsId !== win.ws) Hypr.focusWorkspace(win.ws)
    }


    // Плотный фон из размытых обоев: под ним не видно, как Hyprland листает столы
    Item {
        anchors.fill: parent
        opacity: win.t
        Image {
            id: bgWall
            anchors.fill: parent
            source: Wall.path ? "file://" + Wall.path : ""
            sourceSize: Qt.size(win.width / 2, win.height / 2)
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }
        MultiEffect {
            anchors.fill: parent
            source: bgWall
            blurEnabled: true
            blur: 1
            blurMax: 40
            brightness: -0.18
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.03, 0.03, 0.05, 0.35)
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ui.missionOpen = false
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.missionOpen = false
        Keys.onPressed: e => {
            const n = e.key - Qt.Key_0;
            if (n >= 1 && n <= 9) {
                win.ws = n;
                Hypr.focusWorkspace(n);
            }
        }
    }

    // ───── Рабочие столы ─────
    Row {
        id: spaces
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18 - 30 * (1 - win.t)
        opacity: win.t
        spacing: 14

        Repeater {
            model: win.workspaces
            delegate: Item {
                id: space
                required property int modelData
                readonly property bool cur: modelData === win.ws
                readonly property var apps: Hypr.toplevels.filter(tl => tl.workspace?.id === modelData)
                readonly property bool dropHover: win.dragging !== null && dropArea.containsDrag
                width: 168
                height: 116
                scale: spaceMouse.containsMouse || dropHover ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }

                Rectangle {
                    id: card
                    width: parent.width
                    height: 94
                    radius: 10
                    clip: true
                    color: "#16171b"
                    border.width: space.cur || space.dropHover ? 2 : 1
                    border.color: space.cur || space.dropHover ? Theme.accent : Theme.glassBorder

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: Wall.path ? "file://" + Wall.path : ""
                        sourceSize: Qt.size(336, 188)
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.85
                    }
                    // Значки программ на столе
                    Row {
                        anchors.centerIn: parent
                        spacing: -6
                        Repeater {
                            model: space.apps.slice(0, 5)
                            delegate: IconImage {
                                required property var modelData
                                implicitSize: 30
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Hypr.classOf(modelData))?.icon ?? Hypr.classOf(modelData), "application-x-executable")
                            }
                        }
                    }
                    Icon {
                        visible: space.apps.length === 0
                        anchors.centerIn: parent
                        text: "add"
                        size: 26
                        color: Theme.text2
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: space.apps.length === 0 && space.modelData > Hypr.wsId ? "Новый стол" : "Стол " + space.modelData
                    size: 12
                    weight: space.cur ? Font.DemiBold : Font.Medium
                    color: space.cur ? Theme.text : Theme.text2
                }

                MouseArea {
                    id: spaceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        win.ws = space.modelData;
                        Hypr.focusWorkspace(space.modelData);
                    }
                }
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: d => {
                        if (win.dragging)
                            Hypr.moveWindow(win.dragging.address, space.modelData);
                    }
                }
            }
        }
    }

    // «Призрак» перетаскиваемого окна: значок программы под курсором
    Rectangle {
        id: ghost
        z: 100
        width: 84
        height: 84
        radius: 20
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.accent
        visible: win.dragging !== null
        Drag.active: win.dragging !== null
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        IconImage {
            anchors.centerIn: parent
            implicitSize: 56
            source: win.dragging ? Quickshell.iconPath(DesktopEntries.heuristicLookup(Hypr.classOf(win.dragging))?.icon ?? Hypr.classOf(win.dragging), "application-x-executable") : ""
        }
    }

    // ───── Окна ─────
    Item {
        id: stage
        x: 60
        y: 170
        width: parent.width - 120
        height: parent.height - y - 110

        readonly property int n: win.wins.length
        readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * width / height / 1.6)))
        readonly property int rows: Math.max(1, Math.ceil(n / cols))
        readonly property real cellW: width / cols
        readonly property real cellH: height / rows

        Label {
            anchors.centerIn: parent
            visible: stage.n === 0
            opacity: win.t
            text: "На этом столе нет окон"
            size: 18
            dim: true
        }

        Repeater {
            model: win.wins
            delegate: Item {
                id: w
                required property var modelData
                required property int index

                readonly property var o: modelData.lastIpcObject
                readonly property real rw: Math.max(1, o.size[0])
                readonly property real rh: Math.max(1, o.size[1])
                // Целевая ячейка
                readonly property int col: index % stage.cols
                readonly property int row: Math.floor(index / stage.cols)
                readonly property int inRow: row === stage.rows - 1 ? stage.n - row * stage.cols : stage.cols
                readonly property real fit: Math.min((stage.cellW - 40) / rw, (stage.cellH - 50) / rh, 0.8)
                readonly property real gw: rw * fit
                readonly property real gh: rh * fit
                readonly property real gx: (stage.width - inRow * stage.cellW) / 2 + col * stage.cellW + (stage.cellW - gw) / 2
                readonly property real gy: row * stage.cellH + (stage.cellH - gh) / 2 - 10
                // Исходное место окна (в координатах stage)
                readonly property real sx: o.at[0] - stage.x
                readonly property real sy: o.at[1] - stage.y

                readonly property bool hov: hover.hovered
                readonly property bool held: win.dragging === modelData

                x: sx + (gx - sx) * win.t
                y: sy + (gy - sy) * win.t
                width: rw + (gw - rw) * win.t
                height: rh + (gh - rh) * win.t
                z: hov ? 2 : 1
                opacity: held ? 0.35 : 1
                scale: hov && !held ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "#1b1c20"
                    border.width: w.hov ? 2 : 0
                    border.color: Theme.accent

                    // Значок под превью — виден, пока кадр окна не пришёл (окна с других столов)
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: Math.min(parent.width, parent.height) * 0.35
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Hypr.classOf(w.modelData))?.icon ?? Hypr.classOf(w.modelData), "application-x-executable")
                        visible: !shot.hasContent
                    }
                    ScreencopyView {
                        id: shot
                        anchors.fill: parent
                        captureSource: win.visible ? w.modelData.wayland : null
                        live: true
                    }
                }

                // Значок и название под окном
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 8
                    spacing: 6
                    opacity: win.t
                    IconImage {
                        implicitSize: 20
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Hypr.classOf(w.modelData))?.icon ?? Hypr.classOf(w.modelData), "application-x-executable")
                    }
                    Rectangle {
                        width: Math.min(titleText.implicitWidth, w.width - 20) + 14
                        height: 22
                        radius: 11
                        color: w.hov ? Theme.alpha(Theme.accent, 0.9) : Qt.rgba(0, 0, 0, 0.5)
                        Label {
                            id: titleText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, w.width - 20)
                            text: w.modelData.title || Hypr.prettify(Hypr.classOf(w.modelData))
                            size: 11.5
                            color: w.hov ? Theme.inkOnAccent : Theme.text
                        }
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    drag.target: ghost
                    drag.threshold: 14
                    onPressed: m => {
                        const p = mapToItem(win.contentItem, m.x, m.y);
                        ghost.x = p.x - ghost.width / 2;
                        ghost.y = p.y - ghost.height / 2;
                    }
                    onPositionChanged: if (drag.active && !win.dragging) win.dragging = w.modelData
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton)
                            Hypr.closeWindow(w.modelData.address);
                        else if (!win.dragging)
                            win.pick(w.modelData);
                    }
                    onReleased: {
                        if (win.dragging) {
                            ghost.Drag.drop();
                            win.dragging = null;
                        }
                    }
                }

                // Закрыть
                HoverButton {
                    visible: w.hov && win.t > 0.9 && !win.dragging
                    x: 8
                    y: 8
                    width: 24
                    height: 24
                    radius: 12
                    color: hovered ? Theme.red : Qt.rgba(0.12, 0.12, 0.14, 0.95)
                    border.width: 1
                    border.color: Theme.glassBorder
                    onClicked: Hypr.closeWindow(w.modelData.address)
                    Icon {
                        anchors.centerIn: parent
                        text: "close"
                        size: 14
                    }
                }
            }
        }
    }
}
