#!/usr/bin/env bash
# Enter на экране входа SDDM «не работал»: pam_u2f стоял первым (sufficient) и
# молча ждал касания YubiKey ~30 с, пароль в это время не проверялся.
# Делаем как у hyprlock: сначала пароль, при пустом/неверном — касание ключа.
# Запуск: sudo bash pam/fix-enter-u2f.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "нужен root"; exit 1; }
BK=/var/backups/pam-yubikey-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BK"; cp -a /etc/pam.d/sddm /etc/pam.d/hyprlock-u2f "$BK"/
U2F='pam_u2f.so           cue pinverification=0 authfile=/etc/u2f_mappings origin=pam://archlinux appid=pam://archlinux'

cat > /etc/pam.d/sddm <<PAM
#%PAM-1.0
# Пароль ИЛИ касание YubiKey. Верный пароль — вход сразу; пустое поле + Enter — касание ключа.
auth       required                    pam_shells.so
auth       requisite                   pam_nologin.so
auth       required                    pam_faillock.so      preauth
auth       [success=2 conv_err=die default=ignore]  pam_unix.so  try_first_pass nullok
auth       [success=1 default=ignore]  $U2F
auth       [default=die]               pam_faillock.so      authfail
auth       required                    pam_faillock.so      authsucc
auth       required                    pam_env.so
-auth      optional                    pam_gnome_keyring.so
-auth      optional                    pam_kwallet5.so

account    include                     system-login

password   include                     system-login
-password  optional                    pam_gnome_keyring.so    use_authtok

session    optional                    pam_keyinit.so          force revoke
session    include                     system-login
-session   optional                    pam_gnome_keyring.so    auto_start
-session   optional                    pam_kwallet5.so         auto_start
PAM

# hyprlock: оборванный диалог не должен уходить в ожидание ключа (зависание hyprlock)
sed -i 's/^auth       \[success=2 default=ignore\]  pam_unix.so/auth       [success=2 conv_err=die default=ignore]  pam_unix.so/' /etc/pam.d/hyprlock-u2f

# тема с подсказкой TOUCH KEY
install -m 644 "$(dirname "$0")/../components/LoginCard.qml" /usr/share/sddm/themes/bento-login/components/

faillock --user sgurev --reset
echo "Готово. Бэкап: $BK"
grep -n pam_unix /etc/pam.d/sddm /etc/pam.d/hyprlock-u2f
