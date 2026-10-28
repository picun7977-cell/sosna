#!/usr/bin/env python3
"""Текст песни для острова «Сосны» с lrclib.net.

    lyrics.py <исполнитель> <название> <длительность, с> [прокси]

Печатает одну строку JSON: {"status": "ok" | "plain" | "missing" | "error", "synced": "...", "plain": "..."}.
  ok      — есть синхронный текст (LRC)
  plain   — только обычный текст
  missing — текста нет
  error   — lrclib недоступен (нет сети, блокировка, перегрузка) — стоит повторить позже

Если lrclib не отвечает напрямую, запрос идёт через локальный прокси: заданный аргументом,
из $https_proxy / $all_proxy или найденный на типичных портах (Throne, Happ, v2rayN, Clash).
Найденное кладётся в ~/.cache/sosna/lyrics — потом работает и без сети.
"""
import hashlib
import json
import os
import socket
import subprocess
import sys
import time
import urllib.parse

API = "https://lrclib.net/api"
CACHE = os.path.expanduser("~/.cache/sosna/lyrics")
MISSING_TTL = 7 * 86400  # «текста нет» перепроверяем раз в неделю
# Типичные локальные прокси: Throne / sing-box, Happ / v2rayN, Clash
PORTS = [(2080, "socks5h"), (10808, "socks5h"), (10809, "http"), (7890, "http"), (7891, "socks5h"), (1080, "socks5h")]


class Unreachable(Exception):
    pass


def port_open(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.3):
            return True
    except OSError:
        return False


def proxies(custom):
    out = [None]  # сначала напрямую
    for p in (custom, os.environ.get("https_proxy"), os.environ.get("HTTPS_PROXY"), os.environ.get("all_proxy")):
        if p and p not in out:
            out.append(p)
    for port, scheme in PORTS:
        if port_open(port):
            out.append(f"{scheme}://127.0.0.1:{port}")
    return out


class Client:
    def __init__(self, custom):
        self.routes = proxies(custom)
        self.good = None  # маршрут, который уже сработал

    def get(self, path, **params):
        url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
        routes = [self.good] if self.good is not None else self.routes
        for route in routes:
            cmd = ["curl", "-sS", "--connect-timeout", "4", "--max-time", "8", "-A", "sosna-shell/1.0 (local desktop)", "-w", "\n%{http_code}", url]
            if route:
                cmd[1:1] = ["-x", route]
            try:
                r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            except subprocess.TimeoutExpired:
                continue
            body, _, code = r.stdout.rpartition("\n")
            if os.environ.get("SOSNA_LYRICS_DEBUG"):
                print(f"{route or 'напрямую'} {path} → {code} {r.stderr.strip()[:80]}", file=sys.stderr)
            if r.returncode != 0 or code in ("000", "429") or code.startswith("5"):
                continue  # нет связи или сервер перегружен — пробуем следующий маршрут
            self.good = route
            if code == "404":
                return None
            try:
                return json.loads(body)
            except ValueError:
                continue
        raise Unreachable


def norm(s):
    return "".join(ch for ch in s.lower() if ch.isalnum())


def same_artist(a, b):
    a, b = norm(a), norm(b)
    return len(a) >= 3 and len(b) >= 3 and (a in b or b in a)


def pick(items, artist, duration, key, tolerance):
    """Первая подходящая запись с нужным полем: близкая по длительности или того же исполнителя.
    Иначе легко подхватить чужую песню с тем же названием."""
    for d in items:
        if not d.get(key):
            continue
        close = duration > 0 and abs((d.get("duration") or 0) - duration) < tolerance
        if close or same_artist(artist, d.get("artistName") or ""):
            return d[key]
    return ""


def lookup(artist, title, duration, custom):
    c = Client(custom)
    synced = plain = ""
    # 1. Точное совпадение
    params = {"artist_name": artist, "track_name": title}
    if duration > 0:
        params["duration"] = round(duration)
    d = c.get("get", **params)
    if d:
        synced, plain = d.get("syncedLyrics") or "", d.get("plainLyrics") or ""
    # 2. Поиск «исполнитель название»
    if not synced:
        found = c.get("search", q=f"{artist} {title}".strip()) or []
        synced = pick(found, artist, duration, "syncedLyrics", 8)
        plain = plain or pick(found, artist, duration, "plainLyrics", 8)
    # 3. Только по названию (на YouTube/SoundCloud «исполнитель» часто — канал залившего)
    if not synced:
        found = c.get("search", track_name=title) or []
        synced = pick(found, artist, duration, "syncedLyrics", 4)
        plain = plain or pick(found, artist, duration, "plainLyrics", 6)
    return synced, plain


def main():
    artist, title = sys.argv[1], sys.argv[2]
    duration = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 0
    custom = sys.argv[4] if len(sys.argv) > 4 else ""

    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha1(f"{artist}\x01{title}".lower().encode()).hexdigest() + ".json")
    try:
        with open(path) as f:
            cached = json.load(f)
        if cached["status"] != "missing" or time.time() - cached.get("t", 0) < MISSING_TTL:
            print(json.dumps(cached, ensure_ascii=False))
            return
    except (OSError, ValueError, KeyError):
        pass

    try:
        synced, plain = lookup(artist, title, duration, custom)
    except Unreachable:
        print(json.dumps({"status": "error"}))
        return

    res = {"status": "ok" if synced else "plain" if plain else "missing", "synced": synced, "plain": plain, "t": int(time.time())}
    with open(path, "w") as f:
        json.dump(res, f, ensure_ascii=False)
    print(json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main()
