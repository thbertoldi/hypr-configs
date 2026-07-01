#!/usr/bin/env bash
# Toggle VPN: if any vpn-type connection is active, bring all of them down.
# Otherwise fuzzel-pick from configured vpn profiles and bring one up.
# Auth dialog comes from nm-applet (needs NetworkManager-applet-openvpn).

set -eu

notify() { command -v notify-send >/dev/null && notify-send -a vpn "$1" "${2:-}" || true; }
refresh_bar() { pkill -RTMIN+9 waybar 2>/dev/null || true; }

active=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="vpn"{print $1}')

if [ -n "$active" ]; then
    while IFS= read -r name; do
        if nmcli connection down "$name" >/dev/null 2>&1; then
            notify "VPN disconnected" "$name"
        else
            notify "Disconnect failed" "$name"
        fi
    done <<<"$active"
    refresh_bar
    exit 0
fi

mapfile -t profiles < <(
    nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="vpn"{print $1}'
)
if [ ${#profiles[@]} -eq 0 ]; then
    notify "No VPN profiles configured"
    exit 1
fi

choice=$(printf "%s\n" "${profiles[@]}" \
    | fuzzel --dmenu --prompt="VPN  " --lines=8 --width=42)
[ -z "${choice:-}" ] && exit 0

if nmcli connection up "$choice" >/dev/null 2>&1; then
    notify "VPN connected" "$choice"
else
    notify "VPN failed" "$choice"
fi
refresh_bar
