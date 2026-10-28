import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import Quickshell.Io
import qs.services
import qs.components

// Экран блокировки: размытые обои, большие часы, имя и поле пароля.
// Если оболочка упала при блокировке — Super+Alt+L перезапускает Сосну.
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property bool leaving: false
    property int attempts: 0

    function submit(): void {
        if (busy || password.length === 0)
            return;
        busy = true;
        failed = false;
        pam.start();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/assets/pam.d"
        config: "passwd"
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.leaving = true;
                Sounds.play("unlock");
                unlockTimer.restart();
            } else {
                root.failed = true;
                root.attempts++;
                root.password = "";
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 420
        onTriggered: {
            Session.locked = false;
            root.leaving = false;
            root.password = "";
            root.failed = false;
        }
    }

    WlSessionLock {
        locked: Session.locked

        WlSessionLockSurface {
            id: surface

            color: "#0d0e11"


            Loader {
                anchors.fill: parent
                sourceComponent: lockView
            }
        }
    }

    // Предпросмотр без запирания: qs -c sosna ipc call lock preview
    property bool previewing: false
    LazyLoader {
        active: root.previewing
        PanelWindow {
            screen: Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sosna-lock"
            color: "#0d0e11"
            Loader {
                anchors.fill: parent
                sourceComponent: lockView
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.previewing = false
            }
        }
    }
    Timer {
        running: root.previewing
        interval: 5000
        onTriggered: root.previewing = false
    }

    Component {
        id: lockView
        Item {
            id: content
            anchors.fill: parent
            opacity: root.leaving ? 0 : 1
            scale: root.leaving ? 1.06 : 1
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InCubic } }
            Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.InCubic } }

            // Обои, размытые и чуть затемнённые
            Image {
                id: wall
                anchors.fill: parent
                source: Wall.path ? "file://" + Wall.path : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(content.width, content.height)
                visible: false
                asynchronous: true
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blur: 1
                blurMax: 48
                brightness: -0.12
                saturation: 0.1
                // «Вдох» при появлении
                scale: appear.running ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.25) }
                    GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.05) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                }
            }

            Timer {
                id: appear
                running: Session.locked || root.previewing
                interval: 50
            }

            // ───── Дата и часы ─────
            Text {
                id: date
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.12
                text: {
                    const s = clock.date.toLocaleString(Qt.locale("ru_RU"), "dddd, d MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                font.family: Theme.font
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
            }

            Item {
                id: clockBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: date.bottom
                anchors.topMargin: -6
                width: bigClock.implicitWidth
                height: bigClock.implicitHeight

                Text {
                    id: bigClock
                    text: Qt.formatTime(clock.date, "hh:mm")
                    font.family: Theme.font
                    font.pixelSize: 168
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.92)
                }
            }

            // ───── Музыка, если играет ─────
            Glass {
                visible: Media.hasTrack
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockBox.bottom
                anchors.topMargin: 18
                width: 360
                height: 64
                radius: 18
                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    ClippingRectangle {
                        width: 44
                        height: 44
                        radius: 10
                        color: Theme.tile
                        Image {
                            anchors.fill: parent
                            source: Media.art ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Column {
                        width: 190
                        anchors.verticalCenter: parent.verticalCenter
                        Label { width: parent.width; text: Media.title; weight: Font.DemiBold }
                        Label { width: parent.width; text: Media.artist; dim: true; size: 12 }
                    }
                    HoverButton {
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Media.toggle()
                        Icon { anchors.centerIn: parent; text: Media.playing ? "pause" : "play_arrow"; fill: true; size: 24 }
                    }
                    HoverButton {
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Media.next()
                        Icon { anchors.centerIn: parent; text: "fast_forward"; fill: true; size: 22 }
                    }
                }
            }

            // ───── Пользователь и пароль ─────
            Column {
                id: user
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.1
                spacing: 12

                ClippingRectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84
                    height: 84
                    radius: 42
                    color: Theme.tile
                    border.width: 2
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.25)
                    Image {
                        anchors.fill: parent
                        source: Config.avatar
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(168, 168)
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Config.userName
                    font.family: Theme.font
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: "white"
                }

                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 240
                    height: 38
                    radius: 19
                    color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.2 : 0.14)
                    border.width: 1
                    border.color: root.failed ? Theme.red : Qt.rgba(1, 1, 1, 0.22)
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    // Тряска при неверном пароле
                    transform: Translate { id: shakeT }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 50 }
                        NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: shakeT; property: "x"; to: 5; duration: 70 }
                        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                    }
                    Connections {
                        target: root
                        function onAttemptsChanged(): void {
                            shake.restart();
                        }
                    }

                    // Точки вместо символов
                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Repeater {
                            model: Math.min(root.password.length, 18)
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "white"
                                NumberAnimation on scale { from: 0; to: 1; duration: 180; easing.type: Easing.OutBack }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.password.length === 0
                        text: root.busy ? "Проверяю…" : root.failed ? "Неверный пароль" : "Введите пароль"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: root.failed ? "#ffb4ae" : Qt.rgba(1, 1, 1, 0.6)
                    }
                    // Кнопка «войти»
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.22)
                        opacity: root.password.length > 0 ? 1 : 0
                        scale: root.password.length > 0 ? 1 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        Icon {
                            anchors.centerIn: parent
                            text: root.busy ? "progress_activity" : "arrow_forward"
                            size: 18
                            color: "white"
                            RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submit()
                        }
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        opacity: 0
                        focus: true
                        echoMode: TextInput.Password
                        text: root.password
                        onTextChanged: if (text !== root.password) root.password = text
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.password = ""
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Hypr.caps ? "Включён Caps Lock" : "Раскладка: " + Hypr.layout
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Hypr.caps ? Theme.orange : Qt.rgba(1, 1, 1, 0.45)
                }
            }

            // ───── Питание ─────
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 28
                spacing: 14
                Repeater {
                    model: [
                        { g: "bedtime", t: "Сон", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
                        { g: "restart_alt", t: "Перезагрузка", run: () => Session.reboot() },
                        { g: "power_settings_new", t: "Выключение", run: () => Session.poweroff() }
                    ]
                    delegate: Column {
                        required property var modelData
                        spacing: 6
                        HoverButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 42
                            height: 42
                            radius: 21
                            color: hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                            onClicked: parent.modelData.run()
                            Icon {
                                anchors.centerIn: parent
                                text: parent.parent.modelData.g
                                size: 20
                                color: "white"
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.modelData.t
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                    }
                }
            }

            // Погода слева внизу
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 32
                spacing: 10
                visible: Weather.ready
                Icon {
                    text: Weather.icon
                    size: 30
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: Weather.signed(Weather.temp) + "  " + Weather.desc; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: "white" }
                    Text { text: Weather.city; font.family: Theme.font; font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.6) }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            Session.lock();
        }
        function preview(): void {
            root.previewing = true;
        }
    }
}
