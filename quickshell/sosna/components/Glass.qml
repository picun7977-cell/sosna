import QtQuick
import qs.services

// Матовое стекло: полупрозрачная заливка (размывает Hyprland) и тонкая светлая рамка
Rectangle {
    property bool strong: false

    color: strong ? Theme.glassStrong : Theme.glass
    radius: Theme.radius
    border.width: 1
    border.color: Theme.glassBorder
}
