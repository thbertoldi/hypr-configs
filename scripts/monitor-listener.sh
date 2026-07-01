#!/usr/bin/env bash
# Live dock/undock switching for the laptop panel.
# Reconciles once at startup, then reacts to Hyprland monitor add/remove events
# so plugging or unplugging an external display flips eDP-1 instantly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECONCILE="$SCRIPT_DIR/monitor-autoswitch.sh"

# Initial reconcile (handles booting either docked or undocked).
"$RECONCILE"

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*)
            "$RECONCILE"
            ;;
    esac
done
