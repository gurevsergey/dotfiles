#!/usr/bin/env bash
# Меню питания через rofi
lock="󰌾  Заблокировать"
suspend="󰤄  Сон"
logout="󰍃  Выйти"
reboot="󰜉  Перезагрузка"
shutdown="⏻  Выключить"

choice=$(printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$shutdown" |
    rofi -dmenu -i -p "Питание" -theme-str 'window {width: 320px;} listview {lines: 5;}')

confirm() {
    [ "$(printf '%s\n' "󰄬  Да" "󰅖  Нет" |
        rofi -dmenu -i -no-custom -p "$1?" -theme-str 'window {width: 320px;} listview {lines: 2;}')" = "󰄬  Да" ]
}

case "$choice" in
    "$lock")     loginctl lock-session ;;
    "$suspend")  systemctl suspend ;;
    "$logout")   command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
    "$reboot")   confirm "Перезагрузить" && systemctl reboot ;;
    "$shutdown") confirm "Выключить" && systemctl poweroff ;;
esac
