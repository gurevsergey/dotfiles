#!/usr/bin/env bash
# Запись экрана (SUPER+SHIFT+R): первое нажатие — выделить область и начать,
# второе — остановить. Файл в ~/Videos/Записи, ссылка на него — в буфере обмена.

dir=~/Videos/Записи
state=${XDG_RUNTIME_DIR:-/tmp}/record-current

if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder
    while pgrep -x wf-recorder >/dev/null; do sleep 0.1; done
    file=$(cat "$state" 2>/dev/null)
    rm -f "$state"
    pkill -RTMIN+8 waybar
    if [ -n "$file" ]; then
        printf 'file://%s\n' "$file" | wl-copy -t text/uri-list
        notify-send "Запись сохранена" "$file\nФайл в буфере — можно вставить в чат"
    fi
    exit 0
fi

command -v wf-recorder >/dev/null || { notify-send "Запись" "Не установлен wf-recorder"; exit 1; }
geometry=$(slurp -d) || exit 0   # Esc — отмена
mkdir -p "$dir"
file="$dir/$(date +%F_%H-%M-%S).mp4"
echo "$file" > "$state"
wf-recorder -g "$geometry" -f "$file" >/dev/null 2>&1 &
sleep 0.3
pkill -RTMIN+8 waybar
notify-send "Идёт запись" "SUPER+SHIFT+R — остановить"
