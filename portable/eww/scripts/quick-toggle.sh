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
        python3 ~/.config/hypr/scripts/notification_control.py dnd-toggle
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
