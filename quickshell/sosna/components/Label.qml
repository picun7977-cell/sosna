import QtQuick
import qs.services

Text {
    property real size: 13.5
    property int weight: Font.Medium
    property bool mono: false
    property bool dim: false

    font.family: mono ? Theme.mono : Theme.font
    font.pixelSize: Math.round(size)
    font.weight: weight
    font.features: mono ? ({}) : ({ "tnum": 1, "cv11": 1 })
    color: dim ? Theme.text2 : Theme.text
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
