#!/usr/bin/env bash
# Собирает сведения о ПК для темы SDDM bento-login.
# Пишет QML-файл со словарём info: { "CPU": "...", ... }.
# В theme.conf значения подставляются как %CPU%, %GPU% и т.д.
# Запуск: bento-sysinfo.sh [выходной_файл]   (по умолчанию /var/lib/bento-login/SysInfo.qml)
set -uo pipefail
export LC_ALL=C

OUT=${1:-/var/lib/bento-login/SysInfo.qml}
declare -A I

# ── Система ──────────────────────────────────────────────────────────
I[HOST]=$(hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || uname -n)
I[OS]=$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}" )
I[KERNEL]=$(uname -r)
I[KERNEL_SHORT]=${I[KERNEL]%%-*}
I[PKGS]=$(pacman -Qq 2>/dev/null | wc -l)

# ── CPU ──────────────────────────────────────────────────────────────
cpu=$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo)
cpu=$(sed -E 's/\((R|TM)\)//g; s/ (CPU|Processor)//g; s/ [0-9]+-Core//; s/^(AMD|Intel) //; s/ +/ /g; s/ @.*//' <<<"$cpu")
I[CPU]=$cpu
threads=$(nproc --all)
cores=$(lscpu -p=core 2>/dev/null | grep -v '^#' | sort -u | wc -l)
I[CORES]="${cores}C/${threads}T"

# ── GPU (без nvidia-smi: он ломается при рассинхроне модуля и библиотеки) ──
gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller' | head -1)
if [[ $gpu =~ \[([^]]+)\][^[]*$ ]]; then gpu=${BASH_REMATCH[1]}; else gpu=${gpu##*: }; fi
I[GPU]=$gpu
I[GPU_SHORT]=$(sed -E 's/^(GeForce|Radeon|Intel) //' <<<"$gpu")
if [[ -r /proc/driver/nvidia/version ]]; then
    I[GPU_DRV]=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' /proc/driver/nvidia/version | head -1)
else
    I[GPU_DRV]=$(basename "$(readlink -f /sys/class/drm/card*/device/driver 2>/dev/null | head -1)")
fi

# ── Память и диск ────────────────────────────────────────────────────
I[RAM]=$(awk '/^MemTotal/{printf "%d GB", ($2/1048576)+0.5}' /proc/meminfo)
read -r dsize davail <<<"$(df -h --output=size,avail / | tail -1)"
I[DISK]="$davail free / $dsize"
I[DISK_FREE]=$davail

# ── Сеть (локальный адрес интерфейса маршрута по умолчанию) ──────────
route=$(ip -4 route get 1.1.1.1 2>/dev/null | head -1)
I[IP]=$(grep -oP 'src \K[0-9.]+' <<<"$route" || true)
I[IFACE]=$(grep -oP 'dev \K\S+' <<<"$route" || true)
[[ -n ${I[IP]} ]] || I[IP]="offline"

# ── Загрузка и последний вход ────────────────────────────────────────
I[BOOT_EPOCH]=$(awk '/^btime/{print $2}' /proc/stat)
I[BOOT_TIME]=$(date -d "@${I[BOOT_EPOCH]}" +%H:%M)
last_line=$(last -n 30 --time-format iso 2>/dev/null | awk '$1!="reboot" && $1!="wtmp" && NF>2 {print; exit}')
if [[ -n $last_line ]]; then
    I[LAST_USER]=$(awk '{print $1}' <<<"$last_line")
    ts=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+[+-][0-9:]+' <<<"$last_line" | head -1)
    I[LAST_LOGIN]=$(date -d "$ts" +%d%b\ %H:%M | tr '[:lower:]' '[:upper:]')
else
    I[LAST_USER]="—"; I[LAST_LOGIN]="—"
fi

I[UPDATED]=$(date +%H:%M)

# ── Запись QML (атомарно) ────────────────────────────────────────────
esc() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "${s//$'\n'/ }"; }
mkdir -p "$(dirname "$OUT")"
tmp=$(mktemp "$OUT.XXXXXX")
{
    echo "// Сгенерировано bento-sysinfo.sh $(date -Is). Не редактировать вручную."
    echo "import QtQuick"
    echo "Item {"
    echo "    visible: false"
    echo "    readonly property var info: ({"
    for k in $(printf '%s\n' "${!I[@]}" | sort); do
        printf '        "%s": "%s",\n' "$k" "$(esc "${I[$k]}")"
    done
    echo "    })"
    echo "}"
} >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$OUT"
