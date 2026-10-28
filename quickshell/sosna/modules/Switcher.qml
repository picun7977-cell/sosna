import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// Alt+Tab как ⌘Tab: значки окон по свежести фокуса, Tab — дальше, Shift+Alt+Tab — назад,
// отпустил Alt — переход (отпускание ловит hl.on("input.keyboard.key") в sosna.lua)
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
    WlrLayershell.namespace: "sosna-switcher"
    mask: Region {
        item: Ui.switcherOpen ? panel : null
    }

    property bool alive: false
    visible: Ui.switcherOpen || alive
    property int index: 0
    property var list: []

    function build(): void {
        list = Hypr.toplevels.filter(t => t.lastIpcObject?.mapped !== false && Hypr.classOf(t) !== "" && (t.workspace?.id ?? 1) > 0)
            .slice()
            .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 99) - (b.lastIpcObject?.focusHistoryID ?? 99));
    }

    function commit(): void {
        if (!Ui.switcherOpen)
            return;
        const t = list[index];
        Ui.switcherOpen = false;
        if (t)
            Hypr.focusWindow(t.address);
    }

    Connections {
        target: Ui
        function onSwitcherOpenChanged(): void {
            if (Ui.switcherOpen) {
                closeTimer.stop();
                win.build();
                Hyprland.refreshToplevels();
                win.index = win.list.length > 1 ? 1 : 0;
                win.alive = true;
                // Одиночное короткое Alt+Tab: окно ещё не успело показаться — просто прыгаем к прошлому
                showDelay.restart();
            } else {
                closeTimer.restart();
            }
        }
        function onSwitcherNext(): void {
            if (win.list.length)
                win.index = (win.index + 1) % win.list.length;
        }
        function onSwitcherPrev(): void {
            if (win.list.length)
                win.index = (win.index - 1 + win.list.length) % win.list.length;
        }
        function onSwitcherDone(): void {
            win.commit();
        }
    }
    Timer {
        id: closeTimer
        interval: 200
        onTriggered: win.alive = false
    }
    Timer {
        id: showDelay
        interval: 90
    }

    Glass {
        id: panel

        strong: true
        radius: 26
        anchors.centerIn: parent
        width: Math.min(win.width - 80, row.implicitWidth + 32)
        height: 152
        opacity: Ui.switcherOpen && !showDelay.running ? 1 : 0
        scale: Ui.switcherOpen ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 6

            Repeater {
                model: win.list
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.index
                    width: 100
                    height: 100

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Theme.alpha(Theme.text, cell.sel ? 0.16 : 0)
                        border.width: cell.sel ? 1 : 0
                        border.color: Theme.alpha(Theme.text, 0.22)
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 72
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Hypr.classOf(cell.modelData))?.icon ?? Hypr.classOf(cell.modelData), "application-x-executable")
                        scale: cell.sel ? 1.08 : cellMouse.containsMouse ? 1.04 : 0.94
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    }
                    // Номер стола
                    Rectangle {
                        visible: (cell.modelData.workspace?.id ?? 0) !== Hypr.wsId
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(0.0, 0.0, 0.0, 0.6)
                        Label {
                            anchors.centerIn: parent
                            text: (cell.modelData.workspace?.id ?? 0) < 0 ? "✦" : (cell.modelData.workspace?.id ?? "")
                            size: 10
                            mono: true
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.index = cell.index
                        onClicked: {
                            win.index = cell.index;
                            win.commit();
                        }
                    }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: Math.min(implicitWidth, panel.width - 40)
            horizontalAlignment: Text.AlignHCenter
            text: {
                const t = win.list[win.index];
                return t ? (t.title || Hypr.prettify(Hypr.classOf(t))) : "Нет окон";
            }
            size: 13
            weight: Font.DemiBold
        }
    }
}
