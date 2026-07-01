#!/usr/bin/env bash
# fuzzel-based wifi picker for waybar / keybinds.
# Left side of each row: status glyph + ssid; right side: signal + security.
# Selecting "Scan again" rescans; selecting a connected network disconnects it.

set -eu

notify() { command -v notify-send >/dev/null && notify-send -a wifi "$1" "${2:-}" || true; }

# Trigger a rescan in the background so subsequent calls see fresh APs.
nmcli device wifi rescan >/dev/null 2>&1 &

mapfile -t lines < <(
    nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list \
    | awk -F: '
        $2 == "" { next }            # skip hidden SSIDs
        {
            inuse = ($1 == "*") ? "" : ""
            sec   = ($4 == "" || $4 == "--") ? "" : ""
            printf "%s  %-32s  %3s%%  %s\n", inuse, $2, $3, sec
        }' \
    | awk '!seen[$0]++'
)

lines+=("  Scan again")
lines+=("  Open connection editor")

choice=$(printf "%s\n" "${lines[@]}" | fuzzel --dmenu --prompt="wifi  " --lines=12 --width=42)
[ -z "${choice:-}" ] && exit 0

case "$choice" in
    *"Scan again"*)
        nmcli device wifi rescan
        exec "$0"
        ;;
    *"Open connection editor"*)
        exec nm-connection-editor
        ;;
esac

ssid=$(awk '{
    # ssid is field starting at column 4 (after status glyph + two spaces); trim
    s=""; for (i=2; i<=NF-2; i++) s = s (s ? " " : "") $i; print s
}' <<<"$choice")
ssid="${ssid#"${ssid%%[![:space:]]*}"}"
ssid="${ssid%"${ssid##*[![:space:]]}"}"
[ -z "$ssid" ] && exit 0

# If selected network is already active, disconnect it.
active=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v s="$ssid" '$1==s {print $2; exit}')
if [ -n "$active" ]; then
    nmcli connection down id "$ssid" >/dev/null && notify "Disconnected" "$ssid"
    exit 0
fi

# Already-known network?  Just bring it up.
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
    if nmcli connection up id "$ssid" >/dev/null 2>&1; then
        notify "Connected" "$ssid"
    else
        notify "Failed to connect" "$ssid"
    fi
    exit 0
fi

# New network — prompt for password via fuzzel password mode.
pw=$(fuzzel --dmenu --password --prompt="password for $ssid  " --lines=0 --width=42 < /dev/null || true)
if [ -z "${pw:-}" ]; then
    # Try open network
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        notify "Connected" "$ssid"
    else
        notify "Failed to connect" "$ssid (password required?)"
    fi
else
    if nmcli device wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
        notify "Connected" "$ssid"
    else
        notify "Failed to connect" "$ssid (bad password?)"
    fi
fi
