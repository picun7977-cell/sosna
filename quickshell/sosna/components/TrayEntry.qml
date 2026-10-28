import QtQuick
import Quickshell
import qs.services

// Пункт меню значка трея; подменю раскрывается прямо внутри (рекурсия через Loader)
Column {
    id: te

    property var entry
    property bool expanded: false

    Separator {
        visible: te.entry.isSeparator
        width: te.width
    }
    MenuRow {
        visible: !te.entry.isSeparator
        width: te.width
        text: te.entry.text.replace(/_(?=\S)/, "")
        enabled2: te.entry.enabled
        checked: te.entry.buttonType !== QsMenuButtonType.None && te.entry.checkState === Qt.Checked
        icon: te.entry.hasChildren ? (te.expanded ? "expand_less" : "chevron_right") : ""
        onClicked: {
            if (te.entry.hasChildren) {
                te.expanded = !te.expanded;
            } else {
                te.entry.triggered();
                Ui.closePopups();
            }
        }
    }
    Loader {
        active: te.expanded
        width: te.width
        sourceComponent: Column {
            leftPadding: 12
            QsMenuOpener {
                id: sub
                menu: te.entry
            }
            Repeater {
                model: sub.children
                Loader {
                    required property var modelData
                    width: te.width - 12
                    source: Qt.resolvedUrl("TrayEntry.qml")
                    onLoaded: item.entry = modelData
                }
            }
        }
    }
}
