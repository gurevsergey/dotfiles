#!/usr/bin/env python3
"""NVMe endurance indicator via UDisks; no sudo or password prompts."""
import fcntl
import html
import json
import os
from pathlib import Path
import subprocess
import time
from datetime import datetime

SERVICE = "org.freedesktop.UDisks2"
PROPS = "org.freedesktop.DBus.Properties"
NVME = "org.freedesktop.UDisks2.NVMe.Controller"
BLOCK = "/org/freedesktop/UDisks2/block_devices/nvme0n1"
INTERVAL = 600


def bus(*args):
    result = subprocess.run(
        ["busctl", "--system", "--allow-interactive-authorization=no", "--json=short", *args],
        capture_output=True, text=True, timeout=12,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "UDisks недоступен")
    return json.loads(result.stdout)["data"] if result.stdout.strip() else None


def values(data):
    return {key: value["data"] for key, value in data[0].items()}


def read_smart():
    drive = bus("get-property", SERVICE, BLOCK, "org.freedesktop.UDisks2.Block", "Drive")
    note = ""
    try:
        bus("call", SERVICE, drive, NVME, "SmartUpdate", "a{sv}", "1",
            "auth.no_user_interaction", "b", "true")
    except (RuntimeError, subprocess.TimeoutExpired):
        note = "Обновление недоступно; показаны последние данные UDisks."
    attrs = values(bus("call", SERVICE, drive, NVME, "SmartGetAttributes", "a{sv}", "0"))
    props = values(bus("call", SERVICE, drive, PROPS, "GetAll", "s", NVME))
    model = bus("get-property", SERVICE, drive, "org.freedesktop.UDisks2.Drive", "Model")
    wear = int(attrs["percent_used"])
    warnings = props["SmartCriticalWarning"]
    errors = int(attrs["media_errors"])
    spare = int(attrs["avail_spare"])
    updated = int(props["SmartUpdated"])
    if updated <= 0:
        raise RuntimeError("SMART ещё не прочитан")
    temperature = float(props["SmartTemperature"]) - 273.15
    status = "normal"
    if wear >= 80 or errors:
        status = "warning"
    if wear >= 100 or warnings or spare < int(attrs["spare_thresh"]):
        status = "critical"
    if temperature >= float(attrs["cctemp"]) - 273.15:
        status = "critical"
    elif temperature >= float(attrs["wctemp"]) - 273.15 and status == "normal":
        status = "warning"
    if time.time() - updated > 1800:
        status = "stale" if status == "normal" else status
        note = "Данные SMART старше 30 минут. " + note
    tooltip = (f"{model}\n"
               f"Израсходованный ресурс: {wear}% (оценка контроллера)\n"
               "Это износ, а не заполненность диска.\n"
               f"Температура: {temperature:.0f} °C\n"
               f"Доступный резерв: {spare}%\n"
               f"Ошибки данных: {errors}\n"
               f"Предупреждения: {', '.join(warnings) if warnings else 'нет'}\n"
               f"SMART обновлён: {datetime.fromtimestamp(updated):%d.%m %H:%M}")
    if note:
        tooltip += "\n" + note
    return {"text": f"󰋊 SSD {wear}%", "tooltip": html.escape(tooltip), "class": status}


def main():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    cache = runtime / "waybar-ssd-wear.json"
    # Both monitor bars share one read every ten minutes.
    with (runtime / "waybar-ssd-wear.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            previous = json.loads(cache.read_text())
        except (OSError, ValueError):
            previous = {}
        if time.time() - previous.get("timestamp", 0) < INTERVAL and "result" in previous:
            result = previous["result"]
        else:
            try:
                result = read_smart()
                temp = cache.with_suffix(".tmp")
                temp.write_text(json.dumps({"timestamp": time.time(), "result": result}, ensure_ascii=False))
                os.replace(temp, cache)
            except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.TimeoutExpired) as error:
                result = {"text": "󰋊 SSD ?", "class": "unavailable",
                          "tooltip": html.escape(f"SMART недоступен: {error}")}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
