#!/usr/bin/env bash
set -euo pipefail

emit() {
    local line value device
    line=$(brightnessctl --class=backlight --machine-readable info 2>/dev/null | head -n 1 || true)
    if [[ -z "$line" ]]; then
        jq -nc '{available:false,value:0,device:"Sem backlight"}'
        return
    fi
    device=$(awk -F, '{print $1}' <<<"$line")
    value=$(awk -F, '{gsub(/%/, "", $4); print $4}' <<<"$line")
    jq -nc --argjson value "$value" --arg device "$device" \
        '{available:true,value:$value,device:$device}'
}

emit
shopt -s nullglob
brightness_files=(/sys/class/backlight/*/brightness)
if (( ${#brightness_files[@]} == 0 )); then
    while sleep 30; do emit; done
fi

inotifywait --monitor --quiet --event modify,close_write "${brightness_files[@]}" 2>/dev/null \
    | while IFS= read -r _; do emit; done
