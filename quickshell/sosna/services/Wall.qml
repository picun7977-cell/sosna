pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Обои и акцентный цвет из них.
// Путь хранится там же, где у caelestia, — так продолжает работать ~/.local/bin/live-wallpaper.
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/caelestia/wallpaper/path.txt"
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/sosna/accent.txt"
    readonly property string wallDir: Quickshell.env("HOME") + "/Wallpapers"

    property string path: pathFile.text().trim()
    property color accent: "#90cef4"
    property list<string> all: []

    function set(p: string): void {
        pathFile.setText(p + "\n");
    }

    function refreshList(): void {
        listProc.running = true;
    }

    onPathChanged: if (path) {
        // matugen из PATH, иначе из ~/.local/bin
        accentProc.command = ["sh", "-c", "m=$(command -v matugen || echo \"$HOME/.local/bin/matugen\"); exec \"$m\" \"$@\"", "sh", "image", path, "--dry-run", "-j", "hex", "-m", "dark", "--source-color-index", "0"];
        accentProc.running = true;
    }

    FileView {
        id: pathFile
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
    }

    // Акцент из прошлого запуска — чтобы не мигать голубым при старте
    FileView {
        id: cacheFile
        path: root.cachePath
        onLoaded: {
            const c = text().trim();
            if (/^#[0-9a-fA-F]{6}$/.test(c))
                root.accent = c;
        }
    }

    Process {
        id: accentProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).colors.primary.dark.color;
                    root.accent = c;
                    cacheFile.setText(c + "\n");
                    // Цвета терминала под обои
                    Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/termcolors.py", text]);
                } catch (e) {
                    console.warn("sosna: не удалось получить акцент:", e, JSON.stringify(text.slice(0, 120)), text.length);
                }
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$HOME/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: root.all = text.trim().split("\n").filter(s => s.length > 0)
        }
    }
}
