#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    wifi)
        if [[ "$(nmcli radio wifi)" == enabled ]]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        ;;
    bluetooth)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            bluetoothctl power off
        else
            bluetoothctl power on
        fi
        ;;
    dnd)
        if makoctl mode | grep -q 'do-not-disturb'; then
            makoctl mode -r do-not-disturb
        else
            makoctl mode -a do-not-disturb
        fi
        ;;
    night)
        ~/.config/hypr/scripts/hyprsunset-toggle.sh toggle
        ;;
    night-auto)
        ~/.config/hypr/scripts/hyprsunset-toggle.sh auto
        ;;
    *)
        printf 'uso: %s {wifi|bluetooth|dnd|night|night-auto}\n' "${0##*/}" >&2
        exit 64
        ;;
esac

eww poll quick >/dev/null 2>&1 || true
