pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Сеть: тип подключения (nmcli), VPN, а для кабеля — линк, скорость порта и трафик
// (/sys/class/net/<iface>, раз в 2 секунды)
Singleton {
    id: root

    property string type: "ethernet"   // ethernet | wifi | none
    property string name: ""
    property bool vpn: false
    property string vpnName: ""

    // Кабель
    property string iface: ""
    property bool carrier: true
    property int speed: 0              // Мбит/с порта
    property real rx: 0                // байт/с
    property real tx: 0
    property real rxTotal: 0           // байт за сеанс
    property real txTotal: 0
    property real lastRx: -1
    property real lastTx: -1
    property bool ready: false

    function refresh(): void {
        proc.running = true;
    }

    function rate(b: real): string {
        if (b < 1024)
            return Math.round(b) + " Б/с";
        if (b < 1024 * 1024)
            return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " КБ/с";
        return (b / 1048576).toFixed(1) + " МБ/с";
    }

    function size(b: real): string {
        if (b < 1048576)
            return (b / 1024).toFixed(0) + " КБ";
        if (b < 1073741824)
            return (b / 1048576).toFixed(0) + " МБ";
        return (b / 1073741824).toFixed(2) + " ГБ";
    }

    readonly property string speedText: speed >= 1000 ? (speed / 1000) + " Гбит/с" : speed > 0 ? speed + " Мбит/с" : ""

    onCarrierChanged: {
        if (!ready)
            return;
        Island.show("text", carrier ? { title: "Кабель подключён", body: speedText || iface, icon: "lan" } : { title: "Кабель отключён", body: "Нет сети", icon: "lan_off", warn: true }, 2600);
        refresh();
    }

    Process {
        id: proc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device; echo ---; ip -br link | awk '{print $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [nm, links] = text.split("---");
                const rows = nm.trim().split("\n").map(l => l.split(":"));
                const eth = rows.find(r => r[0] === "ethernet" && r[1] === "connected");
                const wifi = rows.find(r => r[0] === "wifi" && r[1] === "connected");
                root.type = eth ? "ethernet" : wifi ? "wifi" : root.iface ? "ethernet" : "none";
                root.name = (eth ?? wifi ?? ["", "", ""])[2] ?? "";
                const tun = links.trim().split("\n").find(l => /^(throne|tun|wg|happ|xray|sing)/.test(l));
                root.vpn = !!tun;
                root.vpnName = !tun ? "" : tun.startsWith("throne") ? "Throne" : tun.startsWith("happ") ? "Happ" : tun.startsWith("wg") ? "WireGuard" : tun;
            }
        }
    }

    // Строки вида «eno1 1 1000 <rx> <tx>»: первый физический проводной интерфейс
    Process {
        running: true
        command: ["sh", "-c", "while :; do for d in /sys/class/net/*; do [ -e \"$d/device\" ] && [ ! -e \"$d/wireless\" ] || continue; n=${d##*/}; echo \"$n $(cat $d/carrier 2>/dev/null || echo 0) $(cat $d/speed 2>/dev/null || echo 0) $(cat $d/statistics/rx_bytes) $(cat $d/statistics/tx_bytes)\"; break; done; sleep 2; done"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(" ");
                if (p.length < 5)
                    return;
                root.iface = p[0];
                const rxb = Number(p[3]), txb = Number(p[4]);
                if (root.lastRx >= 0) {
                    root.rx = Math.max(0, (rxb - root.lastRx) / 2);
                    root.tx = Math.max(0, (txb - root.lastTx) / 2);
                    root.rxTotal += Math.max(0, rxb - root.lastRx);
                    root.txTotal += Math.max(0, txb - root.lastTx);
                }
                root.lastRx = rxb;
                root.lastTx = txb;
                root.speed = Math.max(0, Number(p[2]));
                root.carrier = p[1] === "1";
                root.ready = true;
            }
        }
    }

    Timer {
        running: true
        interval: Ui.controlOpen ? 3000 : 20000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
