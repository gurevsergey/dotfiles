#!/usr/bin/env python3
"""Тема Telegram Desktop в стиле bento (как waybar/kitty/hyprlock).

База — официальная ночная тема Telegram (telegram/night-base.colors, все ключи).
Алгоритм: серо-синие оттенки -> нейтральные тёплые серые, синие акценты -> янтарь,
затем точные цвета bento для главных элементов (OVERRIDES).
Фон чата — сетка точек, как на обоях.

Результат: telegram/bento.tdesktop-theme — открыть файл в Telegram (или
отправить себе в «Избранное» и нажать) -> «Применить тему».
"""
import colorsys, io, re, zipfile
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent / "telegram"
BASE = HERE / "night-base.colors"
OUT = HERE / "bento.tdesktop-theme"

# Палитра bento (waybar/style.css, kitty.conf)
CANVAS, SURFACE, BORDER = "#0b0b0b", "#1a1a1a", "#262626"
INK, TEXT, MUTED, SUBTLE = "#0b0b0b", "#e8e0d0", "#a8a8a8", "#6a6a6a"
AMBER, AMBER_HI, AMBER_DIM = "#e0a060", "#f0bb85", "#b07a42"
RED, RED_DEEP, GREEN, YELLOW = "#e0544a", "#c8312b", "#8cc086", "#e8c547"
PANEL = "#121212"           # фон списка чатов / окон — между canvas и surface
PANEL_OVER = "#1f1f1f"
OUT_BUBBLE = "#3d2c19"      # исходящее сообщение — тёмный янтарь
IN_BUBBLE = "#1c1c1c"

AMBER_HUE = 30 / 360


def parse(c):
    c = c.lstrip("#")
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return r, g, b, c[6:8]


def fmt(r, g, b, a=""):
    return "#" + "".join(f"{round(max(0, min(1, x)) * 255):02x}" for x in (r, g, b)) + a


def remap(c):
    r, g, b, a = parse(c)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    deg = h * 360
    if (r, g, b) in ((1, 1, 1), (0, 0, 0)):
        return c.lower()
    if s < 0.30 or (180 <= deg <= 235 and l < 0.30 and s < 0.45):
        # серо-синие фоны/тексты -> нейтральные, слегка тёплые
        if l < 0.5:
            l2, s2 = l * 0.72, 0.0
        else:
            l2, s2 = l, 0.12
        return fmt(*colorsys.hls_to_rgb(AMBER_HUE, l2, s2), a)
    if 180 <= deg <= 240:
        # синие акценты -> янтарь
        if l < 0.40:
            l2, s2 = l * 0.85, s * 0.55
        else:
            l2, s2 = l, min(s, 0.75)
        return fmt(*colorsys.hls_to_rgb(AMBER_HUE, l2, s2), a)
    return c.lower()


OVERRIDES = {
    # основа
    "windowBg": PANEL, "windowFg": TEXT, "windowBgOver": PANEL_OVER, "windowBgRipple": BORDER,
    "windowFgOver": TEXT, "windowSubTextFg": SUBTLE, "windowSubTextFgOver": MUTED,
    "windowBoldFg": TEXT, "windowBoldFgOver": TEXT,
    "windowBgActive": AMBER, "windowFgActive": INK, "windowActiveTextFg": AMBER,
    "windowShadowFgFallback": PANEL,
    # кнопки: янтарь с тёмным текстом, как активный воркспейс в waybar
    "activeButtonBg": AMBER, "activeButtonBgOver": AMBER_HI, "activeButtonBgRipple": AMBER_DIM,
    "activeButtonFg": INK, "activeButtonFgOver": INK, "activeButtonSecondaryFg": "#3a2a18",
    "activeLineFg": AMBER, "activeLineFgError": RED,
    "lightButtonBg": PANEL, "lightButtonFg": AMBER, "lightButtonBgOver": "#1f1a14",
    "lightButtonBgRipple": "#2a2118",
    "attentionButtonFg": RED, "attentionButtonFgOver": RED,
    "outlineButtonOutlineFg": AMBER,
    "menuBg": SURFACE, "menuBgOver": BORDER, "menuBgRipple": "#2e2e2e",
    "menuIconFg": MUTED, "menuIconFgOver": TEXT, "menuSeparatorFg": BORDER,
    "inputBorderFg": BORDER, "placeholderFg": SUBTLE,
    "boxBg": SURFACE, "boxDividerBg": CANVAS, "titleBg": CANVAS, "titleBgActive": CANVAS,
    "titleFg": SUBTLE, "titleFgActive": MUTED,
    "checkboxFg": SUBTLE,
    # список чатов
    "dialogsBg": PANEL, "dialogsBgOver": PANEL_OVER, "dialogsRippleBg": BORDER,
    "dialogsNameFg": TEXT, "dialogsTextFg": SUBTLE, "dialogsTextFgService": MUTED,
    "dialogsDateFg": SUBTLE, "dialogsDraftFg": RED,
    "dialogsBgActive": AMBER, "dialogsRippleBgActive": AMBER_DIM,
    "dialogsDraftFgActive": "#5a2a10", "dialogsUnreadBgMutedActive": "#7a5a38",
    "dialogsUnreadFgActive": AMBER, "dialogsSendingIconFgActive": "#0b0b0b99",
    "dialogsOnlineBadgeFgActive": INK,
    "dialogsUnreadBg": AMBER, "dialogsUnreadBgOver": AMBER, "dialogsUnreadFg": INK,
    "dialogsUnreadBgMuted": "#3a3a3a", "dialogsUnreadBgMutedOver": "#444444",
    "dialogsSentIconFg": AMBER, "dialogsVerifiedIconBg": AMBER, "dialogsVerifiedIconFg": INK,
    "dialogsMenuIconFg": MUTED, "dialogsMenuIconFgOver": TEXT,
    "dialogsOnlineBadgeFg": GREEN,
    "sideBarBg": CANVAS, "sideBarBgActive": SURFACE, "sideBarTextFg": SUBTLE,
    "sideBarTextFgActive": AMBER, "sideBarIconFg": SUBTLE, "sideBarIconFgActive": AMBER,
    "sideBarBadgeBg": AMBER, "sideBarBadgeBgMuted": "#3a3a3a", "sideBarBadgeFg": INK,
    "searchedBarBg": SURFACE, "searchedBarFg": MUTED,
    # переписка
    "historyComposeAreaBg": PANEL, "historyComposeAreaFg": TEXT,
    "historyComposeAreaFgService": SUBTLE, "historyComposeIconFg": SUBTLE,
    "historyComposeIconFgOver": AMBER, "historySendIconFg": AMBER, "historySendIconFgOver": AMBER_HI,
    "historyComposeButtonBg": PANEL, "historyComposeButtonBgOver": PANEL_OVER,
    "historyReplyBg": PANEL, "historyPinnedBg": PANEL,
    "historyReplyIconFg": AMBER, "historyToDownBg": SURFACE, "historyToDownBgOver": BORDER,
    "historyUnreadBarBg": SURFACE, "historyUnreadBarBorder": AMBER, "historyUnreadBarFg": AMBER,
    "historyForwardChooseBg": "#000000a0", "historyForwardChooseFg": TEXT,
    "historyPeerUserpicFg": "#ffffff",
    "historyTextInFg": TEXT, "historyTextOutFg": TEXT,
    "historyLinkInFg": AMBER, "historyLinkOutFg": AMBER_HI,
    "historyOutIconFg": AMBER, "historyIconFgInverted": AMBER,
    "msgInBg": IN_BUBBLE, "msgOutBg": OUT_BUBBLE,
    "msgInBgSelected": "#4a3620",
    "msgOutBgSelected": "#5a4024",
    "msgInShadow": "#00000000", "msgOutShadow": "#00000000",
    "msgInDateFg": SUBTLE, "msgOutDateFg": "#9a8268",
    "msgInServiceFg": AMBER, "msgOutServiceFg": AMBER_HI,
    "msgInReplyBarColor": AMBER, "msgOutReplyBarColor": AMBER_HI,
    "msgServiceBg": "#1a1a1acc", "msgServiceFg": MUTED, "msgServiceBgSelected": "#4a3620",
    "msgInMonoFg": "#e8c547", "msgOutMonoFg": "#f2d873",
    "msgWaveformInActive": AMBER, "msgWaveformOutActive": AMBER_HI,
    "msgWaveformInInactive": "#3a3a3a", "msgWaveformOutInactive": "#5a4630",
    "msgFileInBg": AMBER, "msgFileOutBg": AMBER, "msgFileInBgOver": AMBER_HI,
    "msgFileOutBgOver": AMBER_HI, "historyFileInIconFg": INK, "historyFileOutIconFg": INK,
    "historyFileInRadialFg": INK, "historyFileOutRadialFg": INK,
    # прочее
    "emojiPanBg": SURFACE, "emojiPanCategories": CANVAS,
    "scrollBarBg": "#ffffff30", "scrollBarBgOver": "#ffffff55",
    "scrollBg": "#ffffff0a", "scrollBgOver": "#ffffff18",
    "searchedTextMatchBg": AMBER, "searchedTextMatchFg": INK,
    "searchedTextCurrentMatchBg": YELLOW, "searchedTextCurrentMatchFg": INK,
    "currencyFg": AMBER, "botKbPrimaryBg": "#e0a060cc",
    "botKbDangerBg": "#e0544acc", "botKbSuccessBg": "#6fa06acc",
    "groupCallActiveFg": AMBER, "groupCallMuted1": "#c8862f", "groupCallMuted2": AMBER_HI,
    "groupCallMemberInactiveStatus": AMBER,
    "outdatedBg": RED_DEEP, "spellUnderline": "#e0544a88",
    "callBgOpaque": CANVAS, "groupCallBg": CANVAS,
    # ссылались на windowFgActive (теперь тёмный), но лежат на тёмном/красном фоне
    "radialFg": "#ffffff", "titleButtonCloseFgOver": "#ffffff", "stickerPanDeleteFg": "#ffffff",
    "youtubePlayIconFg": "#ffffff", "toastFg": TEXT, "mediaviewMenuFg": "#ffffff",
    "mediaviewControlFg": "#ffffff",
    "mainMenuCoverBg": AMBER, "mainMenuCoverFg": INK,
    # единый цвет панелей вокруг чата, поле поиска, диалоги
    "topBarBg": PANEL,
    "filterInputInactiveBg": SURFACE, "filterInputActiveBg": SURFACE, "filterInputBorderFg": AMBER,
    "boxSearchBg": SURFACE, "contactsBg": SURFACE, "contactsBgOver": BORDER,
    "tooltipBg": SURFACE, "tooltipBorderFg": BORDER,
    "titleButtonBgActive": CANVAS, "titleButtonCloseBgActive": CANVAS,
    "botKbBg": SURFACE, "historyComposeButtonBgRipple": BORDER,
    "mediaviewBg": "#0b0b0beb",
}


def dots_png(step=32, bg=CANVAS, dot="#1e1e1e"):
    img = Image.new("RGB", (step * 4, step * 4), bg)
    d = ImageDraw.Draw(img)
    for y in range(step // 2, step * 4, step):
        for x in range(step // 2, step * 4, step):
            d.rectangle([x, y, x + 1, y + 1], fill=dot)
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def main():
    lines, seen = [], set()
    for line in BASE.read_text().splitlines():
        m = re.match(r"^(\w+)\s*:\s*([^;]+);(.*)$", line)
        if not m:
            lines.append(line)
            continue
        key, val, rest = m.group(1), m.group(2).strip(), m.group(3)
        seen.add(key)
        if key in OVERRIDES:
            val = OVERRIDES[key]
        elif val.startswith("#"):
            val = remap(val)
        lines.append(f"{key}: {val};{rest}")
    extra = [k for k in OVERRIDES if k not in seen]
    if extra:
        lines.append("\n// bento: ключи, которых нет в ночной базе")
        lines += [f"{k}: {OVERRIDES[k]};" for k in extra]
    colors = "\n".join(lines) + "\n"
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("colors.tdesktop-theme", colors)
        z.writestr("tiled.png", dots_png())
    (HERE / "bento.colors").write_text(colors)
    print(OUT, f"({len(seen)} ключей базы, {len(extra)} добавлено)")


if __name__ == "__main__":
    main()
