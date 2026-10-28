pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Сервер уведомлений. Новые показываются в острове, все копятся в Центре уведомлений.
Singleton {
    id: root

    property bool dnd: false
    property var times: ({})
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length

    function clear(): void {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times[n.id] = Date.now();

            // Claude Code (мод task-notify) — свой вид в острове, в историю не кладём
            if (n.appName === "Claude Code") {
                const ctx = parseInt(n.hints["x-sosna-ctx"] ?? "-1");
                // Открыт чат с Claude — ответ и так виден в нём, остров не сворачиваем
                if (!Claude.hold)
                    Island.show("claude", { title: n.summary, body: n.body, ctx: ctx, error: n.urgency === NotificationUrgency.Critical }, 5000);
                n.dismiss();
                return;
            }
            if (root.dnd && n.urgency !== NotificationUrgency.Critical)
                return;
            Island.show("notif", { app: n.appName, summary: n.summary, body: n.body, icon: n.appIcon, image: n.image, n: n }, 4500);
            Sounds.play("notify");
        }
    }

    IpcHandler {
        target: "notifs"
        function clear(): void {
            root.clear();
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
    }
}
