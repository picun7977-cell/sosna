#!/usr/bin/env bash
# Удаление «Сосны». Пакеты не трогаем — их могли поставить и для другого.
#   ./uninstall.sh          — убрать оболочку, настройки (~/.config/sosna) оставить
#   ./uninstall.sh --purge  — убрать и настройки, кэш, экранное время
set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
MANIFEST="$STATE/sosna/installed.txt"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

qs -c sosna kill >/dev/null 2>&1 || true

# Всё, что поставил install.sh (по списку), иначе — известные пути
if [ -s "$MANIFEST" ]; then
    mapfile -t FILES < "$MANIFEST"
else
    FILES=("$CFG/quickshell/sosna" "$HOME/.local/bin/sosna-start" "$CFG/hypr/sosna.lua" "$CFG/fish/conf.d/sosna.fish")
fi
for f in "${FILES[@]}"; do
    # Готовый hyprland.lua не удаляем — без него Hyprland не запустится; убираем только строку Сосны
    [ "$f" = "$CFG/hypr/hyprland.lua" ] && continue
    # Курсор оставляем: на него ссылаются настройки GTK и Hyprland
    case "$f" in */icons/*) continue ;; esac
    if [ -e "$f" ] || [ -L "$f" ]; then
        rm -rf "$f" && say "Удалён $f"
    fi
done

if [ -f "$CFG/hypr/hyprland.lua" ]; then
    sed -i '/^-- Оболочка «Сосна»/d; /^require("sosna")$/d' "$CFG/hypr/hyprland.lua"
    say "Убрал require(\"sosna\") из hyprland.lua"
fi
if [ -f "$HOME/.bashrc" ]; then
    sed -i '/^# >>> sosna/,/^# <<< sosna/d' "$HOME/.bashrc"
fi

if [ "$PURGE" -eq 1 ]; then
    rm -rf "$CFG/sosna" "$HOME/.cache/sosna" "$STATE/sosna"
    say "Удалены настройки, кэш и экранное время"
else
    rm -f "$MANIFEST"
    say "Настройки остались в $CFG/sosna (удалить: ./uninstall.sh --purge)"
fi

hyprctl reload >/dev/null 2>&1 || true
say "Сосна удалена. Курсор Bibata и пакеты остались — их можно убрать вручную."
