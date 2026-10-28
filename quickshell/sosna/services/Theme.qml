pragma Singleton

import QtQuick
import Quickshell

// Цвета, шрифты и размеры «Сосны». Акцент берётся из обоев (см. Wall).
Singleton {
    readonly property color accent: /^#[0-9a-fA-F]{6}$/.test(Config.o.accent) ? Config.o.accent : Wall.accent
    readonly property color inkOnAccent: "#10161b"

    readonly property color text: "#f2f2f4"
    readonly property color text2: Qt.rgba(0.92, 0.92, 0.96, 0.64)
    readonly property color text3: Qt.rgba(0.92, 0.92, 0.96, 0.38)

    readonly property color glass: Qt.rgba(0.118, 0.122, 0.141, 0.56)
    readonly property color glassStrong: Qt.rgba(0.11, 0.114, 0.13, 0.78)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.11)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.07)
    readonly property color tile: Qt.rgba(1, 1, 1, 0.07)
    readonly property color tileHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.09)
    readonly property color island: "#0b0b0d"
    readonly property color red: "#ff5a4f"
    readonly property color orange: "#ff9f0a"
    readonly property color green: "#30d158"

    readonly property string font: "Inter Variable"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "Material Symbols Rounded"

    readonly property int barHeight: 34
    readonly property int radius: 22
    readonly property int radiusSmall: 12

    // Длительности анимаций
    readonly property int fast: 160
    readonly property int normal: 280
    readonly property int slow: 460

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
}
