#!/usr/bin/env python3
"""Обои рабочего стола в стиле экрана блокировки bento-login (hyprlock).

Та же сетка из четырёх карточек и та же палитра, но без формы входа:
в главной карточке — характеристики ПК, в зелёной — «SESSION ACTIVE»
и горячие клавиши, в серой — номер монитора.

  gen-wallpaper.py [--palette N] [--out-dir ~/.config/hypr/bento-desktop]

Пишет по PNG на каждый монитор (bg-<имя>.png) и hyprpaper.conf.
"""
import argparse
import configparser
import json
import pathlib
import re
import socket
import subprocess

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
THEME = HERE.parent
HOME = pathlib.Path.home()

ap = argparse.ArgumentParser()
ap.add_argument("--palette", type=int, default=0)
ap.add_argument("--style", choices=["minimal", "cards"], default="minimal",
                help="minimal — спокойный чёрный фон; cards — сетка карточек как у экрана блокировки")
ap.add_argument("--out-dir", default=str(HOME / ".config/hypr/bento-desktop"))
ap.add_argument("--hyprpaper", default=str(HOME / ".config/hypr/hyprpaper.conf"))
args = ap.parse_args()

cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(THEME / "theme.conf", encoding="utf-8")
C = cp["General"]


def conf(key, default=""):
    return C.get(key, default).replace("\\n", "\n")


pal_n = args.palette or int(conf("defaultPalette", "1"))
P = {k: conf(f"palette{pal_n}_{k}", d) for k, d in {
    "background": "#0b0b0b", "art": "#c8312b", "main": "#e0a060", "session": "#6fa06a",
    "clock": "#a8a8a8", "accent": "#d43a2f", "ink": "#0b0b0b"}.items()}
title = conf("title", "EVANGELION")
if "%" in title:
    title = re.sub(r"%[A-Z_]+%", socket.gethostname().upper(), title)

FD = THEME / "fonts"
F_DISPLAY = FD / "ArchivoBlack-Regular.ttf"
F_SANS = FD / "SpaceGrotesk.ttf"
F_MONO_B = FD / "JetBrainsMonoNerdFontMono-Bold.ttf"
F_CJK = pathlib.Path("/usr/share/fonts/TTF/IBMPlexSansJP-Bold.ttf")


def font(path, px):
    return ImageFont.truetype(str(path), max(1, round(px)))


def hexc(c, a=255):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return ""


# ── статичные сведения о ПК ──────────────────────────────────────────
osr = dict(l.split("=", 1) for l in pathlib.Path("/etc/os-release").read_text().splitlines() if "=" in l)
os_name = osr.get("PRETTY_NAME", "Linux").strip('"')
cpu = sh(r"""awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo | sed -E 's/\((R|TM)\)//g; s/ (CPU|Processor)//g; s/ [0-9]+-Core//; s/^(AMD|Intel) //; s/ +/ /g; s/ @.*//'""")
cores = sh("lscpu -p=core | grep -v '^#' | sort -u | wc -l")
threads = sh("nproc --all")
gpu = sh("lspci | grep -Ei 'vga|3d controller' | head -1")
m = re.search(r"\[([^\]]+)\][^\[]*$", gpu)
gpu = re.sub(r"^(GeForce|Radeon|Intel) ", "", m.group(1) if m else gpu)
ram = sh("""awk '/^MemTotal/{printf "%d GB", ($2/1048576)+0.5}' /proc/meminfo""")
specs = f"CPU   {cpu} · {cores}C/{threads}T\nGPU   {gpu}\nRAM   {ram}\nOS    {os_name}"
host = socket.gethostname()

# ── мониторы ─────────────────────────────────────────────────────────
try:
    mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)
except Exception:
    mons = []
if not mons:
    mons = [{"name": "", "width": 2560, "height": 1440, "scale": 1, "x": 0, "y": 0}]
mons.sort(key=lambda m: (m["x"], m["y"]))


def render(W, H, index, mon_name):
    u = min(W / 1920, H / 1080)
    m_ = W * 0.03
    g = W * 0.012
    innerH = H - 2 * m_
    leftW = W * 0.20
    rightX = m_ + leftW + g
    rightW = W - rightX - m_
    topH = (innerH - g) * 0.6
    botH = innerH - g - topH
    botW = (rightW - g) / 2
    R = 16 * u
    ART = (m_, m_, leftW, innerH)
    MAIN = (rightX, m_, rightW, topH)
    SESS = (rightX, m_ + topH + g, botW, botH)
    CLK = (rightX + botW + g, m_ + topH + g, botW, botH)
    ink = hexc(P["ink"])

    img = Image.new("RGBA", (W, H), hexc(P["background"]))
    d = ImageDraw.Draw(img)

    def card(box, color):
        x, y, w, h = box
        d.rounded_rectangle((x, y, x + w, y + h), R, fill=hexc(color))

    def frame(x, y, w, h, bw, r=0):
        d.rounded_rectangle((x, y, x + w, y + h), r, outline=ink, width=max(1, round(bw)))

    def text(x, y, s, f, anchor="la", color=None, **kw):
        fill = hexc(color) if color else ink
        if "\n" in s:
            d.multiline_text((x, y), s, font=f, fill=fill, anchor=anchor, **kw)
        else:
            d.text((x, y), s, font=f, fill=fill, anchor=anchor)

    # ── 1: арт ──
    ax, ay, aw, ah = map(round, ART)
    art = Image.new("RGBA", (aw, ah), hexc(P["art"]))
    bgp = THEME / conf("background", "background.png")
    if bgp.exists():
        src = Image.open(bgp).convert("RGBA")
        k = max(aw / src.width, ah / src.height)
        src = src.resize((round(src.width * k), round(src.height * k)), Image.LANCZOS)
        src = src.crop(((src.width - aw) // 2, (src.height - ah) // 2,
                        (src.width - aw) // 2 + aw, (src.height - ah) // 2 + ah))
        art.alpha_composite(src)
    ad = ImageDraw.Draw(art)
    ad.text((22 * u, 20 * u), f"{index:02d}", font=font(F_DISPLAY, 26 * u), fill=ink)
    ad.multiline_text((aw - 22 * u, 22 * u), f"{os_name}\n{host}", font=font(F_MONO_B, 13 * u),
                      fill=ink, anchor="ra", align="right", spacing=round(4 * u))
    glyphs = list(conf("artGlyphs", "独創"))
    gs = 118 * u
    if F_CJK.exists():
        fc = font(F_CJK, gs)
        for i, ch in enumerate(glyphs):
            ad.text((24 * u, ah - 18 * u - (len(glyphs) - 1 - i) * gs * 1.02), ch, font=fc, fill=ink, anchor="ld")
    mask = Image.new("L", (aw, ah), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, aw - 1, ah - 1), R, fill=255)
    img.paste(art, (ax, ay), mask)

    # ── 2: главная ──
    card(MAIN, P["main"])
    mx, my, mw, mh = MAIN
    pad = 34 * u
    ft = font(F_DISPLAY, 78 * u)
    text(mx + pad, my + 22 * u + 0.12 * 78 * u, title, ft)
    tw = d.textlength(title, font=ft)
    dot = 13 * u
    dx, dy = mx + pad + tw + 10 * u, my + 38 * u
    d.ellipse((dx, dy, dx + dot, dy + dot), fill=hexc(P["accent"]))
    s = 86 * u
    axx, ayy = mx + mw - pad - s, my + pad
    d.polygon([(axx + s * .30, ayy), (axx + s, ayy), (axx + s, ayy + s * .70)], fill=ink)
    d.line([(axx + s * .06, ayy + s * .94), (axx + s * .70, ayy + s * .30)], fill=ink, width=round(s * .16))

    midH = 262 * u
    title_bottom = my + 22 * u + 78 * u * 1.19
    foot = my + mh - 26 * u
    midY = max(title_bottom + 12 * u, (title_bottom + foot - 44 * u * 1.19) / 2 - midH / 2)

    # панель «система»: шапка как у панели входа
    px_ = mx + pad
    pw = min(820 * u, mw * 0.58)
    frame(px_, midY, pw, midH, 3 * u)
    hh = 42 * u
    d.rectangle((px_, midY + hh - 2 * u, px_ + pw, midY + hh), fill=ink)
    fm = font(F_MONO_B, 14 * u)
    text(px_ + 20 * u, midY + hh / 2, host, fm, anchor="lm")
    text(px_ + pw - 20 * u, midY + hh / 2, "ONLINE", fm, anchor="rm")
    sq = 10 * u
    sx0 = px_ + pw - 20 * u - d.textlength("ONLINE", font=fm) - 12 * u - sq
    d.rectangle((sx0, midY + hh / 2 - sq / 2, sx0 + sq, midY + hh / 2 + sq / 2), fill=hexc(P["accent"]))
    fs = font(F_MONO_B, 15 * u)
    text(px_ + 20 * u, midY + hh + (midH - hh) / 2, specs, fs, anchor="lm", spacing=round(10 * u))

    # шкала-декор справа от панели
    qx = px_ + pw + 40 * u
    fq = font(F_MONO_B, 13 * u)
    quote = "Identity verified at the edge.\nEvery session is a negotiation\nbetween the machine and whoever\nremembers the password."
    text(qx, midY + midH / 2, quote, fq, anchor="lm", spacing=round(6 * u))

    text(mx + pad, foot, "#" + host.upper(), font(F_DISPLAY, 44 * u), anchor="ls")
    text(mx + mw - pad, foot - 4 * u, "SYSTEM READY", font(F_MONO_B, 14 * u), anchor="rs")

    # ── 3: сессия ──
    card(SESS, P["session"])
    sx, sy, sw, sh_ = SESS
    fx, fy, fw3, fh3 = sx + 20 * u, sy + 20 * u, sw - 40 * u, sh_ - 40 * u
    frame(fx, fy, fw3, fh3, 1.5 * u, 10 * u)
    ip = 22 * u
    keys = [("SUPER + ENTER", "TERMINAL"), ("SUPER + SPACE", "LAUNCHER"), ("SUPER + X", "SSH HOSTS"),
            ("SUPER + C", "CLOSE"), ("SUPER + M", "POWER")]
    fk = font(F_MONO_B, 12 * u)
    for i, (k_, v) in enumerate(keys):
        y = fy + ip + i * 20 * u
        text(fx + ip, y, k_, fk)
        text(fx + ip + 170 * u, y, v, fk)
    hint_bottom = fy + fh3 - ip
    fhint = font(F_MONO_B, 11 * u)
    hint = "SESSION 01 / 01\nWORKSPACES 1–9"
    text(fx + ip, hint_bottom, hint, fhint, anchor="ld", spacing=round(4 * u))
    hint_h = d.multiline_textbbox((0, 0), hint, font=fhint, spacing=round(4 * u))[3]
    rule_y = hint_bottom - hint_h - 14 * u
    d.rectangle((fx + ip, rule_y, fx + fw3 - ip, rule_y + max(1, 1.5 * u)), fill=ink)
    text(fx + ip, rule_y - 12 * u, "HYPRLAND", font(F_DISPLAY, 44 * u), anchor="ld")
    text(fx + fw3 - ip, rule_y - 14 * u, conf("sessionTag", "DE"), font(F_DISPLAY, 26 * u), anchor="rd")
    text(fx + ip, rule_y - 12 * u - 44 * u * 1.05, "SESSION ACTIVE", font(F_MONO_B, 11 * u), anchor="ld")

    # ── 4: монитор ──
    card(CLK, P["clock"])
    cx_, cy_, cw_, ch_ = CLK
    ls = 44 * u
    lx, ly = cx_ + cw_ - 30 * u - ls, cy_ + 28 * u
    d.polygon([(lx, ly), (lx + ls * .42, ly), (lx + ls * .42, ly + ls * .55), (lx, ly + ls)], fill=ink)
    d.polygon([(lx + ls * .58, ly), (lx + ls, ly), (lx + ls * .58, ly + ls * .45)], fill=ink)
    d.polygon([(lx + ls, ly + ls * .22), (lx + ls, ly + ls), (lx + ls * .30, ly + ls)], fill=ink)
    text(cx_ + 30 * u, cy_ + 26 * u, f"Display {mon_name or '—'}\n{W}×{H}", font(F_SANS, 26 * u),
         spacing=round(6 * u))
    big = min(ch_ * 0.58, cw_ * 0.30)
    num = f"{index:02d}"
    fb = font(F_DISPLAY, big)
    text(cx_ + 22 * u, cy_ + ch_ - 4 * u, num[0], fb, anchor="ld")
    w0 = d.textlength(num[0], font=fb)
    text(cx_ + 22 * u + w0, cy_ + ch_ - 4 * u, num[1:], fb, anchor="ld", color=P["accent"])
    return img


def render_minimal(W, H, index, mon_name):
    """Спокойный вариант: чёрный фон, тёмный номер, иероглифы, полоса и плитки палитры."""
    u = min(W / 1920, H / 1080)
    m_ = W * 0.03
    bgc = hexc(P["background"])
    dim1, dim2 = (24, 24, 24, 255), (34, 34, 34, 255)
    img = Image.new("RGBA", (W, H), bgc)
    d = ImageDraw.Draw(img)

    # тонкая сетка точек
    step = 48 * u
    y = step
    while y < H:
        x = step
        while x < W:
            d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=(22, 22, 22, 255))
            x += step
        y += step

    # огромный номер монитора справа: первая цифра тёмная, вторая — приглушённый акцент
    num = f"{index:02d}"
    fb = font(F_DISPLAY, H * 0.62)
    right = W - m_
    base = H - m_ - 70 * u
    w1 = d.textlength(num[1], font=fb)
    acc = hexc(P["accent"])
    mix = tuple(round(acc[i] * 0.4 + bgc[i] * 0.6) for i in range(3)) + (255,)
    d.text((right, base), num[1], font=fb, fill=mix, anchor="rs")
    d.text((right - w1, base), num[0], font=fb, fill=dim1, anchor="rs")

    # иероглифы столбиком слева
    if F_CJK.exists():
        gs = 150 * u
        fc = font(F_CJK, gs)
        for i, ch in enumerate(conf("artGlyphs", "独創")):
            d.text((m_, m_ + 10 * u + i * gs * 1.05), ch, font=fc, fill=dim2, anchor="la")

    # подпись (заголовок EVANGELION убран по просьбе 2026-11-25)
    fm = font(F_MONO_B, 13 * u)
    info = f"{host.upper()} · DISPLAY {mon_name or '—'} · {W}×{H}\nCPU {cpu} · GPU {gpu} · RAM {ram}"
    d.multiline_text((m_, H - m_ - 128 * u), info, font=fm, fill=hexc(P["clock"]), anchor="la",
                     spacing=round(6 * u))

    # плитки палитры (как карточки экрана блокировки)
    tile, gap = 46 * u, 8 * u
    ty = H - m_ - tile
    for i, c in enumerate((P["art"], P["main"], P["session"], P["clock"])):
        x0 = m_ + i * (tile + gap)
        d.rounded_rectangle((x0, ty, x0 + tile, ty + tile), 8 * u, fill=hexc(c))
    d.text((m_ + 4 * (tile + gap) + 10 * u, ty + tile / 2), "UNIT-01 · SYSTEM READY", font=fm,
           fill=hexc(P["clock"]), anchor="lm")

    # полоса «опасности» внизу справа
    sw_, sh2 = W * 0.34, 18 * u
    sx, sy = W - m_ - sw_, H - m_ - sh2
    stripe = Image.new("RGBA", (round(sw_), round(sh2)), hexc(P["main"]))
    sd = ImageDraw.Draw(stripe)
    k = 26 * u
    x = -sh2
    while x < sw_ + sh2:
        sd.polygon([(x, sh2), (x + k * 0.5, sh2), (x + k * 0.5 + sh2, 0), (x + sh2, 0)], fill=bgc)
        x += k
    msk = Image.new("L", stripe.size, 0)
    ImageDraw.Draw(msk).rounded_rectangle((0, 0, stripe.width - 1, stripe.height - 1), 4 * u, fill=255)
    img.paste(stripe, (round(sx), round(sy)), msk)
    return img


if args.style == "minimal":
    render = render_minimal


out = pathlib.Path(args.out_dir).expanduser()
out.mkdir(parents=True, exist_ok=True)
blocks = []
for i, mon in enumerate(mons, 1):
    W, H = round(mon["width"] / mon["scale"]), round(mon["height"] / mon["scale"])
    name = mon.get("name", "")
    path = out / f"bg-{args.style}-{name or 'any'}-{W}x{H}-p{pal_n}.png"
    render(W, H, i, name).convert("RGB").save(path)
    print("обои:", path)
    blocks.append((name, path))

# запасные обои для любых других мониторов (например, переносного)
fallback = out / f"bg-{args.style}-any-2560x1440-p{pal_n}.png"
render(2560, 1440, 1, "").convert("RGB").save(fallback)

hp = ("# Обои в стиле экрана блокировки bento-login.\n"
      f"# СГЕНЕРИРОВАНО: {HERE}/gen-wallpaper.py — правьте генератор.\n"
      "splash = false\nipc = true\n\n")
for name, path in blocks:
    hp += f"wallpaper {{\n    monitor = {name}\n    path = {path}\n    fit_mode = cover\n}}\n\n"
hp += f"wallpaper {{\n    monitor =\n    path = {fallback}\n    fit_mode = cover\n}}\n"
pathlib.Path(args.hyprpaper).expanduser().write_text(hp, encoding="utf-8")
print("hyprpaper:", args.hyprpaper)
