#!/usr/bin/env bash
# Пакеты для окружения Hyprland + Waybar
set -e
sudo pacman -S --needed --noconfirm \
    waybar ttf-jetbrains-mono-nerd otf-font-awesome \
    rofi swaync hyprlock hypridle hyprpaper \
    pavucontrol brightnessctl playerctl \
    network-manager-applet blueman \
    wl-clipboard cliphist libnotify \
    breeze plasma-integration gnome-themes-extra
