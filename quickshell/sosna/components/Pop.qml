import QtQuick
import qs.services

// Стеклянная всплывашка с «пружинным» появлением из точки привязки
Glass {
    id: root

    property bool open: false
    property int origin: Item.Bottom

    strong: true
    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.9
    transformOrigin: origin
    Behavior on opacity { NumberAnimation { duration: root.open ? 200 : 140; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: root.open ? 340 : 160; easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 } }
}
