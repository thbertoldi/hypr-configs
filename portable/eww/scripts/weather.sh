#!/usr/bin/env bash
# Poll wttr.in every 30 minutes and cache the response.
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-weather.json"
TTL=1800
CITY="${EWW_WEATHER_CITY:-}"
mkdir -p "$(dirname "$CACHE")"

now=$(date +%s)
if [ -f "$CACHE" ]; then
    age=$(( now - $(stat -c %Y "$CACHE") ))
    if [ "$age" -lt "$TTL" ]; then
        cat "$CACHE"
        exit 0
    fi
fi

raw=$(curl -sS --max-time 4 "https://wttr.in/${CITY}?format=j1" 2>/dev/null || true)
if [ -z "$raw" ]; then
    if [ -f "$CACHE" ]; then cat "$CACHE"; else echo '{"icon":"?","temp":"--","desc":"offline","city":"?"}'; fi
    exit 0
fi

icon=$(jq -r '.current_condition[0].weatherCode' <<<"$raw" | awk '{
    if ($1==113) print "☀"
    else if ($1==116) print "⛅"
    else if ($1>=119 && $1<=143) print "☁"
    else if ($1>=176 && $1<=296) print "🌧"
    else if ($1>=302 && $1<=389) print "⛈"
    else if ($1>=392) print "❄"
    else print "?"
}')
temp=$(jq -r '.current_condition[0].temp_C' <<<"$raw")°C
desc=$(jq -r '.current_condition[0].weatherDesc[0].value' <<<"$raw")
city=$(jq -r '.nearest_area[0].areaName[0].value' <<<"$raw")

out=$(jq -nc --arg i "$icon" --arg t "$temp" --arg d "$desc" --arg c "$city" \
    '{icon:$i, temp:$t, desc:$d, city:$c}')
echo "$out" | tee "$CACHE"
