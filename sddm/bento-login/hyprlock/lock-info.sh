#!/usr/bin/env bash
# Живые надписи для hyprlock в стиле bento-login.
# Вызывается из hyprlock.conf: text = cmd[update:N] lock-info.sh <что>
# Цвета и часовой пояс — в env.sh рядом (его пишет gen-hyprlock.py).
DIR=$(dirname "$(readlink -f "$0")")
# shellcheck source=/dev/null
. "$DIR/env.sh"
export LC_ALL=C TZ=${LOCK_TZ:-UTC}

up() { tr '[:lower:]' '[:upper:]'; }

case ${1:-} in
clock)   # ЧЧММ: часы чернилами, минуты акцентом
    printf '<span foreground="%s">%s</span><span foreground="%s">%s</span>' \
        "$INK" "$(date +%H)" "$ACCENT" "$(date +%M)" ;;
date)    # #24NOV26
    printf '#%s' "$(date +%d%b%y | up)" ;;
day)     # TUESDAY / 24 NOVEMBER 2026
    date +'%A%n%-d %B %Y' | up ;;
bars)    # Столбики H M S D из блоков, 7 уровней
    rows=7
    h=$(date +%-H); m=$(date +%-M); s=$(date +%-S); d=$(date +%-d)
    dim=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d)
    vals=("$((h * 1000 / 23))" "$((m * 1000 / 59))" "$((s * 1000 / 59))" "$((d * 1000 / dim))")
    for ((r = rows; r >= 1; r--)); do
        line=""
        for v in "${vals[@]}"; do
            if ((v * rows >= r * 1000 - 500)); then
                line+="<span foreground=\"$ACCENT\">██</span> "
            else
                line+="<span foreground=\"$INK\" alpha=\"18%\">██</span> "
            fi
        done
        printf '%s\n' "${line% }"
    done ;;
net)     # eno1 · 192.168.1.10
    r=$(ip -4 route get 1.1.1.1 2>/dev/null | head -1)
    ipaddr=$(grep -oP 'src \K[0-9.]+' <<<"$r"); dev=$(grep -oP 'dev \K\S+' <<<"$r")
    [[ -n $ipaddr ]] && printf '%s · %s' "$dev" "$ipaddr" || printf 'offline' ;;
art)     # Arch Linux / kernel 7.3.4
    . /etc/os-release; k=$(uname -r)
    printf '%s\nkernel %s' "${PRETTY_NAME:-Linux}" "${k%%-*}" ;;
specs)   # CPU / GPU / RAM / DISK / PKGS
    cpu=$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo \
        | sed -E 's/\((R|TM)\)//g; s/ (CPU|Processor)//g; s/ [0-9]+-Core//; s/^(AMD|Intel) //; s/ +/ /g; s/ @.*//')
    cores=$(lscpu -p=core 2>/dev/null | grep -v '^#' | sort -u | wc -l)
    gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller' | head -1)
    [[ $gpu =~ \[([^]]+)\][^[]*$ ]] && gpu=${BASH_REMATCH[1]}
    gpu=$(sed -E 's/^(GeForce|Radeon|Intel) //' <<<"$gpu")
    drv=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' /proc/driver/nvidia/version 2>/dev/null | head -1)
    ram=$(awk '/^MemTotal/{printf "%d GB", ($2/1048576)+0.5}' /proc/meminfo)
    read -r size avail <<<"$(df -h --output=size,avail / | tail -1)"
    pk=$(pacman -Qq 2>/dev/null | wc -l)
    printf 'CPU   %s · %sC/%sT\nGPU   %s%s\nRAM   %s\nDISK  %s free / %s\nPKGS  %s\n\n%s' \
        "$cpu" "$cores" "$(nproc --all)" "$gpu" "${drv:+ · $drv}" "$ram" "$avail" "$size" "$pk" "$(fold -s -w 46 <<<"$LOCK_QUOTE" | sed 's/ *$//')" ;;
uptime)  # Uptime 1h 08m / HK 04:24
    sec=$(cut -d. -f1 /proc/uptime)
    dd=$((sec / 86400)); hh=$((sec % 86400 / 3600)); mm=$((sec % 3600 / 60))
    if ((dd > 0)); then u="${dd}d ${hh}h"; elif ((hh > 0)); then u=$(printf '%dh %02dm' $hh $mm); else u="${mm}m"; fi
    printf 'Uptime %s' "$u"
    if [[ -n ${LOCK_EXTRA_TZ:-} ]]; then
        printf '\n%s %s' "${LOCK_EXTRA_TZ%%=*}" "$(TZ=${LOCK_EXTRA_TZ#*=} date +%H:%M)"
    fi ;;
lockedat) # время блокировки (выполняется один раз при запуске hyprlock)
    printf 'LOCKED AT\n%s' "$(date +'%H:%M')" ;;
*)
    echo "usage: $0 clock|date|day|bars|net|art|specs|uptime|lockedat" >&2; exit 1 ;;
esac
