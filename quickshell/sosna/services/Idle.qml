pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// «Кофе»: пока включён, экран не блокируется. Выключен — блокировка через 10 минут простоя.
Singleton {
    id: root

    property bool coffee: true

    IdleInhibitor {
        enabled: root.coffee
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "sosna-inhibitor"
        }
    }

    IdleMonitor {
        enabled: !root.coffee && Config.o.lockAfter > 0
        timeout: Math.max(60, Config.o.lockAfter)
        onIsIdleChanged: if (isIdle) Session.lock()
    }
}
