#!/usr/bin/env bash
# Waybar custom module: VPN status. JSON output for class-based styling.
# Refreshed every 5s by waybar's interval, or immediately via SIGRTMIN+9.

active=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
    | awk -F: '$2=="vpn"{print $1; exit}')

if [ -n "$active" ]; then
    # Shorten "SUSE-UDP-NUE-NM_setting" → "UDP-NUE"
    short="${active#SUSE-}"
    short="${short%-NM_setting}"
    printf '{"text":"  %s","tooltip":"VPN: %s","class":"on","alt":"on"}\n' \
        "$short" "$active"
else
    printf '{"text":"","tooltip":"VPN: off","class":"off","alt":"off"}\n'
fi
