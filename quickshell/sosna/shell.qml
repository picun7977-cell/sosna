//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import qs.services
import qs.modules

// «Сосна» — macOS-подобная оболочка для Hyprland
ShellRoot {
    settings.watchFiles: true

    Background {}
    Desktop {}
    Bar {}
    IslandWindow {}
    Dock {}
    Popups {}
    Spotlight {}
    Screenshot {}
    Mission {}
    Switcher {}
    Lock {}
    Settings {}
    Corners {}

    // Сервисы, которым нужно стартовать сразу
    Component.onCompleted: {
        Idle.coffee;
        Notifs.dnd;
        Weather.ready;
        Config.o;
        Launcher.history;
        Borders.apply;
        ScreenTime.loaded;
        Cursor.x;
        Brightness.ready;
        Wall.refreshList();
    }
}
