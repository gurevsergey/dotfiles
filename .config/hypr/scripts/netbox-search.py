#!/usr/bin/env python3
"""Единый поиск (SUPER+I): NetBox (IP, префиксы, устройства, VLAN, VM) и,
для IP/MAC, ~/skripts/loc.py — где устройство подключено (порт, Wi-Fi, DHCP, ARP).
Строка NetBox открывает объект в NetBox-PWA, строка loc.py — полную таблицу loc.py.

Токен: NetBox → профиль → API Tokens → Add, затем
    echo 'ТОКЕН' > ~/.config/netbox-search/token && chmod 600 ~/.config/netbox-search/token
Найденное открывается в NetBox-PWA.
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

NETBOX = "https://netbox.example.com"
PWA_ID = "01M3VNEX18YTZZNKAQ2XKJ6033"
TOKEN_FILE = os.path.expanduser("~/.config/netbox-search/token")
LIMIT = 15
LOC_SEARCH = os.path.expanduser("~/.config/hypr/scripts/loc-search.sh")
LOC_PY = os.path.expanduser("~/skripts/loc.py")
RU_TO_EN = str.maketrans("фисвуаФИСВУАюЮжЖ", "abcdefABCDEF..::")
LOC_RE = re.compile(r"[0-9]{1,3}(\.[0-9]{1,3}){0,3}\.?|[0-9A-Fa-f]{2}([-:.]?[0-9A-Fa-f]{2}){1,5}")

# (метка, endpoint, функция описания объекта)
KINDS = [
    ("IP", "ipam/ip-addresses", lambda o: [
        o["address"], o.get("dns_name"),
        (o.get("assigned_object") or {}).get("device", {}).get("name"),
        o.get("description"),
    ]),
    ("Префикс", "ipam/prefixes", lambda o: [
        o["prefix"], (o.get("vlan") or {}).get("display"), o.get("description"),
    ]),
    ("Устройство", "dcim/devices", lambda o: [
        o.get("name") or o["display"], (o.get("primary_ip") or {}).get("address"),
        (o.get("site") or {}).get("name"), (o.get("role") or {}).get("name"),
    ]),
    ("VLAN", "ipam/vlans", lambda o: [
        f'{o["vid"]} {o["name"]}', (o.get("group") or {}).get("name"), o.get("description"),
    ]),
    ("VM", "virtualization/virtual-machines", lambda o: [
        o["name"], (o.get("primary_ip") or {}).get("address"), (o.get("cluster") or {}).get("name"),
    ]),
]


def notify(text):
    subprocess.run(["notify-send", "NetBox", text])


def rofi(lines, prompt):
    res = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", prompt],
        input="\n".join(lines), capture_output=True, text=True,
    )
    return res.stdout.strip() if res.returncode == 0 else None


def api(token, endpoint, query):
    scheme = "Bearer" if token.startswith("nbt_") else "Token"
    url = f"{NETBOX}/api/{endpoint}/?" + urllib.parse.urlencode({"q": query, "limit": LIMIT, "brief": 0})
    req = urllib.request.Request(url, headers={"Authorization": f"{scheme} {token}", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.load(resp)["results"]


def loc_rows(query):
    """Строки из loc.py --json: [(метка, [поля]), ...]."""
    try:
        res = subprocess.run(["python3", LOC_PY, query, "--json"], capture_output=True, text=True, timeout=20)
        data = json.loads(res.stdout)
    except Exception:
        return []
    rows = []
    for r in data.get("access", []):
        rows.append(("Порт", [f'{r["switch"]} {r["port"]}', f'VLAN {r["vlan"]}' if r.get("vlan") else None,
                                r.get("mac"), r.get("ip"), r.get("name")]))
    for r in data.get("wifi", []):
        rows.append(("Wi-Fi", [r.get("ap"), r.get("ssid"), r.get("rssi"), r.get("mac"), r.get("ip"), r.get("client")]))
    for r in data.get("apport", []):
        rows.append(("AP-порт", [f'{r["switch"]} {r["port"]}', r.get("apmac")]))
    for r in data.get("dhcp", []):
        rows.append(("DHCP", [r.get("ip"), r.get("mac"), r.get("server"), r.get("comment")]))
    arp = {}
    for r in data.get("arp", []):
        arp.setdefault((r["ip"], r["mac"], r.get("name")), set()).add(r["seen"])
    for (ip, mac, name), seen in arp.items():
        rows.append(("ARP", [ip, mac, name, f"на {len(seen)} устр."]))
    trunks = data.get("trunks", [])
    if trunks:
        rows.append(("Транки", [f'{len(trunks)} записей на {len({t["switch"] for t in trunks})} устр.']))
    return rows


def main():
    try:
        token = open(TOKEN_FILE).read().strip()
        # допускаем, что вставлен заголовок целиком: "Bearer nbt_…" / "Token …"
        token = token.split()[-1] if token else token
    except OSError:
        notify(f"Нет токена API. Положите его в {TOKEN_FILE}")
        return 1

    # MAC/IP из буфера обмена — уже в списке, достаточно Enter
    # только текст: в буфере может лежать картинка после скриншота
    clip = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], capture_output=True,
                          text=True, errors="replace", timeout=2).stdout.strip()[:64]
    query = rofi([clip] if LOC_RE.fullmatch(clip) else [], "Поиск")
    if not query:
        return 0
    query = query.strip()
    # "net …" — только NetBox, "loc …" — только loc.py
    only = None
    head, _, rest = query.partition(" ")
    if head.lower() in ("net", "loc") and rest.strip():
        only, query = head.lower(), rest.strip()
    # набрано в русской раскладке (MAC: фисвуа → abcdef)
    if LOC_RE.fullmatch(query.translate(RU_TO_EN)):
        query = query.translate(RU_TO_EN)
    is_loc = bool(LOC_RE.fullmatch(query)) and only != "net"

    def search(kind):
        label, endpoint, describe = kind
        try:
            return [(label, describe(o), o) for o in api(token, endpoint, query)]
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise
            return []
        except Exception:
            return []

    try:
        with ThreadPoolExecutor(len(KINDS) + 1) as pool:
            loc_future = pool.submit(loc_rows, query) if is_loc else None
            found = [] if only == "loc" else [r for rows in pool.map(search, KINDS) for r in rows]
            located = loc_future.result() if loc_future else []
    except urllib.error.HTTPError as e:
        notify(f"Ошибка доступа к API ({e.code}): проверьте токен")
        return 1

    if not found and not located:
        subprocess.run(["rofi", "-e", f"Ничего не найдено: {query}"])
        return 0

    # loc.py первым: где подключено важнее, чем запись в NetBox
    entries = [(label, parts, None) for label, parts in located] + found
    width = max(len(label) for label, _, _ in entries)
    lines = [
        f"{'loc' if obj is None else 'net'}  {label:<{width}}  " + "  ·  ".join(str(p) for p in parts if p and p != "-")
        for label, parts, obj in entries
    ]
    choice = rofi(lines, query)
    if not choice:
        return 0
    obj = entries[lines.index(choice)][2]
    if obj is None:
        subprocess.Popen([LOC_SEARCH, query])
        return 0
    url = obj.get("url", "").replace("/api/", "/", 1)
    subprocess.Popen(["firefoxpwa", "site", "launch", PWA_ID, "--url", url])
    return 0


if __name__ == "__main__":
    sys.exit(main())
