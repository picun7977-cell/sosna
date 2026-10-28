pragma Singleton

import QtQuick
import Quickshell

// Блокировка и питание
Singleton {
    id: root

    property bool locked: false

    function lock(): void {
        Ui.closeAll();
        locked = true;
    }
    function suspend(): void {
        lock();
        Quickshell.execDetached(["sh", "-c", "sleep 1; systemctl suspend"]);
    }
    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
    function logout(): void {
        Hypr.dispatch("hl.dsp.exit()");
    }
}
