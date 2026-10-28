pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Настройки «Сосны»: ~/.config/sosna/settings.json. Меняются из приложения «Настройки»,
// файл можно править и руками — изменения подхватываются на лету.
Singleton {
    id: root

    readonly property alias o: adapter

    // Имя и аватар: из настроек, иначе имя пользователя системы и ~/.face
    readonly property string userName: {
        const n = adapter.userName || Quickshell.env("USER") || "Пользователь";
        return n.charAt(0).toUpperCase() + n.slice(1);
    }
    readonly property string avatar: "file://" + (adapter.avatar || Quickshell.env("HOME") + "/.face")

    function set(key: string, value: var): void {
        adapter[key] = value;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/sosna/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            // Пользователь
            property string userName: ""          // пусто — $USER
            property string avatar: ""            // пусто — ~/.face

            // Внешний вид
            property string accent: ""            // пусто — цвет из обоев
            property bool cornersRound: true
            property int cornerRadius: 14
            property bool startupAnim: true

            // Док
            property int dockIcon: 52
            property bool dockMagnify: true
            property real dockMaxScale: 1.75
            property bool dockAutohide: true
            property bool dockDownloads: true
            property bool dockTrash: true
            property var dockFolders: []          // свои папки в правой части дока

            // Остров
            property bool islandHideFullscreen: true
            property bool islandIdle: true        // погода и сосенка в покое
            property bool islandLyrics: true
            property bool islandPet: true
            property string countdownTitle: "Новый год"
            property string countdownDate: "2027-01-01"

            // Строка меню
            property bool barSeconds: false
            property bool barDate: true
            property bool barWeather: true

            // Рабочий стол
            property bool widgets: true
            property bool wClock: true
            property bool wCalendar: true
            property bool wWeather: true
            property bool wMusic: true
            property bool wSystem: true
            property bool wNote: true
            property bool wScreenTime: true
            property string note: "Купить молоко 🥛\nДоделать Сосну 🌲"
            property bool weatherFx: true
            property var widgetPos: ({})          // ключ виджета → [x, y]

            // Поведение
            property bool sounds: true
            property bool startupSound: true
            property bool hotCorner: true
            property string hotCornerAction: "mission"
            property bool shake: true
            property int lockAfter: 600           // секунд простоя до блокировки, 0 — никогда
            property bool screenTime: true

            // Погода
            property string city: "Москва"
            property real lat: 55.7558
            property real lon: 37.6173
        }
    }
}
