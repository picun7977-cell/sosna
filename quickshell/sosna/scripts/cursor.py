#!/usr/bin/env python3
"""Позиция курсора для «Сосны» и «встряхни мышь».

Опрашивает сокет Hyprland ~30 раз в секунду, печатает «x y» при движении
и «shake», если мышью быстро потрясли из стороны в сторону.
"""
import json
import os
import socket
import sys
import time

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
run = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
path = f"{run}/hypr/{sig}/.socket.sock"


def cursor():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(path)
        s.sendall(b"j/cursorpos")
        data = b""
        while chunk := s.recv(4096):
            data += chunk
    p = json.loads(data)
    return p["x"], p["y"]


last = None
hist = []          # (время, x) за последние 0.7 с
cooldown = 0.0
while True:
    try:
        x, y = cursor()
    except Exception:
        time.sleep(1)
        continue
    now = time.monotonic()
    if (x, y) != last:
        print(x, y, flush=True)
        last = (x, y)
    hist.append((now, x))
    hist = [h for h in hist if now - h[0] < 0.7]
    # Встряска: много смен направления и большой путь за короткое время
    if now > cooldown and len(hist) > 6:
        turns, dist, prev_dx = 0, 0, 0
        for (_, a), (_, b) in zip(hist, hist[1:]):
            dx = b - a
            dist += abs(dx)
            if dx and prev_dx and (dx > 0) != (prev_dx > 0) and abs(dx) > 8:
                turns += 1
            if dx:
                prev_dx = dx
        if turns >= 4 and dist > 1400:
            print("shake", flush=True)
            cooldown = now + 1.5
            hist.clear()
    time.sleep(0.033)
