import QtQuick
import qs.services

// Значок из Material Symbols Rounded (тонкий, похож на SF Symbols)
Text {
    property real size: 18
    property int weight: 400
    property bool fill: false

    font.family: Theme.icons
    font.pixelSize: Math.round(size)
    font.variableAxes: ({ "FILL": fill ? 1 : 0, "wght": weight, "opsz": 24, "GRAD": 0 })
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
