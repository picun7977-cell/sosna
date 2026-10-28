#!/usr/bin/env python3
"""Цвета терминала под обои для «Сосны».

Принимает JSON matugen (image … -j hex -m dark) первым аргументом, собирает
16 цветов ANSI в тон обоям и пишет escape-последовательности:
  ~/.local/state/sosna/sequences.txt      — выводить при старте шелла (cat в config.fish / .bashrc)
  ~/.local/state/caelestia/sequences.txt  — если папка есть (её уже читает fish у caelestia)
Открытые терминалы перекрашиваются сразу — последовательности пишутся в их /dev/pts.
"""
import colorsys
import json
import os
import sys


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexc(c):
    return "#" + "".join(f"{round(max(0, min(1, v)) * 255):02x}" for v in c)


def hue_of(h):
    return colorsys.rgb_to_hls(*rgb(h))[0] * 360


def tint(hue, src, light, sat, pull=0.18):
    """Классический оттенок ANSI, слегка притянутый к цвету обоев."""
    d = (src - hue + 180) % 360 - 180
    h = (hue + max(-12, min(12, d * pull))) % 360
    return hexc(colorsys.hls_to_rgb(h / 360, light, sat))


def main():
    c = {k: v["dark"]["color"] for k, v in json.loads(sys.argv[1])["colors"].items()}
    src = hue_of(c["primary"])
    # Насыщенность ANSI — от насыщенности обоев: серым обоям не нужен кислотный терминал
    s = colorsys.rgb_to_hls(*rgb(c["primary"]))[2]
    sat = 0.35 + 0.35 * s

    # Красный, зелёный, жёлтый — классические (ошибки, git diff), чуть подкрашены в тон обоев.
    # Синий, пурпурный и циан — цвета темы: ими рисуют логотип fastfetch, подписи, папки в ls.
    base = {1: 5, 2: 120, 3: 45}
    pal = {0: c["surface_container_high"], 7: c["on_surface_variant"],
           8: c["outline"], 15: c["on_surface"],
           4: c["primary"], 12: c["primary_fixed"],
           5: c["tertiary"], 13: c["tertiary_fixed"],
           6: c["secondary"], 14: c["secondary_fixed"]}
    for i, h in base.items():
        pal[i] = tint(h, src, 0.70, sat)
        pal[i + 8] = tint(h, src, 0.80, sat)

    def osc(code, col):
        r, g, b = (col[1:3], col[3:5], col[5:7])
        return f"\033]{code};rgb:{r}/{g}/{b}\033\\"

    seq = osc(10, c["on_surface"]) + osc(11, c["surface"]) + osc(12, c["primary"]) + osc(17, c["surface_variant"])
    seq += "".join(osc(f"4;{i}", pal[i]) for i in range(16))

    home = os.path.expanduser("~")
    targets = [f"{home}/.local/state/sosna/sequences.txt"]
    if os.path.isdir(f"{home}/.local/state/caelestia"):
        targets.append(f"{home}/.local/state/caelestia/sequences.txt")
    for t in targets:
        os.makedirs(os.path.dirname(t), exist_ok=True)
        with open(t, "w") as f:
            f.write(seq)

    # Перекрашиваем уже открытые терминалы
    uid = os.getuid()
    for name in os.listdir("/dev/pts"):
        p = f"/dev/pts/{name}"
        if not name.isdigit() or os.stat(p).st_uid != uid:
            continue
        try:
            fd = os.open(p, os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY)
            os.write(fd, seq.encode())
            os.close(fd)
        except OSError:
            pass


if __name__ == "__main__":
    main()
