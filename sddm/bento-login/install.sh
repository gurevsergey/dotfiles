#!/usr/bin/env bash
# Установка темы bento-login. Запуск: sudo ./install.sh
# sddm НЕ перезапускается — тема применится при следующем входе/перезагрузке.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST=/usr/share/sddm/themes/bento-login
CONF=/etc/sddm.conf.d/theme.conf

[[ $EUID -eq 0 ]] || { echo "нужен root: sudo $0"; exit 1; }

install -d -m 755 "$DEST" "$DEST/components" "$DEST/fonts" "$DEST/translations"
install -m 644 "$SRC"/Main.qml "$SRC"/theme.conf "$SRC"/metadata.desktop "$SRC"/background.png "$DEST"/
[[ -f "$SRC/preview.png" ]] && install -m 644 "$SRC/preview.png" "$DEST"/
install -m 644 "$SRC"/components/*.qml "$DEST/components/"
install -m 644 "$SRC"/fonts/* "$DEST/fonts/"

# сведения о ПК: скрипт + systemd (до старта sddm и раз в 2 мин)
install -m 755 "$SRC/sysinfo/bento-sysinfo.sh" /usr/local/bin/bento-sysinfo.sh
install -m 644 "$SRC/sysinfo/bento-sysinfo.service" "$SRC/sysinfo/bento-sysinfo.timer" /etc/systemd/system/
install -d -m 755 /var/lib/bento-login
systemctl daemon-reload
systemctl enable bento-sysinfo.service bento-sysinfo.timer
systemctl start bento-sysinfo.service bento-sysinfo.timer

install -d -m 755 /etc/sddm.conf.d
if [[ -f "$CONF" ]]; then
    cp -a "$CONF" "$CONF.bak-$(date +%F-%H%M%S)"
fi
cat > "$CONF" <<'EOF'
[Theme]
Current=bento-login
EOF

echo "Тема установлена в $DEST, включена в $CONF"
echo "Проверка: sddm-greeter-qt6 --test-mode --theme $DEST"
