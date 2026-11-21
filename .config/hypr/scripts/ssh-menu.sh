#!/usr/bin/env bash
# SSH-меню (SUPER+X): хосты из ~/.ssh/config → rofi → kitty с ssh на текущем столе.
# Можно ввести и свой адрес: user@10.0.0.1

hosts=$(awk '
    function flush(   i) { for (i = 0; i < n; i++) printf "%-18s %s%s\n", h[i], (user ? user "@" : ""), name; n = 0 }
    tolower($1) == "host" {
        flush(); user = ""; name = ""
        for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) h[n++] = $i
        next
    }
    tolower($1) == "hostname" { name = $2 }
    tolower($1) == "user"     { user = $2 }
    END { flush() }
' ~/.ssh/config 2>/dev/null)

choice=$(printf '%s\n' "$hosts" | rofi -dmenu -i -p "SSH" -mesg "Enter — подключиться · можно ввести user@host")
[ -z "$choice" ] && exit 0
target=${choice%% *}

# target уходит внутрь Lua-строки — пропускаем только безопасные символы
if [[ ! $target =~ ^[A-Za-z0-9@._:-]+$ ]]; then
    notify-send "SSH" "Некорректный адрес: $target"
    exit 1
fi

# Без явного стола окно ушло бы на стол 1 (общее правило default-workspace-lg)
ws=$(hyprctl activeworkspace -j | sed -n 's/^ *"id": \(-\?[0-9]*\),/\1/p' | head -1)
hyprctl dispatch "hl.dsp.exec_cmd(\"kitty --class ssh-term -T 'ssh $target' -e ssh $target\", { workspace = \"$ws\" })" >/dev/null
