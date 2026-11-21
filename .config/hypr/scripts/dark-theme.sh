#!/usr/bin/env bash
# Тёмная тема Breeze Dark для KDE/Qt-приложений (Dolphin и др.)
set -e
src=/usr/share/color-schemes/BreezeDark.colors
[ -f "$src" ] || { echo "Нет $src — установите пакет breeze"; exit 1; }

{
    cat "$src"
    printf '\n[General]\nColorScheme=BreezeDark\n'
    printf '\n[Icons]\nTheme=breeze-dark\n'
    printf '\n[KDE]\nwidgetStyle=Breeze\n'
} > ~/.config/kdeglobals

echo "kdeglobals: Breeze Dark"
