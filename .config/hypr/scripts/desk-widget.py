#!/usr/bin/env python3
"""Виджет на рабочем столе: Kubernetes, Git, Docker и локальная LLM (Strata).

Слой gtk-layer-shell BOTTOM (над обоями, под окнами), левый нижний угол —
на месте бывшей надписи на обоях bento. Сетка 2×2 из карточек одного размера:
  KUBERNETES  — kubectl (текущий контекст): узлы, поды по namespace, проблемные поды, VM KubeVirt
  GIT         — репозитории в ~/Projects: ветка, изменения, ahead/behind, последний коммит
  DOCKER      — запущенные контейнеры и статус; клик по строке — логи в kitty
  LOCAL LLM   — Strata на 127.0.0.1:8080: модель, состояние, скорость, VRAM/GPU;
                ComfyUI на 127.0.0.1:8188: очередь и занятая им VRAM (клик — открыть в браузере)
Данные собираются в фоновом потоке: Docker/LLM — 3 с, Kubernetes — 15 с, Git — 30 с.

Запуск из автостарта hyprland.lua; перезапуск:
  pkill -x desk-widget; hyprctl dispatch 'hl.dsp.exec_cmd("~/.config/hypr/scripts/desk-widget.py")'
"""
import ctypes
import json
import os
import pathlib
import subprocess
import threading
import time
import urllib.request

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gdk, Gtk, GtkLayerShell  # noqa: E402

# имя процесса для pkill -x
try:
    ctypes.CDLL(None).prctl(15, b"desk-widget", 0, 0, 0)
except Exception:
    pass

HOME = pathlib.Path.home()
# kubectl/virtctl лежат в ~/.local/bin — при запуске из Hyprland PATH может быть коротким
os.environ["PATH"] = f"{HOME}/.local/bin:" + os.environ.get("PATH", "/usr/bin")

# палитра bento Unit-01
INK, TEXT, MUTED, SUBTLE = "#0b0b0b", "#e8e0d0", "#a8a8a8", "#6a6a6a"
MAIN, ART, OK, WARN, BAD = "#e0a060", "#c8312b", "#8cc086", "#e8c547", "#e0544a"

# геометрия под обои gen-wallpaper.py --style minimal (2560×1440): отступ 3 % ширины,
# низ виджета — над строкой характеристик
MARGIN_LEFT, MARGIN_BOTTOM, CARD_W, GAP = 77, 278, 560, 14
MAX_DOCKER, MAX_GIT, MAX_K8S = 4, 7, 5
STRATA = "http://127.0.0.1:8080"
COMFY = "http://127.0.0.1:8188"
GIT_ROOTS = [HOME / "Projects"]
GIT_DEPTH = 4
EVERY = {"fast": 3, "k8s": 15, "git": 30}

CSS = f"""
window {{ background: transparent; }}
.card {{
    background: rgba(11, 11, 11, 0.88);
    border: 2px solid #262626;
    border-radius: 10px;
    padding: 14px 16px;
}}
.head {{ font-family: "Archivo Black"; font-size: 22px; color: {MAIN}; }}
.pill {{
    font-family: "JetBrainsMono Nerd Font"; font-weight: 700; font-size: 13px;
    background: {MAIN}; color: {INK}; border-radius: 6px; padding: 2px 10px;
}}
.pill.ok   {{ background: #6fa06a; }}
.pill.busy {{ background: {WARN}; }}
.pill.bad  {{ background: {ART}; }}
.pill.idle {{ background: #262626; color: {MUTED}; }}
.row {{ border-radius: 6px; padding: 3px 6px; }}
eventbox:hover .row {{ background: #1a1a1a; }}
label {{ font-family: "JetBrainsMono Nerd Font"; font-size: 13px; color: {TEXT}; }}
.foot {{ color: {SUBTLE}; font-size: 12px; }}
"""


def esc(s):
    return GLib.markup_escape_text(str(s) if s is not None else "")


def run(cmd, timeout=6, cwd=None):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
        return r.returncode, r.stdout
    except Exception:
        return 1, ""


def kitty(title, *cmd):
    subprocess.Popen(["kitty", "--class", "desk-widget", "--title", title, *cmd], start_new_session=True)


def ago(ts):
    d = max(0, int(time.time() - ts))
    for n, u in ((86400 * 30, "мес"), (86400 * 7, "нед"), (86400, "д"), (3600, "ч"), (60, "мин")):
        if d >= n:
            return f"{d // n} {u}"
    return "сейчас"


# ── сбор данных ──────────────────────────────────────────────────────
def docker_state():
    """([(name, image, status, state)], stopped) или (None, 0), если демон недоступен."""
    rc, out = run(["docker", "ps", "-a", "--format", "{{json .}}"], 4)
    if rc != 0:
        return None, 0
    items, stopped = [], 0
    for line in out.splitlines():
        try:
            c = json.loads(line)
        except ValueError:
            continue
        if c.get("State") in ("running", "restarting", "paused"):
            items.append((c.get("Names", ""), c.get("Image", ""), c.get("Status", ""), c.get("State", "")))
        else:
            stopped += 1
    return sorted(items), stopped


def llm_state():
    try:
        with urllib.request.urlopen(STRATA + "/metrics", timeout=1.5) as r:
            m = json.load(r)
    except Exception:
        return None
    eng = m.get("engine", {})
    reqs = [r for r in m.get("requests", []) if r.get("decode_tok_s")]
    return {"model": eng.get("model"), "ctx": eng.get("max_context"), "drafting": eng.get("drafting"),
            "images": eng.get("images"), "live": m.get("live", {}),
            "last": max(reqs, key=lambda r: r.get("time", 0)) if reqs else None,
            "done": len(m.get("requests", []))}


def comfy_state():
    """None, если ComfyUI не отвечает; иначе версия, очередь и VRAM процесса (МиБ, из nvidia-smi)."""
    try:
        with urllib.request.urlopen(COMFY + "/system_stats", timeout=1) as r:
            stats = json.load(r)
        with urllib.request.urlopen(COMFY + "/queue", timeout=1) as r:
            q = json.load(r)
    except Exception:
        return None
    vram = None
    rc, out = run(["nvidia-smi", "--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"], 3)
    for line in out.splitlines():
        try:
            pid, mem = [x.strip() for x in line.split(",")]
            cmd = pathlib.Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
            cwd = os.readlink(f"/proc/{pid}/cwd")
        except Exception:
            continue
        if b"main.py" in cmd and b"8188" in cmd and "comfyui" in cwd.lower():
            vram = int(float(mem))
    return {"version": stats.get("system", {}).get("comfyui_version"),
            "running": len(q.get("queue_running", [])), "pending": len(q.get("queue_pending", [])),
            "vram": vram}


def gpu_state():
    rc, out = run(["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu",
                   "--format=csv,noheader,nounits"], 3)
    try:
        name, used, total, util, temp = [x.strip() for x in out.splitlines()[0].split(",")]
        return (name.replace("NVIDIA GeForce ", ""), int(float(used)), int(float(total)),
                int(float(util)), round(float(temp)))
    except Exception:
        return None


def k8s_state():
    """dict: context, nodes [(name, ready, version)], ns {ns: [running, total]}, bad [(ns/pod, reason)], vms."""
    rc, ctx = run(["kubectl", "config", "current-context"], 3)
    if rc != 0:
        return None
    rc, out = run(["kubectl", "get", "nodes,pods", "-A", "-o", "json", "--request-timeout=5s"], 8)
    if rc != 0:
        return {"context": ctx.strip(), "error": True}
    nodes, ns, bad = [], {}, []
    for it in json.loads(out).get("items", []):
        kind, meta, st = it.get("kind"), it.get("metadata", {}), it.get("status", {})
        if kind == "Node":
            ready = any(c.get("type") == "Ready" and c.get("status") == "True" for c in st.get("conditions", []))
            nodes.append((meta.get("name"), ready, st.get("nodeInfo", {}).get("kubeletVersion", "")))
        elif kind == "Pod":
            n = meta.get("namespace", "")
            phase = st.get("phase", "")
            reason = phase
            for cs in st.get("containerStatuses", []) or []:
                w = (cs.get("state") or {}).get("waiting")
                if w:
                    reason = w.get("reason", phase)
            ok = phase == "Succeeded" or (phase == "Running" and reason == "Running" and all(
                cs.get("ready") for cs in st.get("containerStatuses", []) or []))
            if phase == "Succeeded":
                continue
            c = ns.setdefault(n, [0, 0])
            c[1] += 1
            if ok:
                c[0] += 1
            else:
                bad.append((f"{n}/{meta.get('name', '')}", reason))
    vms = 0
    rc, out = run(["kubectl", "get", "vmi", "-A", "--no-headers", "--request-timeout=5s"], 6)
    if rc == 0:
        vms = len([line for line in out.splitlines() if line.strip()])
    return {"context": ctx.strip(), "nodes": nodes, "ns": ns, "bad": bad, "vms": vms}


_repos_cache = {"t": 0, "list": []}


def find_repos():
    if time.time() - _repos_cache["t"] < 600 and _repos_cache["list"]:
        return _repos_cache["list"]
    found = []
    for root in GIT_ROOTS:
        base = len(root.parts)
        for dirpath, dirs, _files in os.walk(root):
            p = pathlib.Path(dirpath)
            if ".git" in dirs:
                found.append(p)
                dirs[:] = []
                continue
            if len(p.parts) - base >= GIT_DEPTH:
                dirs[:] = []
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("node_modules", "target", "venv")]
    _repos_cache.update(t=time.time(), list=found)
    return found


def git_state():
    repos = []
    for p in find_repos():
        rc, out = run(["git", "status", "--porcelain=v2", "--branch"], 5, cwd=p)
        if rc != 0:
            continue
        branch, ahead, behind, changes, upstream = "?", 0, 0, 0, False
        for line in out.splitlines():
            if line.startswith("# branch.head "):
                branch = line.split(" ", 2)[2]
            elif line.startswith("# branch.upstream "):
                upstream = True
            elif line.startswith("# branch.ab "):
                a, b = line.split()[2:4]
                ahead, behind = int(a), -int(b)
            elif not line.startswith("#"):
                changes += 1
        rc, ts = run(["git", "log", "-1", "--format=%ct"], 3, cwd=p)
        repos.append({"name": p.name, "path": str(p), "branch": branch, "ahead": ahead, "behind": behind,
                      "changes": changes, "upstream": upstream, "ts": int(ts.strip() or 0)})
    # сначала требующие внимания, потом по свежести
    repos.sort(key=lambda r: (-(r["changes"] > 0 or r["ahead"] > 0 or r["behind"] > 0), -r["ts"]))
    return repos


# ── интерфейс ────────────────────────────────────────────────────────
class Card(Gtk.Box):
    def __init__(self, title):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.get_style_context().add_class("card")
        self.set_size_request(CARD_W, -1)
        head = Gtk.Box(spacing=12)
        h = Gtk.Label(label=title)
        h.get_style_context().add_class("head")
        self.pill = Gtk.Label()
        self.pill.get_style_context().add_class("pill")
        self.pill.set_valign(Gtk.Align.CENTER)
        head.pack_start(h, False, False, 0)
        head.pack_start(self.pill, False, False, 0)
        self.pack_start(head, False, False, 4)
        self.body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.pack_start(self.body, False, False, 0)
        self.foot = Gtk.Label(xalign=0)
        self.foot.get_style_context().add_class("foot")
        self.pack_end(self.foot, False, False, 2)
        self.set_pill("…", "idle")

    def set_pill(self, text, cls):
        ctx = self.pill.get_style_context()
        for c in ("ok", "busy", "bad", "idle"):
            ctx.remove_class(c)
        if cls:
            ctx.add_class(cls)
        self.pill.set_text(text)

    def clear(self):
        for ch in self.body.get_children():
            self.body.remove(ch)

    def row(self, markup, on_click=None):
        lbl = Gtk.Label(xalign=0)
        lbl.set_ellipsize(3)  # END
        lbl.set_markup(markup)
        box = Gtk.Box()
        box.get_style_context().add_class("row")
        box.pack_start(lbl, True, True, 0)
        if on_click:  # EventBox не рисует padding — оборачиваем Box, чтобы отступы совпадали
            ev = Gtk.EventBox()
            ev.add(box)
            ev.connect("button-press-event", lambda *_a: on_click())
            self.body.pack_start(ev, False, False, 0)
        else:
            self.body.pack_start(box, False, False, 0)

    def done(self, foot):
        self.foot.set_text(foot)
        self.body.show_all()


def sq(color):
    return f"<span color='{color}'>■</span>"


class Widget(Gtk.Window):
    def __init__(self, monitor):
        super().__init__()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_namespace(self, "desk-widget")
        GtkLayerShell.set_monitor(self, monitor)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, MARGIN_LEFT)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, MARGIN_BOTTOM)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(self, -1)  # не сдвигать окна

        vis = self.get_screen().get_rgba_visual()
        if vis:
            self.set_visual(vis)
        self.set_app_paintable(True)

        # сетка 2×2: все карточки одной ширины и высоты
        grid = Gtk.Grid(column_spacing=GAP, row_spacing=GAP, column_homogeneous=True, row_homogeneous=True)
        self.k8s, self.git = Card("KUBERNETES"), Card("GIT")
        self.docker, self.llm = Card("DOCKER"), Card("LOCAL LLM")
        grid.attach(self.k8s, 0, 0, 1, 1)
        grid.attach(self.git, 1, 0, 1, 1)
        grid.attach(self.docker, 0, 1, 1, 1)
        grid.attach(self.llm, 1, 1, 1, 1)
        self.add(grid)
        self.show_all()

    # KUBERNETES
    def update_k8s(self, s):
        c = self.k8s
        c.clear()
        if s is None:
            c.set_pill("NO CONTEXT", "idle")
            c.done("kubectl не настроен")
            return
        if s.get("error"):
            c.set_pill("UNREACHABLE", "bad")
            c.row(f"{sq(BAD)}  <b>{esc(s['context'])}</b>  <span color='{SUBTLE}'>API не отвечает</span>")
            c.done("kubectl get nodes — ошибка")
            return
        nodes, ns, bad = s["nodes"], s["ns"], s["bad"]
        ready = sum(r for _, r, _ in nodes)
        run_, total = sum(v[0] for v in ns.values()), sum(v[1] for v in ns.values())
        c.set_pill(f"{run_}/{total} PODS" + (f" · {len(bad)} BAD" if bad else ""),
                   "bad" if bad or ready < len(nodes) else "ok")
        for name, r, ver in nodes:
            c.row(f"{sq(OK if r else BAD)}  <b>{esc(name)}</b>  "
                  f"<span color='{MUTED}'>{'Ready' if r else 'NotReady'} · {esc(ver)}</span>")
        lines = []
        for n, (ok_, tot) in sorted(ns.items(), key=lambda kv: (kv[1][0] == kv[1][1], kv[0])):
            col = OK if ok_ == tot else BAD
            lines.append(f"<span color='{col}'>{esc(n)}</span> <span color='{MUTED}'>{ok_}/{tot}</span>")
        # namespace по три в строку
        for i in range(0, len(lines), 3):
            c.row("   " + "   ".join(lines[i:i + 3]))
        for pod, reason in bad[:MAX_K8S]:
            c.row(f"{sq(BAD)}  {esc(pod)}  <span color='{BAD}'>{esc(reason)}</span>",
                  lambda p=pod: kitty(f"kubectl describe {p}", "sh", "-c",
                                      f"kubectl describe pod -n {p.split('/')[0]} {p.split('/')[1]} | less"))
        foot = f"{esc(s['context'])} · VM KubeVirt: {s['vms']}"
        c.done(foot)

    # GIT
    def update_git(self, repos):
        c = self.git
        c.clear()
        if not repos:
            c.set_pill("NO REPOS", "idle")
            c.done("в ~/Projects нет репозиториев")
            return
        dirty = [r for r in repos if r["changes"] or r["ahead"] or r["behind"]]
        c.set_pill(f"{len(dirty)} DIRTY" if dirty else "CLEAN", "busy" if dirty else "ok")
        for r in repos[:MAX_GIT]:
            marks = []
            if r["changes"]:
                marks.append(f"<span color='{WARN}'>●{r['changes']}</span>")
            if r["ahead"]:
                marks.append(f"<span color='{MAIN}'>↑{r['ahead']}</span>")
            if r["behind"]:
                marks.append(f"<span color='{BAD}'>↓{r['behind']}</span>")
            if not r["upstream"]:
                marks.append(f"<span color='{SUBTLE}'>local</span>")
            col = WARN if r["changes"] else (MAIN if r["ahead"] or r["behind"] else OK)
            c.row(f"{sq(col)}  <b>{esc(r['name'])}</b>  <span color='{SUBTLE}'>{esc(r['branch'])}</span>  "
                  f"{' '.join(marks)}  <span color='{SUBTLE}'>{ago(r['ts']) if r['ts'] else ''}</span>",
                  lambda p=r["path"]: kitty(f"git {pathlib.Path(p).name}", "--directory", p, "sh", "-c",
                                            "git status; git log --oneline -15; exec $SHELL"))
        more = f" · ещё {len(repos) - MAX_GIT}" if len(repos) > MAX_GIT else ""
        c.done(f"репозиториев: {len(repos)}{more} · клик — git status")

    # DOCKER
    def update_docker(self, items, stopped):
        c = self.docker
        c.clear()
        if items is None:
            c.set_pill("OFFLINE", "bad")
            c.done("docker недоступен")
            return
        bad = sum("unhealthy" in s for _, _, s, _ in items)
        c.set_pill(f"{len(items)} RUNNING" + (f" · {bad} UNHEALTHY" if bad else ""),
                   "bad" if bad else ("ok" if items else "idle"))
        for name, image, status, state in items[:MAX_DOCKER]:
            col = BAD if "unhealthy" in status else (WARN if state != "running" or "starting" in status else OK)
            c.row(f"{sq(col)}  <b>{esc(name)}</b>  <span color='{SUBTLE}'>{esc(image)}</span>\n"
                  f"   <span color='{MUTED}'>{esc(status)}</span>",
                  lambda n=name: kitty(f"docker logs {n}", "docker", "logs", "-f", "--tail", "200", n))
        if len(items) > MAX_DOCKER:
            c.row(f"<span color='{SUBTLE}'>   … ещё {len(items) - MAX_DOCKER}</span>")
        foot = "нет запущенных контейнеров" if not items else "клик — логи контейнера"
        if stopped:
            foot += f" · остановлено: {stopped}"
        c.done(foot)

    # LOCAL LLM
    def update_llm(self, s, gpu, comfy=None):
        c = self.llm
        c.clear()
        mon = lambda: kitty("strata monitor", "strata", "monitor", "--url", STRATA)  # noqa: E731
        if s is None:
            c.set_pill("OFFLINE", "idle")
            c.row(f"{sq(SUBTLE)}  Strata не запущена  <span color='{SUBTLE}'>127.0.0.1:8080</span>")
        else:
            live = s["live"] or {}
            st = live.get("state") or "idle"
            if st == "idle":
                c.set_pill("READY", "ok")
            else:
                tok = live.get("tok_s")
                c.set_pill(st.upper() + (f" · {tok:.0f} tok/s" if tok else ""), "busy")
            feats = [f"{(s['ctx'] or 0) // 1024}k ctx"]
            if s.get("drafting"):
                feats.append(str(s["drafting"]).upper())
            if s.get("images"):
                feats.append("vision")
            c.row(f"{sq(OK if st == 'idle' else WARN)}  <b>{esc(s['model'])}</b>\n"
                  f"   <span color='{MUTED}'>{esc(' · '.join(feats))}</span>", mon)
            if st != "idle" and live.get("generated") is not None:
                c.row(f"   <span color='{MUTED}'>генерирует: {live.get('generated')} ток · "
                      f"{live.get('elapsed_s') or 0:.0f} с · в очереди {live.get('queued', 0)}</span>")
            last = s.get("last")
            if last:
                c.row(f"   <span color='{MUTED}'>последний ответ: {last['decode_tok_s']:.0f} tok/s · "
                      f"{last.get('output_tokens', 0)} ток · {last.get('duration_s', 0):.1f} с</span>")
        if comfy is None:
            c.row(f"{sq(SUBTLE)}  <span color='{SUBTLE}'>ComfyUI не запущен  127.0.0.1:8188</span>")
        else:
            busy = comfy["running"] or comfy["pending"]
            state = (f"генерирует · в очереди {comfy['pending']}" if busy else "простаивает")
            vram = f" · VRAM {comfy['vram'] / 1024:.1f} GB" if comfy["vram"] is not None else ""
            c.row(f"{sq(WARN if busy else OK)}  <b>ComfyUI</b> <span color='{MUTED}'>"
                  f"{esc(comfy['version'] or '')}  {state}{vram}</span>",
                  lambda: subprocess.Popen(["xdg-open", COMFY], start_new_session=True))
        if gpu:
            name, used, total, util, temp = gpu
            k = max(0, min(16, round(used / total * 16)))
            bar = f"<span color='{MAIN}'>{'█' * k}</span><span color='#262626'>{'█' * (16 - k)}</span>"
            c.row(f"   <span color='{MUTED}'>{esc(name)}  VRAM</span> {bar} "
                  f"<span color='{MUTED}'>{used / 1024:.1f}/{total / 1024:.1f} GB</span>")
            c.row(f"   <span color='{MUTED}'>GPU {util:>3}%  ·  {temp}°C</span>")
        c.done("клик — strata monitor" + (f" · ответов: {s['done']}" if s else ""))


def main():
    prov = Gtk.CssProvider()
    prov.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    disp = Gdk.Display.get_default()
    widgets = [Widget(disp.get_monitor(i)) for i in range(disp.get_n_monitors())]

    def apply(kind, data):
        for w in widgets:
            if kind == "fast":
                (items, stopped), llm, gpu, comfy = data
                w.update_docker(items, stopped)
                w.update_llm(llm, gpu, comfy)
            elif kind == "k8s":
                w.update_k8s(data)
            elif kind == "git":
                w.update_git(data)
        return False

    collectors = {
        "fast": lambda: (docker_state(), llm_state(), gpu_state(), comfy_state()),
        "k8s": k8s_state,
        "git": git_state,
    }

    def loop(kind):
        while True:
            try:
                data = collectors[kind]()
                GLib.idle_add(apply, kind, data)
            except Exception as e:  # не роняем виджет из-за одного источника
                print(f"desk-widget {kind}: {e}", flush=True)
            time.sleep(EVERY[kind])

    for kind in collectors:
        threading.Thread(target=loop, args=(kind,), daemon=True).start()
    Gtk.main()


if __name__ == "__main__":
    main()
