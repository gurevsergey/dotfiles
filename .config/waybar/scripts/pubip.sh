#!/usr/bin/env python3
# Публичный IP и страна для waybar.
# Запрашивает ipinfo.io только при смене маршрутизации (default-маршрут или
# поднятые туннельные интерфейсы) либо раз в 10 минут — waybar дёргает скрипт часто.
# Аргументы: --refresh сбрасывает кэш, --copy копирует IP в буфер обмена.
import json
import os
import subprocess
import sys
import time
import urllib.request

CACHE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-pubip.json")
MAX_AGE = 600
# туннели без раздельной маршрутизации: всё идёт через туннель
FULL_TUNNEL_DEVS = {"hop0", "next-hop"}


def ip_json(*args):
    out = subprocess.run(["ip", "-j", *args], capture_output=True, text=True).stdout
    return json.loads(out or "[]")


def fingerprint():
    # Маршрут до внешнего адреса учитывает policy routing (в т.ч. туннели NM)
    route = ip_json("route", "get", "1.1.1.1")
    # ifindex меняется при пересоздании туннеля (Happ так делает при смене
    # сервера, оставляя имя happ-xray), поэтому одного имени мало
    links = [
        f'{link["ifname"]}#{link["ifindex"]}'
        for link in ip_json("-d", "link", "show", "up")
        if link.get("linkinfo", {}).get("info_kind") in ("wireguard", "tun")
    ]
    dev = route[0].get("dev", "") if route else ""
    # hop переключает локации внутри sing-box, не пересоздавая туннель, —
    # смену видно только по его состоянию
    try:
        hop = os.stat(os.path.expanduser("~/.config/hop/state.json")).st_mtime_ns
    except OSError:
        hop = 0
    return f"{dev}|{','.join(sorted(links))}|{hop}"


def flag(cc):
    if len(cc) != 2 or not cc.isalpha():
        return "󰇧"
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in cc.upper())


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.load(r)


def fetch_ifconfig():
    d = get_json("https://ifconfig.co/json")
    org = " ".join(x for x in (d.get("asn"), d.get("asn_org")) if x)
    return {"ip": d.get("ip"), "country": d.get("country_iso"), "city": d.get("city"),
            "region": d.get("region_name"), "org": org}


def fetch_ipwho():
    d = get_json("https://ipwho.is/")
    conn = d.get("connection") or {}
    org = " ".join(x for x in (f'AS{conn["asn"]}' if conn.get("asn") else None, conn.get("org")) if x)
    return {"ip": d.get("ip"), "country": d.get("country_code"), "city": d.get("city"),
            "region": d.get("region"), "org": org}


def fetch_tunnel():
    # Выходы туннеля общие на многих клиентов, ipinfo.io их часто режет (429) —
    # тогда спрашиваем ipwho.is (не ifconfig.co: его геобаза ошибается на
    # подсетях туннеля, например берлинский выход называет GB)
    try:
        return get_json("https://ipinfo.io/json")
    except Exception:
        return fetch_ipwho()


def same_exit(a, b):
    # Выход туннеля может отдавать разные адреса из одного пула на каждое
    # соединение, так что сравниваем /24, а не адрес целиком
    ip_a, ip_b = a.get("ip") or "", b.get("ip") or ""
    if ":" in ip_a or ":" in ip_b:
        return ip_a == ip_b
    return ip_a.rsplit(".", 1)[0] == ip_b.rsplit(".", 1)[0]


def fetch():
    # При раздельном туннелировании ifconfig.co идёт напрямую, а ipinfo.io — через
    # туннель, поэтому они видят разные адреса; хватает и одного ответа
    res = {}
    for key, fn in (("direct", fetch_ifconfig), ("tunnel", fetch_tunnel)):
        try:
            res[key] = fn()
        except Exception as e:
            err = e
    if not res:
        raise err
    return res


def describe(info, title):
    cc = info.get("country") or "??"
    place = ", ".join(x for x in (info.get("city"), info.get("region"), cc) if x)
    return f"{title}: {info.get('ip', '?')}\n{place}\n{info.get('org', '')}"


def main():
    if "--refresh" in sys.argv:
        try:
            os.remove(CACHE)
        except FileNotFoundError:
            pass
        return
    if "--copy" in sys.argv:
        try:
            with open(CACHE) as f:
                info = json.load(f)["info"]
            ip = (info.get("direct") or info["tunnel"])["ip"]
        except (OSError, ValueError, KeyError, TypeError):
            return
        subprocess.run(["wl-copy", ip])
        subprocess.run(["notify-send", "-t", "2000", "Публичный IP скопирован", ip])
        return

    fp = fingerprint()
    try:
        with open(CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}

    info = cache.get("info")
    # старый формат кэша — один ответ без разбивки на direct/tunnel
    if info and not ("direct" in info or "tunnel" in info):
        info = None
    if not info or cache.get("fp") != fp or time.time() - cache.get("ts", 0) > MAX_AGE:
        try:
            info = fetch()
            with open(CACHE, "w") as f:
                json.dump({"fp": fp, "ts": time.time(), "info": info}, f)
        except Exception as e:
            print(json.dumps({"text": "󰇧  нет сети", "class": "offline",
                              "tooltip": f"Не удалось узнать публичный IP:\n{e}"}, ensure_ascii=False))
            return

    entries = [(k, info[k]) for k in ("direct", "tunnel") if info.get(k)]
    # один и тот же выход — раздельного туннелирования нет; показываем
    # ответ ipinfo.io, у него геобаза точнее. Через туннель hop (sing-box) идёт весь
    # трафик, а адреса выхода там из разных подсетей, так что сравнивать
    # их бесполезно
    full_tunnel = fp.split("|")[0] in FULL_TUNNEL_DEVS
    if len(entries) == 2 and (full_tunnel or same_exit(entries[0][1], entries[1][1])):
        entries = entries[1:]
    titles = {"direct": "Напрямую (ifconfig.co)", "tunnel": "Через туннель (ipinfo.io)"}
    parts = []
    for _, e in entries:
        cc = e.get("country") or "??"
        parts.append(f"{flag(cc)} {cc}  {e.get('ip', '?')}")
    tooltip = "\n\n".join(describe(e, titles[k]) for k, e in entries)
    tooltip += "\n\nЛКМ — скопировать прямой IP · ПКМ — обновить"
    main_cc = (entries[0][1].get("country") or "??").lower()
    print(json.dumps({"text": "   ".join(parts), "tooltip": tooltip,
                      "class": main_cc, "alt": entries[0][1].get("ip", "?")}, ensure_ascii=False))

main()
