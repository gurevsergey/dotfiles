#!/usr/bin/env python3
"""Обзор окон (SUPER+TAB): все окна по столам → rofi → перейти к выбранному."""
import json
import subprocess

WS_NAMES = {
    "1": "Сеть", "2": "Работа", "3": "Код", "4": "Мониторинг", "5": "Заметки", "6": "Чат",
    "special:bitwarden": "Bitwarden", "special:music": "Музыка", "special:spotify": "Spotify",
    "special:dropterm": "Терминал", "special:magic": "Карман",
}


def ws_key(c):
    name = c["workspace"]["name"]
    return (name.startswith("special"), int(name) if name.isdigit() else 99, name, c["at"][0])


clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout)
clients = sorted((c for c in clients if c["mapped"] and c["title"]), key=ws_key)

rows = []
for c in clients:
    ws = c["workspace"]["name"]
    if ws.startswith("special:"):
        label = f'★  {WS_NAMES.get(ws, ws[8:])}'
    else:
        label = f'{ws}  {WS_NAMES.get(ws, "")}'
    icon = c["class"].lower()
    rows.append(f'{label:<16}  {c["title"]}\0icon\x1f{icon}')

res = subprocess.run(
    ["rofi", "-dmenu", "-i", "-show-icons", "-format", "i", "-p", "Окна"],
    input="\n".join(rows), capture_output=True, text=True,
)
if res.returncode == 0 and res.stdout.strip():
    addr = clients[int(res.stdout.strip())]["address"]
    subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{addr}" }})'], capture_output=True)
