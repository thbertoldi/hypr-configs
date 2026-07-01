#!/usr/bin/env bash
# Enable the laptop panel (eDP-1) only when no external monitor is connected.
#   Docked   (any non-eDP-1 output present) -> laptop off.
#   Undocked (eDP-1 is the only output)      -> laptop on at native res.
# Detection is name-agnostic: anything that isn't eDP-1 counts as "external",
# so it works whether the dock connects via DP-1, HDMI-A-1, etc.
# Idempotent -- safe to run repeatedly.
set -euo pipefail

external=$(hyprctl monitors all -j | jq -r '.[].name' | grep -vx 'eDP-1' || true)

if [ -n "$external" ]; then
    hyprctl keyword monitor "eDP-1, disable"
else
    hyprctl keyword monitor "eDP-1, preferred, auto, 1"
fi
