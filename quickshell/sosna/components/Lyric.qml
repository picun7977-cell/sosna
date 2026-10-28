import QtQuick
import qs.services

// Строка, которая при смене «уплывает» вверх, а новая всплывает снизу (для текста песни).
// Караоке: спетая часть строки ярче и заливается слева направо (progress 0…1).
// Длинная строка не обрезается «…», а едет влево вслед за заливкой;
// длинное название трека (без текста) медленно прокручивается туда-обратно.
Item {
    id: root

    property string text
    property bool lyric: false
    property real progress: 1
    property Item front: a
    property Item back: b

    implicitWidth: Math.min(420, Math.max(a.textWidth, b.textWidth))
    implicitHeight: 20
    clip: true

    onTextChanged: {
        const incoming = back, outgoing = front;
        anim.stop();
        incoming.text = root.text;
        inY.target = inO.target = incoming;
        outY.target = outO.target = outgoing;
        front = incoming;
        back = outgoing;
        anim.start();
    }

    ParallelAnimation {
        id: anim
        NumberAnimation { id: inY; property: "y"; from: 14; to: 0; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { id: inO; property: "opacity"; from: 0; to: 1; duration: 360 }
        NumberAnimation { id: outY; property: "y"; to: -14; duration: 360; easing.type: Easing.InCubic }
        NumberAnimation { id: outO; property: "opacity"; to: 0; duration: 260 }
    }

    component Line: Item {
        id: line

        property string text
        readonly property real textWidth: base.implicitWidth
        readonly property bool isFront: root.front === line
        readonly property bool overflow: textWidth > width
        readonly property bool karaoke: root.lyric && isFront
        // Ушедшая строка остаётся залитой целиком
        readonly property real fill: !root.lyric ? textWidth : isFront ? textWidth * root.progress : textWidth

        width: root.width
        height: root.height

        // Сдвиг строки: короткая — по центру; длинная в караоке — держим заливку на ~60% ширины
        property real shift: !overflow ? (width - textWidth) / 2 : karaoke ? -Math.max(0, Math.min(textWidth - width, fill - width * 0.6)) : 0
        Behavior on shift {
            enabled: line.karaoke
            NumberAnimation { duration: 220 }
        }

        // Прокрутка длинного названия трека (отдельно от shift, чтобы не сломать его привязку)
        property real scroll: 0
        SequentialAnimation on scroll {
            running: line.overflow && !root.lyric && line.isFront
            loops: Animation.Infinite
            onRunningChanged: if (!running) line.scroll = 0
            PauseAnimation { duration: 1800 }
            NumberAnimation { to: line.width - line.textWidth; duration: Math.max(1500, (line.textWidth - line.width) * 28); easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1800 }
            NumberAnimation { to: 0; duration: Math.max(1500, (line.textWidth - line.width) * 28); easing.type: Easing.InOutSine }
        }

        // Плавная заливка между опросами позиции (раз в 200 мс)
        property real shownFill: fill
        Behavior on shownFill {
            enabled: line.karaoke
            NumberAnimation { duration: 220 }
        }

        Text {
            id: base
            x: line.shift + line.scroll
            height: line.height
            text: line.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: root.lyric ? Font.DemiBold : Font.Medium
            color: root.lyric ? Theme.alpha(Theme.text, 0.38) : Theme.alpha(Theme.text, 0.8)
            verticalAlignment: Text.AlignVCenter
        }
        // Спетая часть: та же строка, обрезанная по заливке
        Item {
            visible: root.lyric
            x: line.shift + line.scroll
            width: line.shownFill
            height: line.height
            clip: true
            Text {
                height: line.height
                text: line.text
                font: base.font
                color: Theme.text
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Line {
        id: a
        Component.onCompleted: text = root.text
    }
    Line {
        id: b
        opacity: 0
    }
}
