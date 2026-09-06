#!/usr/bin/env bash
set -euo pipefail

wifi=off
bluetooth=off
dnd=off
night=off
night_mode=auto

[[ "$(nmcli radio wifi 2>/dev/null || true)" != enabled ]] || wifi=on
bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bluetooth=on || true
dnd=$(python3 ~/.config/hypr/scripts/notification_control.py dnd 2>/dev/null || printf off)
night=$(~/.config/hypr/scripts/hyprsunset-toggle.sh status 2>/dev/null || printf 'off')
night_mode=$(~/.config/hypr/scripts/hyprsunset-toggle.sh mode 2>/dev/null || printf 'auto')

jq -nc --arg wifi "$wifi" --arg bluetooth "$bluetooth" --arg dnd "$dnd" \
    --arg night "$night" --arg night_mode "$night_mode" \
    '{wifi:$wifi,bluetooth:$bluetooth,dnd:$dnd,night:$night,night_mode:$night_mode}'
