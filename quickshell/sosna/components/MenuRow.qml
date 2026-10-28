import QtQuick
import QtQuick.Layouts
import qs.services

// Строка меню в стиле macOS: подсветка акцентом при наведении
Rectangle {
    id: root

    property string text
    property string icon
    property string hint
    property bool checked: false
    property bool enabled2: true
    signal clicked

    implicitWidth: 220
    height: visible ? 28 : 0
    radius: 6
    color: area.containsMouse && enabled2 ? Theme.accent : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 10
        spacing: 9
        Icon {
            visible: root.icon !== "" || root.checked
            text: root.checked ? "check" : root.icon
            size: 16
            color: area.containsMouse && root.enabled2 ? Theme.inkOnAccent : root.enabled2 ? Theme.text : Theme.text3
            Layout.preferredWidth: 18
        }
        Label {
            Layout.fillWidth: true
            text: root.text
            size: 13
            color: area.containsMouse && root.enabled2 ? Theme.inkOnAccent : root.enabled2 ? Theme.text : Theme.text3
        }
        Label {
            visible: root.hint !== ""
            text: root.hint
            size: 11.5
            color: area.containsMouse ? Theme.alpha(Theme.inkOnAccent, 0.7) : Theme.text3
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled2
        onClicked: root.clicked()
    }
}
