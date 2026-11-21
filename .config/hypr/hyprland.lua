-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--            HYPRLAND CONFIG (WinBox 4)          --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Старый конфиг: hyprland.lua.bak-2026-09-29


------------------
---- MONITORS ----
------------------

-- Десктоп (Ryzen 7950X + RTX 5080), два MSI MAG321QR 2560x1440 @ 165 Гц.
-- Мониторы заданы по описанию (модель + серийный номер), а не по имени выхода:
-- после перехода nouveau → nvidia или пересадки кабеля DP-1/DP-2 могут поменяться.
local MAIN = "desc:Microstep MSI MAG321QR DB9A242802641"   -- левый, основной
local SIDE = "desc:Microstep MSI MAG321QR DB9A242801725"   -- правый

-- Любой другой монитор: максимальная частота обновления, справа от остальных
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1,
})

hl.monitor({
    output   = MAIN,
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = SIDE,
    mode     = "2560x1440@165",
    position = "2560x0",
    scale    = 1,
})

-- ARZOPA: highrr выбирает 1024x768@75 вместо полного разрешения.
hl.monitor({
    output   = "desc:GWD ARZOPA 0000002089130",
    mode     = "2560x1600@60",
    position = "5120x0",
    scale    = 2,
})

-- Раскладка (по задачам, чтобы реже переключаться):
--   Левый:  1 Сеть (WinBox, NetBox)   2 Работа (Firefox + kitty)   3 Код (VS Code)
--           4 Мониторинг (Grafana)    5 Заметки (Obsidian)
--   Правый: 6 Чат (Mattermost + Bitrix24) — всегда на виду
--           7 Доп. стол (пустой, под что угодно)
--   Поверх любого стола: SUPER+B Bitwarden, SUPER+Y Яндекс Музыка (scratchpad)
hl.workspace_rule({
    workspace  = "1",
    monitor    = MAIN,
    default    = true,
    persistent = true,
})

for _, ws in ipairs({ "2", "3", "4", "5" }) do
    hl.workspace_rule({
        workspace  = ws,
        monitor    = MAIN,
        persistent = true,
    })
end

hl.workspace_rule({
    workspace  = "6",
    monitor    = SIDE,
    default    = true,
    persistent = true,
})

hl.workspace_rule({
    workspace  = "7",
    monitor    = SIDE,
    persistent = true,
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    -- WinBox 4 uses the compositor's solid background; no wallpaper daemon needed.
    hl.exec_cmd("waybar")
    hl.exec_cmd("systemctl --user start swaync.service")  -- через unit, чтобы не дублировать D-Bus-активацию
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Программы на своих столах (silent — не переключаться на них при входе)
    hl.exec_cmd("$HOME/.local/opt/winbox/WinBox", { workspace = "1 silent" })
    hl.exec_cmd("$HOME/.local/opt/winbox/WinBox", { workspace = "1 silent" })
    hl.exec_cmd("firefoxpwa site launch 01M3VNEX18YTZZNKAQ2XKJ6033", { workspace = "1 silent" })
    hl.exec_cmd("firefox",                        { workspace = "2 silent" })
    hl.exec_cmd(terminal .. " --class kitty-main", { workspace = "2 silent" })
    hl.exec_cmd("code",                           { workspace = "3 silent" })
    hl.exec_cmd("firefoxpwa site launch 01M3VNPW59ZGA5VBGYHR1Q0Z1B", { workspace = "4 silent" })
    hl.exec_cmd("obsidian",                       { workspace = "5 silent" })
    hl.exec_cmd("mattermost-desktop",             { workspace = "6 silent" })
    hl.exec_cmd("firefoxpwa site launch 01M5KX789A235CSVNA8WJBVQKG", { workspace = "6 silent" })  -- Bitrix24
    hl.exec_cmd("bitwarden-desktop",              { workspace = "special:bitwarden silent" })

end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")          -- тёмная тема Breeze для Dolphin и Qt
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
-- GTK_THEME не задаём: тема GTK3 (adw-gtk3-dark) берётся из gsettings, а GTK4/libadwaita с этой переменной ломается
hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")     -- VS Code, Obsidian, Mattermost, Bitwarden — нативно в Wayland

-- NVIDIA (RTX 5080, драйвер nvidia-open) — только когда драйвер реально загружен,
-- иначе на nouveau эти переменные ломают OpenGL/видео
local nv = io and io.open("/proc/driver/nvidia/version")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")          -- аппаратное декодирование видео (libva-nvidia-driver)
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Палитра WinBox 4
local c = {
    amber   = "rgba(62b0e8ff)",
    muted   = "rgba(82919dff)",
    teal    = "rgba(62b0e8ff)",
    surface = "rgba(3b4853ff)",
}

hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 6,

        border_size = 1,

        col = {
            active_border   = c.teal,
            inactive_border = c.surface,
        },

        resize_on_border = true,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 3,
        rounding_power = 2.5,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        dim_inactive = false,
        dim_strength = 0.06,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = "rgba(0e1318cc)",
            color_inactive = "rgba(0e131877)",
            offset       = { 0, 4 },
        },

        blur = {
            enabled   = false,
            size      = 8,
            passes    = 2,
            noise     = 0.02,
            contrast  = 1.0,
            brightness = 0.9,
            vibrancy  = 0.2,
            popups    = true,
            special   = true,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 2,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 1.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle",   enabled = false })  -- вращение градиента перерисовывало экраны каждый кадр
hl.animation({ leaf = "windows",       enabled = true,  speed = 1.8, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 1.6,  bezier = "easeOutQuint",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 1.2, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 1.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 1.5,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.5,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.5,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.5,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.5,  bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 2,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
        background_color = "rgb(262e35)",
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/waybar/scripts/powermenu.sh"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("$HOME/.local/opt/winbox/WinBox"))
-- Инструкция: less, а если его нет — more (оба закрываются клавишей q)
local guide = "kitty --class guide -e sh -c 'f=~/.config/hypr/ИНСТРУКЦИЯ.md; command -v less >/dev/null && exec less -R \"$f\" || exec more \"$f\"'"

local function focusOrLaunch(class, cmd)
    return function()
        local win = hl.get_windows({ class = class })[1]
        if win then
            hl.dispatch(hl.dsp.focus({ window = win }))
        else
            hl.dispatch(hl.dsp.exec_cmd(cmd))
        end
    end
end

-- Scratchpad-программа: показать/спрятать поверх текущего стола, запустить если не открыта
local function toggleScratch(special, class, cmd)
    return function()
        local win = hl.get_windows({ class = class })[1]
        if not win then
            hl.dispatch(hl.dsp.exec_cmd(cmd))
        elseif win.workspace and win.workspace.name ~= "special:" .. special then
            -- окно оказалось на обычном столе (перенесли/открылось мимо правила) — вернуть в свой слой
            hl.dispatch(hl.dsp.window.move({ workspace = "special:" .. special, follow = false, window = win }))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(special))
    end
end

hl.bind(mainMod .. " + B", toggleScratch("bitwarden", "Bitwarden", "bitwarden-desktop"))
hl.bind(mainMod .. " + Y", toggleScratch("music", "YandexMusic", "/opt/yandex-music/yandexmusic --gtk-version=3"))
hl.bind(mainMod .. " + U", toggleScratch("spotify", "spotify", "spotify"))
hl.bind(mainMod .. " + grave", toggleScratch("dropterm", "kitty-drop", terminal .. " --class kitty-drop"))
hl.bind(mainMod .. " + ESCAPE", toggleScratch("dropterm", "kitty-drop", terminal .. " --class kitty-drop"))  -- 65%-клавиатура: ` только через Fn
hl.bind(mainMod .. " + T", focusOrLaunch("mattermost-desktop", "mattermost-desktop"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.config/hypr/scripts/windows.py"))          -- все окна по столам
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.config/hypr/scripts/ssh-menu.sh"))            -- SSH-хосты
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/bt-menu.sh"))        -- Bluetooth-меню
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("~/.config/hypr/scripts/netbox-search.py"))       -- поиск: NetBox + loc.py
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/record.sh"))      -- запись экрана: старт/стоп
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -display-columns 2 -p 'Буфер' | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("pkill -x waybar; while pgrep -x waybar >/dev/null; do sleep 0.1; done; waybar"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(guide))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(guide))  -- нет F-ряда

-- Скриншоты: область -> буфер, весь экран -> ~/Pictures
hl.bind("Print",           hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy && notify-send 'Скриншот' 'Область скопирована'"))
hl.bind("SHIFT + Print",   hl.dsp.exec_cmd("mkdir -p ~/Pictures && grim ~/Pictures/$(date +%F_%H-%M-%S).png && notify-send 'Скриншот' 'Сохранён в ~/Pictures'"))
-- Для 65%-клавиатуры (нет Print): область — SUPER+SHIFT+S ниже, весь экран — SUPER+CTRL+S
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures && grim ~/Pictures/$(date +%F_%H-%M-%S).png && notify-send 'Скриншот' 'Сохранён в ~/Pictures'"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (SUPER+SHIFT+S занят скриншотом)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Звук (PulseAudio), яркость
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"),      { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                 { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                 { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Плавающие окна для настроек (сеть, звук, bluetooth)
hl.window_rule({
    name  = "float-settings",
    match = { class = "^(guide|pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|nmtui|polkit-kde-authentication-agent-1)$" },

    float  = true,
    size   = "900 600",
    center = true,
})

-- Любое новое окно без своего правила ниже — на LG (стол 1), даже если
-- фокус был на ноутбуке. Правило должно стоять раньше точечных ниже:
-- Hyprland применяет правила по порядку, и более позднее совпадающее
-- правило переопределяет workspace, так что именные правила ниже
-- по-прежнему отправляют свои окна на столы 2-6.
hl.window_rule({ name = "default-workspace-lg", match = { class = ".*" }, workspace = "1" })

-- Программы на своих рабочих столах
hl.window_rule({ name = "ws-winbox",     match = { class = "(?i)^winbox" },          workspace = "1" })
hl.window_rule({ name = "ws-firefox",    match = { class = "^firefox$" },             workspace = "2" })
hl.window_rule({ name = "ws-kitty-main", match = { class = "^kitty-main$" },          workspace = "2" })
hl.window_rule({ name = "ws-netbox",     match = { class = "^FFPWA-01M3VNEX18YTZZNKAQ2XKJ6033$" }, workspace = "1" })
hl.window_rule({ name = "ws-vscode",     match = { class = "(?i)^(code|com\\.microsoft\\.vscode)$" }, workspace = "3" })
hl.window_rule({ name = "ws-grafana",    match = { class = "^FFPWA-01M3VNPW59ZGA5VBGYHR1Q0Z1B$" }, workspace = "4" })
hl.window_rule({ name = "ws-obsidian",   match = { class = "^md\\.obsidian\\.Obsidian$" },         workspace = "5" })
hl.window_rule({ name = "ws-mattermost", match = { class = "^mattermost-desktop$" }, workspace = "6" })
hl.window_rule({ name = "ws-bitrix24",   match = { class = "^FFPWA-01M5KX789A235CSVNA8WJBVQKG$" }, workspace = "6" })

-- Scratchpad-окна: плавают по центру поверх текущего стола (SUPER+B / SUPER+Y / SUPER+U)
hl.window_rule({ name = "sp-bitwarden", match = { class = "^Bitwarden$" },   workspace = "special:bitwarden silent", float = true, size = "1200 900", center = true })
hl.window_rule({ name = "sp-dropterm",  match = { class = "^kitty-drop$" },  workspace = "special:dropterm silent",  float = true, size = "monitor_w*0.6 monitor_h*0.45", move = "monitor_w*0.2 60" })
hl.window_rule({ name = "loc-result",   match = { class = "^loc-result$" },  float = true, size = "monitor_w*0.7 monitor_h*0.7", center = true })
hl.window_rule({ name = "sp-music",     match = { class = "^YandexMusic$" }, workspace = "special:music silent",     float = true, size = "1400 900", center = true })
hl.window_rule({ name = "sp-spotify",   match = { class = "^spotify$" },     workspace = "special:spotify silent",   float = true, size = "1400 900", center = true })

-- Размытие под панелью, меню и уведомлениями
hl.layer_rule({ name = "blur-waybar", match = { namespace = "^waybar$" },           blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-rofi",   match = { namespace = "^rofi$" },             blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-swaync", match = { namespace = "^swaync-.*$" },        blur = true, ignore_alpha = 0.2 })

-- Монитор процессов: Ctrl+Shift+Esc
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty -e htop --sort-key=PERCENT_CPU"))
