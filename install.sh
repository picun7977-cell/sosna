#!/usr/bin/env bash
# Установка оболочки «Сосна» на Arch Linux (и производные: CachyOS, EndeavourOS, …).
#   ./install.sh            — пакеты + файлы
#   ./install.sh --no-deps  — только файлы (пакеты уже стоят)
#   ./install.sh --link     — вместо копии ссылка на папку репозитория (для разработки)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
MANIFEST="$STATE/sosna/installed.txt"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz"

DEPS=1
LINK=0
for a in "$@"; do
    case "$a" in
        --no-deps) DEPS=0 ;;
        --link) LINK=1 ;;
        -h|--help) sed -n 2,6p "$0"; exit 0 ;;
        *) echo "Неизвестный параметр: $a"; exit 1 ;;
    esac
done

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Запускай от обычного пользователя, не от root (sudo спросится сам)."
command -v pacman >/dev/null || die "Нужен Arch Linux или производный дистрибутив с pacman."

mkdir -p "$STATE/sosna"
touch "$MANIFEST"
remember() { grep -qxF "$1" "$MANIFEST" || echo "$1" >> "$MANIFEST"; }

# Старую версию файла не затираем, а откладываем рядом: имя.bak-дата
backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        mv "$1" "$1.bak-$STAMP"
        warn "Старый $1 сохранён как $1.bak-$STAMP"
    fi
}

# ───────────── 1. Пакеты ─────────────
PKGS=(
    # Основа
    hyprland quickshell xdg-desktop-portal-hyprland polkit-gnome
    pipewire pipewire-pulse wireplumber networkmanager
    # Цвета из обоев, музыка, буфер, скриншоты, запись экрана
    matugen cava playerctl cliphist wl-clipboard grim slurp hyprpicker satty gpu-screen-recorder
    # Яркость монитора по DDC/CI, поиск файлов, калькулятор, диалоги
    ddcutil fd libqalculate zenity libnotify gvfs trash-cli
    # Программы по умолчанию: терминал, файлы, настройки сети
    foot thunar nm-connection-editor
    # Шрифты и значки
    inter-font ttf-jetbrains-mono-nerd ttf-material-symbols-variable papirus-icon-theme
    # Скрипты оболочки
    python curl
)

if [ "$DEPS" -eq 1 ]; then
    say "Ставлю пакеты (pacman попросит пароль)…"
    sudo pacman -S --needed "${PKGS[@]}"

    # Живые обои — по желанию: mpvpaper есть в репозитории CachyOS или в AUR
    if ! command -v mpvpaper >/dev/null; then
        if pacman -Si mpvpaper >/dev/null 2>&1; then
            sudo pacman -S --needed mpvpaper || true
        elif command -v paru >/dev/null; then
            paru -S --needed mpvpaper || true
        elif command -v yay >/dev/null; then
            yay -S --needed mpvpaper || true
        else
            warn "mpvpaper не поставлен (нужен только для живых обоев) — он есть в AUR."
        fi
    fi

    # Чтобы работала яркость монитора: модуль i2c-dev и группа i2c
    if ! lsmod | grep -q '^i2c_dev'; then
        echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
        sudo modprobe i2c-dev || true
    fi
    if getent group i2c >/dev/null && ! id -nG | grep -qw i2c; then
        sudo usermod -aG i2c "$USER" && warn "Ты добавлен в группу i2c — яркость заработает после перезахода."
    fi
fi

command -v Hyprland >/dev/null || die "Hyprland не найден."
HV="$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+' | head -1 | cut -d' ' -f2)"
if [ -n "$HV" ] && [ "$(printf '%s\n0.56\n' "$HV" | sort -V | head -1)" != "0.56" ]; then
    die "Нужен Hyprland 0.56 или новее (с Lua-конфигом), а стоит $HV."
fi

# ───────────── 2. Оболочка ─────────────
say "Ставлю оболочку в $CFG/quickshell/sosna"
mkdir -p "$CFG/quickshell"
backup "$CFG/quickshell/sosna"
if [ "$LINK" -eq 1 ]; then
    ln -s "$REPO/quickshell/sosna" "$CFG/quickshell/sosna"
else
    cp -r "$REPO/quickshell/sosna" "$CFG/quickshell/sosna"
fi
remember "$CFG/quickshell/sosna"

mkdir -p "$HOME/.local/bin"
install -m755 "$REPO/bin/sosna-start" "$HOME/.local/bin/sosna-start"
remember "$HOME/.local/bin/sosna-start"

# ───────────── 3. Hyprland ─────────────
HY="$CFG/hypr"
mkdir -p "$HY"
cmp -s "$REPO/hypr/sosna.lua" "$HY/sosna.lua" 2>/dev/null || backup "$HY/sosna.lua"
cp "$REPO/hypr/sosna.lua" "$HY/sosna.lua"
remember "$HY/sosna.lua"

if [ -f "$HY/hyprland.lua" ]; then
    if ! grep -q 'require("sosna")' "$HY/hyprland.lua"; then
        printf '\n-- Оболочка «Сосна»\nrequire("sosna")\n' >> "$HY/hyprland.lua"
        say "Добавил require(\"sosna\") в конец $HY/hyprland.lua"
    fi
elif [ -f "$HY/hyprland.conf" ]; then
    warn "У тебя старый конфиг $HY/hyprland.conf, а «Сосне» нужен Lua-конфиг (hyprland.lua)."
    read -rp "Поставить готовый hyprland.lua? Старый .conf останется рядом как запасной [y/N] " ans
    if [[ "$ans" =~ ^[yYдД] ]]; then
        cp "$REPO/hypr/hyprland.lua" "$HY/hyprland.lua"
        remember "$HY/hyprland.lua"
    else
        warn "Тогда перенеси свой конфиг в hyprland.lua и допиши в конец: require(\"sosna\")"
    fi
else
    say "Своего конфига Hyprland нет — ставлю готовый $HY/hyprland.lua"
    cp "$REPO/hypr/hyprland.lua" "$HY/hyprland.lua"
    remember "$HY/hyprland.lua"
fi

if [ -f "$HY/hyprland.lua" ] && ! Hyprland --verify-config -c "$HY/hyprland.lua" 2>&1 | grep -q "config ok"; then
    warn "Hyprland нашёл ошибки в конфиге — проверь: Hyprland --verify-config"
fi

# ───────────── 4. Курсор Bibata ─────────────
ICONS="$HOME/.local/share/icons"
if [ ! -d "$ICONS/Bibata-Modern-Classic" ] && [ ! -d /usr/share/icons/Bibata-Modern-Classic ]; then
    say "Скачиваю курсор Bibata Modern Classic…"
    tmp="$(mktemp -d)"
    if curl -fsSL "$CURSOR_URL" -o "$tmp/c.tar.xz"; then
        mkdir -p "$ICONS"
        tar -xf "$tmp/c.tar.xz" -C "$ICONS" Bibata-Modern-Classic
        remember "$ICONS/Bibata-Modern-Classic"
    else
        warn "Не удалось скачать курсор — останется системный."
    fi
    rm -rf "$tmp"
fi
gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 20 2>/dev/null || true

# ───────────── 5. Папки, обои, цвета терминала ─────────────
mkdir -p "$HOME/Wallpapers" "$HOME/Pictures/Screenshots" "$STATE/caelestia/wallpaper" "$HOME/.cache/sosna"
WP="$STATE/caelestia/wallpaper/path.txt"
if [ ! -s "$WP" ]; then
    first="$(find "$HOME/Wallpapers" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -1)"
    if [ -n "$first" ]; then
        echo "$first" > "$WP"
    else
        warn "Положи картинки в ~/Wallpapers и выбери обои в Настройках → Внешний вид."
    fi
fi

# Цвета терминала под обои: Сосна пишет их в ~/.local/state/sosna/sequences.txt,
# шелл выводит этот файл при старте
if [ -d "$CFG/fish" ] || command -v fish >/dev/null; then
    mkdir -p "$CFG/fish/conf.d"
    cat > "$CFG/fish/conf.d/sosna.fish" <<'EOF'
# «Сосна»: цвета терминала под обои
status is-interactive; and cat ~/.local/state/sosna/sequences.txt 2>/dev/null
EOF
    remember "$CFG/fish/conf.d/sosna.fish"
fi
if [ -f "$HOME/.bashrc" ] && ! grep -q "# >>> sosna" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'
# >>> sosna: цвета терминала под обои
[[ $- == *i* ]] && cat ~/.local/state/sosna/sequences.txt 2>/dev/null
# <<< sosna
EOF
fi

# ───────────── 6. Запуск ─────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    say "Hyprland уже запущен — перезагружаю конфиг и запускаю Сосну"
    hyprctl reload >/dev/null || true
    "$HOME/.local/bin/sosna-start"
fi

echo
say "Готово! 🌲"
echo "   Если Hyprland ещё не запущен — войди в него (из TTY: команда Hyprland)."
echo "   Win — Spotlight, Win+, — Настройки Сосны, Win+K — Центр управления."
echo "   Удаление: ./uninstall.sh"
