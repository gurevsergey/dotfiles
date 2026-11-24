#!/usr/bin/env bash
# Тёмная тема Breeze Dark для KDE/Qt-приложений (Dolphin и др.)
set -e
# bento Unit-01 (как waybar); если схемы нет — Breeze Dark
src=$HOME/.local/share/color-schemes/BentoUnit01.colors
[ -f "$src" ] || src=/usr/share/color-schemes/BreezeDark.colors
[ -f "$src" ] || { echo "Нет $src — установите пакет breeze"; exit 1; }

{
    cat "$src"
    printf '\n[General]\nColorScheme=%s\n' "$(basename "$src" .colors)"
    printf '\n[Icons]\nTheme=breeze-dark\n'
    printf '\n[KDE]\nwidgetStyle=Breeze\n'
} > ~/.config/kdeglobals

echo "kdeglobals: $(basename "$src" .colors)"
