pragma Singleton

import QtQuick
import Quickshell

// Ночной свет: gammastep с фиксированной температурой
Singleton {
    id: root

    property bool on: false
    property int temp: 4500

    function apply(): void {
        if (on)
            Quickshell.execDetached(["sh", "-c", "pkill -x gammastep; sleep 0.2; gammastep -P -O " + temp + " >/dev/null 2>&1 &"]);
        else
            Quickshell.execDetached(["sh", "-c", "pkill -x gammastep; gammastep -x >/dev/null 2>&1"]);
    }

    function setTemp(t: int): void {
        temp = t;
        on = true;
        debounce.restart();
    }

    function toggle(): void {
        on = !on;
        apply();
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: root.apply()
    }
}
