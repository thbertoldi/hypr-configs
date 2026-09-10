#!/usr/bin/env bash
# Live dock/undock switching for the laptop panel.
# Reconciles once at startup, then reacts to monitor and configuration events.
# The reconciler allows a short HDMI wake-up gap before enabling eDP-1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECONCILE="$SCRIPT_DIR/monitor-autoswitch.sh"

# Initial reconcile (handles booting either docked or undocked).
"$RECONCILE" || printf 'Display reconciliation failed; waiting for the next event.\n' >&2

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*|configreloaded*)
            "$RECONCILE" || printf 'Display reconciliation failed; waiting for the next event.\n' >&2
            ;;
    esac
done
