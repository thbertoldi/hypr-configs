#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

case "${1:-agenda}" in
    agenda)
        if command -v dcal >/dev/null 2>&1 \
            || { command -v flatpak >/dev/null 2>&1 \
                && flatpak info com.danklinux.dankcalendar >/dev/null 2>&1; }; then
            exec "$script_dir/app-launch.sh" "$script_dir/dcal.sh" show
        fi
        notify-send -a Hyprland -u normal 'Agenda' \
            'DankCalendar não está instalado; usando o Merkuro como fallback.'
        ;&
    merkuro)
        if command -v merkuro-calendar >/dev/null 2>&1; then
            # qt6ct themes Qt Widgets through Kvantum, but its default palette
            # leaves Kirigami/Qt Quick applications light.  The KDE platform
            # plugin makes Merkuro consume the user's dark KDE color scheme.
            exec "$script_dir/app-launch.sh" env QT_QPA_PLATFORMTHEME=kde merkuro-calendar
        fi
        if command -v korganizer >/dev/null 2>&1; then
            notify-send -a Hyprland -u normal 'Agenda' \
                'Merkuro não está instalado; usando o KOrganizer como fallback.'
            exec "$script_dir/app-launch.sh" korganizer
        fi
        notify-send -a Hyprland -u critical 'Agenda indisponível' \
            'Instale o DankCalendar, Merkuro ou KOrganizer.'
        exit 1
        ;;
    classic)
        command -v korganizer >/dev/null 2>&1 || {
            notify-send -a Hyprland -u critical 'Agenda indisponível' \
                'KOrganizer não está instalado.'
            exit 1
        }
        exec "$script_dir/app-launch.sh" korganizer
        ;;
    outlook)
        exec "$script_dir/app-launch.sh" xdg-open https://outlook.live.com/calendar/0/view/month
        ;;
    proton)
        exec "$script_dir/app-launch.sh" xdg-open https://calendar.proton.me
        ;;
    *)
        printf 'uso: %s {agenda|merkuro|classic|outlook|proton}\n' "${0##*/}" >&2
        exit 64
        ;;
esac
