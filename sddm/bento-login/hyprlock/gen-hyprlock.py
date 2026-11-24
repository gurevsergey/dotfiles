#!/usr/bin/env python3
"""Генерирует экран блокировки hyprlock в стиле SDDM-темы bento-login.

Статичное (карточки, рамки, заголовок, арт, иероглифы) рисуется в PNG-фон,
живое (часы, дата, HMSD, сеть, характеристики, поле пароля) — виджеты hyprlock.

  gen-hyprlock.py [--palette N] [--size 2560x1440] [--conf ~/.config/hypr/hyprlock.conf]

Блок auth { pam { module = ... } } переносится из текущего hyprlock.conf.
"""
import argparse
import configparser
import getpass
import json
import os
import pathlib
import re
import shlex
import shutil
import socket
import subprocess
import time

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
THEME = HERE.parent
HOME = pathlib.Path.home()

# ── аргументы ─────────────────────────────────────────────────────────
ap = argparse.ArgumentParser()
ap.add_argument("--palette", type=int, default=0, help="номер палитры из theme.conf (0 = defaultPalette)")
ap.add_argument("--size", default="auto", help="WxH логического экрана, auto = самый большой монитор")
ap.add_argument("--out-dir", default=str(HOME / ".config/hypr/bento-lock"))
ap.add_argument("--conf", default=str(HOME / ".config/hypr/hyprlock.conf"))
ap.add_argument("--tz", default="Europe/Moscow", help="часовой пояс часов")
ap.add_argument("--extra-tz", default="HK=Asia/Hong_Kong", help="второй пояс в карточке часов, пусто = нет")
ap.add_argument("--title", default=None, help="заголовок (по умолчанию title из theme.conf)")
args = ap.parse_args()

# ── theme.conf ────────────────────────────────────────────────────────
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
title = args.title or conf("title", "EVANGELION")
if "%" in title:
    title = re.sub(r"%[A-Z_]+%", socket.gethostname().upper(), title)
quote = "Identity verified at the edge. Every session is a negotiation between the machine and whoever remembers the password."

# ── размер экрана ─────────────────────────────────────────────────────
if args.size == "auto":
    try:
        mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)
        m = max(mons, key=lambda m: m["width"] * m["height"] / m["scale"] ** 2)
        W, H = round(m["width"] / m["scale"]), round(m["height"] / m["scale"])
    except Exception:
        W, H = 2560, 1440
else:
    W, H = map(int, args.size.lower().split("x"))

# ── шрифты ────────────────────────────────────────────────────────────
FD = THEME / "fonts"
F_DISPLAY = FD / "ArchivoBlack-Regular.ttf"
F_SANS = FD / "SpaceGrotesk.ttf"
F_MONO_B = FD / "JetBrainsMonoNerdFontMono-Bold.ttf"
F_CJK = pathlib.Path("/usr/share/fonts/TTF/IBMPlexSansJP-Bold.ttf")
# запятая в конце: иначе Pango читает «Black» как вес и берёт другой шрифт
FAM_DISPLAY, FAM_SANS, FAM_MONO = "Archivo Black,", "Space Grotesk,", "JetBrainsMono Nerd Font Mono,"

# hyprlock берёт шрифты из fontconfig — ставим свои в ~/.local/share/fonts
user_fonts = HOME / ".local/share/fonts/bento-login"
user_fonts.mkdir(parents=True, exist_ok=True)
changed = False
for f in (F_DISPLAY, F_SANS):
    dst = user_fonts / f.name
    if not dst.exists() or dst.stat().st_size != f.stat().st_size:
        shutil.copy2(f, dst)
        changed = True
if changed:
    subprocess.run(["fc-cache", "-f", str(user_fonts)], check=False)


def font(path, px, variation=None):
    f = ImageFont.truetype(str(path), max(1, round(px)))
    if variation:
        try:
            f.set_variation_by_name(variation)
        except Exception:
            pass
    return f


# ── геометрия (как в Main.qml) ────────────────────────────────────────
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


def hexc(c, a=255):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def rgba(c, a="ff"):
    return f"rgba({c.lstrip('#')}{a})"


img = Image.new("RGBA", (W, H), hexc(P["background"]))
d = ImageDraw.Draw(img)


def card(box, color):
    x, y, w, h = box
    d.rounded_rectangle((x, y, x + w, y + h), R, fill=hexc(color))


def frame(x, y, w, h, bw, color, r=0):
    d.rounded_rectangle((x, y, x + w, y + h), r, outline=hexc(color), width=max(1, round(bw)))


def text(x, y, s, f, color, anchor="la", **kw):
    d.multiline_text((x, y), s, font=f, fill=hexc(color), anchor=anchor, **kw) if "\n" in s else \
        d.text((x, y), s, font=f, fill=hexc(color), anchor=anchor)


# ── Карточка 1: арт ───────────────────────────────────────────────────
ax, ay, aw, ah = map(round, ART)
art = Image.new("RGBA", (aw, ah), hexc(P["art"]))
bgp = THEME / conf("background", "background.png")
if bgp.exists():
    src = Image.open(bgp).convert("RGBA")
    k = max(aw / src.width, ah / src.height)
    src = src.resize((round(src.width * k), round(src.height * k)), Image.LANCZOS)
    src = src.crop(((src.width - aw) // 2, (src.height - ah) // 2, (src.width - aw) // 2 + aw, (src.height - ah) // 2 + ah))
    art.alpha_composite(src)
ad = ImageDraw.Draw(art)
ad.text((22 * u, 20 * u), conf("artIndex", "01"), font=font(F_DISPLAY, 26 * u), fill=hexc(P["ink"]))
glyphs = list(conf("artGlyphs", "独創"))
gs = 118 * u
if F_CJK.exists():
    fc = font(F_CJK, gs)
    for i, ch in enumerate(glyphs):
        ad.text((24 * u, ah - 18 * u - (len(glyphs) - 1 - i) * gs * 1.02), ch, font=fc, fill=hexc(P["ink"]), anchor="ld")
mask = Image.new("L", (aw, ah), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, aw - 1, ah - 1), R, fill=255)
img.paste(art, (ax, ay), mask)

# ── Карточка 2: главная ───────────────────────────────────────────────
card(MAIN, P["main"])
mx, my, mw, mh = MAIN
pad = 34 * u
ft = font(F_DISPLAY, 78 * u)
text(mx + pad, my + 22 * u + 0.12 * 78 * u, title, ft, P["ink"])
tw = d.textlength(title, font=ft)
dot = 13 * u
dx, dy = mx + pad + tw + 10 * u, my + 38 * u
d.ellipse((dx, dy, dx + dot, dy + dot), fill=hexc(P["accent"]))
# стрелка ↗
s = 86 * u
axx, ayy = mx + mw - pad - s, my + pad
d.polygon([(axx + s * .30, ayy), (axx + s, ayy), (axx + s, ayy + s * .70)], fill=hexc(P["ink"]))
d.line([(axx + s * .06, ayy + s * .94), (axx + s * .70, ayy + s * .30)], fill=hexc(P["ink"]), width=round(s * .16))

midH = 262 * u
title_bottom = my + 22 * u + 78 * u * 1.19
date_px = 44 * u
date_top = my + mh - 26 * u - date_px * 1.19
midY = max(title_bottom + 12 * u, (title_bottom + date_top) / 2 - midH / 2)

# HMSD: рамка и буквы (столбики — живой виджет)
bx, bw_ = mx + pad, 156 * u
frame(bx, midY, bw_, midH, 3 * u, P["ink"])
fl = font(F_DISPLAY, 15 * u)
for i, ch in enumerate("HMSD"):
    cx = bx + 12 * u + i * 36 * u + 12 * u
    text(cx, midY + midH - 14 * u, ch, fl, P["ink"], anchor="ms")
bars_center = (bx + bw_ / 2, midY + 8 * u + (midH - 44 * u) / 2)

# панель входа
px_ = bx + bw_ + 22 * u
pw = min(640 * u, mw * 0.46)
frame(px_, midY, pw, midH, 3 * u, P["ink"])
hh = 42 * u
d.rectangle((px_, midY + hh - 2 * u, px_ + pw, midY + hh), fill=hexc(P["ink"]))
fm = font(F_MONO_B, 14 * u)
text(px_ + 20 * u, midY + hh / 2, socket.gethostname(), fm, P["ink"], anchor="lm")
text(px_ + pw - 20 * u, midY + hh / 2, conf("authLabel", "AUTH"), fm, P["ink"], anchor="rm")
fieldX, fieldH = 130 * u, 46 * u
fw = pw - fieldX - 20 * u
uy = midY + hh + (midH - hh - 2 * fieldH - 24 * u) / 2
py = uy + fieldH + 24 * u
fs = font(F_MONO_B, 12 * u)
text(px_ + 20 * u, uy + fieldH / 2, conf("userLabel", "USER"), fs, P["ink"], anchor="lm")
text(px_ + 20 * u, py + fieldH / 2, conf("passLabel", "PASSKEY"), fs, P["ink"], anchor="lm")
frame(px_ + fieldX, uy, fw, fieldH, 2 * u, P["ink"], 3 * u)
text(px_ + fieldX + 16 * u, uy + fieldH / 2, getpass.getuser().upper(), font(F_MONO_B, 21 * u), P["ink"], anchor="lm")
PASS = (px_ + fieldX, py, fw, fieldH)
desc_left = px_ + pw + 40 * u
mid_center_y = midY + midH / 2

# ── Карточка 3: сессия ────────────────────────────────────────────────
card(SESS, P["session"])
sx, sy, sw, sh = SESS
fx, fy, fw3, fh3 = sx + 20 * u, sy + 20 * u, sw - 40 * u, sh - 40 * u
frame(fx, fy, fw3, fh3, 1.5 * u, P["ink"], 10 * u)
ip = 22 * u
hint_bottom = fy + fh3 - ip
fhint = font(F_MONO_B, 11 * u)
hint = "TOUCH YUBIKEY\nOR ENTER PASSKEY"
text(fx + ip, hint_bottom, hint, fhint, P["ink"], anchor="ld", spacing=round(4 * u))
hint_h = d.multiline_textbbox((0, 0), hint, font=fhint, spacing=round(4 * u))[3]
rule_y = hint_bottom - hint_h - 14 * u
d.rectangle((fx + ip, rule_y, fx + fw3 - ip, rule_y + max(1, 1.5 * u)), fill=hexc(P["ink"]))
fname = font(F_DISPLAY, 44 * u)
text(fx + ip, rule_y - 12 * u, "HYPRLAND", fname, P["ink"], anchor="ld")
text(fx + fw3 - ip, rule_y - 14 * u, conf("sessionTag", "DE"), font(F_DISPLAY, 26 * u), P["ink"], anchor="rd")
text(fx + ip, rule_y - 12 * u - 44 * u * 1.05, "SESSION LOCKED", font(F_MONO_B, 11 * u), P["ink"], anchor="ld")

# ── Карточка 4: часы ──────────────────────────────────────────────────
card(CLK, P["clock"])
cx_, cy_, cw_, ch_ = CLK
ls = 44 * u
lx, ly = cx_ + cw_ - 30 * u - ls, cy_ + 28 * u
ink = hexc(P["ink"])
d.polygon([(lx, ly), (lx + ls * .42, ly), (lx + ls * .42, ly + ls * .55), (lx, ly + ls)], fill=ink)
d.polygon([(lx + ls * .58, ly), (lx + ls, ly), (lx + ls * .58, ly + ls * .45)], fill=ink)
d.polygon([(lx + ls, ly + ls * .22), (lx + ls, ly + ls), (lx + ls * .30, ly + ls)], fill=ink)
clock_px = min(ch_ * 0.58, cw_ * 0.30)

# точки палитры (декор)
n = int(conf("paletteCount", "1"))
if n > 1:
    dw = 9 * u
    pillw = n * dw + (n - 1) * 8 * u + 20 * u
    pcx, pcy = rightX + rightW / 2, H - m_
    d.rounded_rectangle((pcx - pillw / 2, pcy - 11 * u, pcx + pillw / 2, pcy + 11 * u), 11 * u, fill=(0, 0, 0, 140))
    for i in range(n):
        x0 = pcx - pillw / 2 + 10 * u + i * (dw + 8 * u)
        d.ellipse((x0, pcy - dw / 2, x0 + dw, pcy + dw / 2), fill=(255, 255, 255, 255) if i == pal_n - 1 else (106, 106, 106, 255))

# ── запись фона и env ────────────────────────────────────────────────
out = pathlib.Path(args.out_dir).expanduser()
out.mkdir(parents=True, exist_ok=True)
bg_path = out / f"bg-{W}x{H}-p{pal_n}.png"
img.convert("RGB").save(bg_path)
shutil.copy2(HERE / "lock-info.sh", out / "lock-info.sh")
os.chmod(out / "lock-info.sh", 0o755)
(out / "env.sh").write_text(
    "# сгенерировано gen-hyprlock.py\n"
    f"INK={shlex.quote(P['ink'])}\nACCENT={shlex.quote(P['accent'])}\n"
    f"LOCK_TZ={shlex.quote(args.tz)}\nLOCK_EXTRA_TZ={shlex.quote(args.extra_tz)}\n"
    f"LOCK_QUOTE={shlex.quote(quote)}\n", encoding="utf-8")
INFO = str(out / "lock-info.sh")

# ── hyprlock.conf ────────────────────────────────────────────────────
PT = 0.75  # hyprlock font_size в пунктах (96 dpi): px * 0.75


def pos(anchor, x, y):
    """Привязать угол виджета (anchor: l/c/r + t/c/b) к точке (x, y) от левого верхнего угла."""
    hv, vv = anchor[0], anchor[1]
    halign = {"l": "left", "c": "center", "r": "right"}[hv]
    valign = {"t": "top", "c": "center", "b": "bottom"}[vv]
    ox = {"l": x, "c": x - W / 2, "r": x - W}[hv]
    oy = {"t": -y, "c": H / 2 - y, "b": H - y}[vv]
    return f"    position = {round(ox)}, {round(oy)}\n    halign = {halign}\n    valign = {valign}\n"


def label(cmd, update, fam, px, color, anchor, x, y, align="left", z=5):
    src = f"cmd[update:{update}] {INFO} {cmd}" if cmd else None
    return ("label {\n    monitor =\n"
            f"    text = {src}\n"
            f"    font_family = {fam}\n    font_size = {round(px * PT)}\n    color = {rgba(color)}\n"
            f"    text_align = {align}\n" + pos(anchor, x, y) + f"    zindex = {z}\n}}\n\n")


old = pathlib.Path(args.conf).expanduser()
auth = 'auth {\n    pam {\n        module = hyprlock\n    }\n}\n'
if old.exists():
    mm = re.search(r"(#[^\n]*\n)?auth\s*\{(?:[^{}]|\{[^{}]*\})*\}", old.read_text(encoding="utf-8"))
    if mm:
        auth = mm.group(0) + "\n"

pxx, pyy, pww, phh = PASS
btn_h = fieldH - 12 * u
btn_w = btn_h * 1.25
cfg = f"""# hyprlock в стиле SDDM-темы bento-login.
# СГЕНЕРИРОВАНО {time.strftime('%Y-%m-%d %H:%M')}: {THEME}/hyprlock/gen-hyprlock.py
# Палитра {pal_n}, экран {W}x{H}. Править генератор, а не этот файл.

general {{
    hide_cursor = true
    immediate_render = true
}}

background {{
    monitor =
    path = {bg_path}
    blur_passes = 0
    color = {rgba(P['background'])}
}}

input-field {{
    monitor =
    size = {round(pww)}, {round(phh)}
    outline_thickness = {max(2, round(2 * u))}
    rounding = {round(3 * u)}
    outer_color = {rgba(P['ink'])}
    inner_color = {rgba(P['main'])}
    font_color = {rgba(P['ink'])}
    font_family = {FAM_MONO}
    check_color = {rgba(P['ink'])}
    fail_color = {rgba(P['accent'])}
    capslock_color = {rgba(P['accent'])}
    fail_text = <b>ACCESS DENIED · $ATTEMPTS</b>
    fade_on_empty = false
    placeholder_text =
    dots_size = 0.28
    dots_spacing = 0.35
    dots_center = false
    dots_rounding = -1
{pos('lt', pxx, pyy)}    zindex = 1
}}

# кнопка ▶ поверх поля
shape {{
    monitor =
    size = {round(btn_w)}, {round(btn_h)}
    color = {rgba(P['ink'])}
    rounding = {round(2 * u)}
{pos('rt', pxx + pww - 6 * u, pyy + 6 * u)}    zindex = 10
}}

label {{
    monitor =
    text = ▶
    font_family = {FAM_MONO}
    font_size = {round(14 * u * PT)}
    color = {rgba(P['main'])}
{pos('cc', pxx + pww - 6 * u - btn_w / 2, pyy + fieldH / 2)}    zindex = 11
}}

"""
# живые виджеты
cfg += label("bars", 1000, FAM_MONO, 20 * u, P["ink"], "cc", *bars_center, align="center")
cfg += label("net", 60000, FAM_MONO, 14 * u, P["ink"], "cc", px_ + pw / 2, midY + hh / 2)
cfg += label("specs", 60000, FAM_MONO, 13 * u, P["ink"], "lc", desc_left, mid_center_y)
cfg += label("date", 60000, FAM_DISPLAY, date_px, P["ink"], "lb", mx + pad, my + mh - 26 * u)
cfg += ("label {\n    monitor =\n    text = <b>$LAYOUT</b>\n"
        f"    font_family = {FAM_MONO}\n    font_size = {round(14 * u * PT)}\n    color = {rgba(P['ink'])}\n"
        + pos("rb", mx + mw - pad, my + mh - 30 * u) + "    zindex = 5\n}\n\n")
cfg += label("art", 3600000, FAM_MONO, 10 * u, P["ink"], "rt", ax + aw - 22 * u, ay + 22 * u, align="right")
cfg += label("day", 60000, FAM_MONO, 13 * u, P["ink"], "lt", fx + ip, fy + ip)
cfg += label("lockedat", 86400000, FAM_MONO, 11 * u, P["ink"], "rb", fx + fw3 - ip, hint_bottom, align="right")
cfg += label("uptime", 10000, FAM_SANS, 26 * u, P["ink"], "lt", cx_ + 30 * u, cy_ + 26 * u)
cfg += label("clock", 1000, FAM_DISPLAY, clock_px, P["ink"], "lb", cx_ + 22 * u, cy_ + ch_ - 4 * u)
cfg += ("" if auth.lstrip().startswith("#") else "# Разблокировка (перенесено из старого конфига)\n") + auth

old_text = old.read_text(encoding="utf-8") if old.exists() else ""
if old.exists() and "СГЕНЕРИРОВАНО" not in old_text:
    bak = old.with_name(old.name + time.strftime(".bak-%Y%m%d-%H%M%S"))
    shutil.copy2(old, bak)
    print("бэкап:", bak)
old.write_text(cfg, encoding="utf-8")
print("фон:", bg_path)
print("конфиг:", old)
