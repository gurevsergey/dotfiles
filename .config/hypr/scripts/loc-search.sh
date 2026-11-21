#!/usr/bin/env bash
# Где подключено устройство (SUPER+SHIFT+I): MAC или IP → ~/skripts/loc.py →
# таблица в плавающем окне. Если в буфере обмена MAC/IP — он уже подставлен,
# достаточно Enter. Можно передать цель аргументом: loc-search.sh 10.0.0.1

LOC=~/skripts/loc.py
LOG=~/.cache/loc-search.log
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
is_target() { [[ $1 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){0,3}\.?$ || $1 =~ ^[0-9A-Fa-f]{2}([-:.]?[0-9A-Fa-f]{2}){1,5}$ ]]; }

target=$1
if [ -z "$target" ]; then
    clip=$(wl-paste --no-newline 2>/dev/null | head -c 64 | tr -d '[:space:]')
    is_target "$clip" || clip=""
    target=$(printf '%s' "$clip" | rofi -dmenu -p "loc")
fi
# MAC, набранный в русской раскладке: фисвуа → abcdef, ю → . , ж → :
target=$(printf '%s' "$target" | tr -d '[:space:]' | sed 'y/фисвуаФИСВУАюЮжЖ/abcdefABCDEF..::/')
log "input=[$target] args=[$*]"
[ -z "$target" ] && exit 0

# target уходит в shell-строку внутри kitty — пропускаем только безопасные символы
if [[ ! $target =~ ^[0-9A-Za-z.:-]+$ ]]; then
    log "rejected [$target]"
    rofi -e "loc: некорректный ввод «$target» — нужен MAC или IP"
    exit 1
fi

if [ "$2" = "--show" ]; then
    exec kitty --class loc-result -T "loc $target" -e bash -c "
        python3 $LOC '$target' --style box
        while read -rsn1 k; do [[ \$k == q || \$k == \$'\\e' ]] && break; done
    "
fi

# Через Hyprland с явным столом: иначе окно уйдёт на стол 1 (правило default-workspace-lg)
ws=$(hyprctl activeworkspace -j | sed -n 's/^ *"id": \(-\?[0-9]*\),/\1/p' | head -1)
out=$(hyprctl dispatch "hl.dsp.exec_cmd(\"$0 $target --show\", { workspace = \"$ws\" })" 2>&1)
log "dispatch ws=$ws -> $out"
