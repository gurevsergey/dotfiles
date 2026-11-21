#!/usr/bin/env bash
# Bluetooth-меню (SUPER+ALT+B, ЛКМ по значку Bluetooth в waybar):
# сопряжённые устройства — Enter подключает/отключает; поиск и сопряжение новых;
# забыть устройство; вкл/выкл адаптер. PIN-коды, если нужны, спросит blueman-applet.

ROFI=(rofi -dmenu -i -p "Bluetooth")
note() { notify-send -a Bluetooth -i bluetooth "$1" "${2:-}"; }

powered() { bluetoothctl show | grep -q "Powered: yes"; }

info_field() { sed -n "s/^\s*$2: //p" <<<"$1" | head -1; }

# одна строка меню на устройство: "<значок> Имя  · подключено · 🔋80%\tMAC"
device_line() {
    local mac=$1 info name icon conn bat line
    info=$(bluetoothctl info "$mac")
    name=$(info_field "$info" Alias)
    icon=$(info_field "$info" Icon)
    conn=$(info_field "$info" Connected)
    bat=$(sed -n 's/^\s*Battery Percentage: .*(\([0-9]*\)).*/\1/p' <<<"$info")
    case $icon in
        audio-headset|audio-headphones) glyph="󰋋" ;;
        audio-card|audio-speakers)      glyph="󰓃" ;;
        input-gaming)                   glyph="󰊴" ;;
        input-mouse)                    glyph="󰍽" ;;
        input-keyboard)                 glyph="󰌌" ;;
        phone)                          glyph="󰏲" ;;
        *)                              glyph="󰂯" ;;
    esac
    line="$glyph  $name"
    if [[ $(info_field "$info" Paired) != yes ]]; then
        line+="   ·  не сопряжено — Enter: сопрячь"
    elif [[ $conn == yes ]]; then
        line+="   · подключено"
    fi
    [[ -n $bat ]] && line+="  · 󰁹 $bat%"
    printf '%s\t%s\n' "$line" "$mac"
}

pick() {   # stdin: "текст\tзначение" → печатает значение выбранной строки
    local menu choice
    menu=$(cat)
    choice=$(cut -f1 <<<"$menu" | "${ROFI[@]}" "$@") || return 1
    grep -F -m1 "$choice"$'\t' <<<"$menu" | cut -f2
}

# Pair через D-Bus, а не bluetoothctl pair: тогда код/PIN показывает агент
# blueman-applet (окно), а не прячется в выводе bluetoothctl.
# Работает и для устройства, которое уже подключилось без сопряжения
# (клавиатура в таком состоянии на связи, но не печатает).
pair_device() {
    local mac=$1 name path out rc
    name=$(info_field "$(bluetoothctl info "$mac")" Alias)
    note "Сопряжение…" "$name — если появится код, наберите его на устройстве и нажмите Enter"
    pgrep -x blueman-applet >/dev/null || { blueman-applet >/dev/null 2>&1 & sleep 2; }
    path="/org/bluez/hci0/dev_${mac//:/_}"
    out=$(gdbus call --system --dest org.bluez --object-path "$path" \
          --method org.bluez.Device1.Pair --timeout 60 2>&1); rc=$?
    if [[ $rc -eq 0 || $out == *AlreadyExists* ]]; then
        bluetoothctl trust "$mac" >/dev/null
        bluetoothctl connect "$mac" >/dev/null
        note "Готово" "$name сопряжено и будет подключаться само"
    else
        note "Сопряжение не удалось" "$name: ${out##*: }"
    fi
}

toggle_device() {
    local mac=$1 name
    name=$(info_field "$(bluetoothctl info "$mac")" Alias)
    if ! bluetoothctl info "$mac" | grep -q "Paired: yes"; then
        pair_device "$mac"
    elif bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        bluetoothctl disconnect "$mac" >/dev/null && note "Отключено" "$name"
    else
        note "Подключение…" "$name"
        if bluetoothctl connect "$mac" | grep -q "Connection successful"; then
            note "Подключено" "$name"
        else
            note "Не удалось подключить" "$name — включено ли устройство?"
        fi
    fi
}

scan_and_pair() {
    note "Поиск устройств…" "8 секунд — переведите устройство в режим сопряжения"
    bluetoothctl --timeout 8 scan on >/dev/null
    local paired list mac name
    paired=$(bluetoothctl devices Paired | awk '{print $2}')
    list=$(bluetoothctl devices | while read -r _ mac name; do
        grep -qx "$mac" <<<"$paired" && continue
        # безымянные (только MAC) — обычно чужие маяки, прячем
        [[ $name == "${mac//:/-}" || -z $name ]] && continue
        printf '󰂰  %s   (%s)\t%s\n' "$name" "$mac" "$mac"
    done)
    if [[ -z $list ]]; then
        note "Ничего не найдено" "Устройство в режиме сопряжения? Попробуйте ещё раз"
        return
    fi
    mac=$(pick -p "Сопряжение" <<<"$list") || return
    pair_device "$mac"
}

forget_device() {
    local list mac
    list=$(bluetoothctl devices Paired | while read -r _ mac _; do device_line "$mac"; done)
    [[ -z $list ]] && { note "Нет сопряжённых устройств"; return; }
    mac=$(pick -p "Забыть" <<<"$list") || return
    bluetoothctl remove "$mac" >/dev/null && note "Устройство удалено"
}

# ── главное меню ──
if ! powered; then
    act=$(printf '󰂯  Включить Bluetooth\ton\n󰂲  Открыть Blueman\tblueman\n' | pick) || exit 0
    case $act in
        on)      bluetoothctl power on >/dev/null && sleep 1 && exec "$0" ;;
        blueman) exec blueman-manager ;;
    esac
    exit 0
fi

menu=$(
    # сопряжённые + подключённые/доверенные без сопряжения (их нужно сопрячь)
    { bluetoothctl devices Paired; bluetoothctl devices Connected; bluetoothctl devices Trusted; } \
        | awk '!seen[$2]++ {print $2}' | while read -r mac; do device_line "$mac"; done | sort -t$'\t' -k1,1
    printf '󰐕  Найти и подключить новое…\tscan\n'
    printf '󰆴  Забыть устройство…\tforget\n'
    printf '󰂲  Выключить Bluetooth\toff\n'
    printf '󰒓  Открыть Blueman\tblueman\n'
)
act=$(pick -mesg "Enter — подключить / отключить" <<<"$menu") || exit 0

case $act in
    scan)    scan_and_pair ;;
    forget)  forget_device ;;
    off)     bluetoothctl power off >/dev/null && note "Bluetooth выключен" ;;
    blueman) exec blueman-manager ;;
    *:*)     toggle_device "$act" ;;
esac
