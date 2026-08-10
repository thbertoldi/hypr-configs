#!/usr/bin/env bash
# Outputs JSON for the active MPRIS player's current state.
set -euo pipefail

if ! command -v playerctl >/dev/null; then
    echo '{"status":"Stopped","title":"","artist":"","icon":"⏵"}'
    exit 0
fi

status=$(playerctl status 2>/dev/null || echo "Stopped")
title=$(playerctl metadata title 2>/dev/null || echo "")
artist=$(playerctl metadata artist 2>/dev/null || echo "")
icon=$([ "$status" = "Playing" ] && echo "⏸" || echo "⏵")

jq -nc --arg s "$status" --arg t "$title" --arg a "$artist" --arg i "$icon" \
    '{status:$s, title:$t, artist:$a, icon:$i}'
