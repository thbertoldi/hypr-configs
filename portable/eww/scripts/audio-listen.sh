#!/usr/bin/env bash
set -euo pipefail

emit() {
    local sink_state source_state volume muted mic_muted sink icon mic_icon
    sink_state=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || printf 'Volume: 0')
    source_state=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || printf 'Volume: 0 [MUTED]')
    volume=$(awk '{printf "%.0f", $2 * 100}' <<<"$sink_state")
    (( volume > 100 )) && volume=100
    muted=false
    icon=''
    if [[ "$sink_state" == *'[MUTED]'* ]]; then
        muted=true
        icon=''
    elif (( volume < 35 )); then
        icon=''
    fi
    mic_muted=false
    mic_icon=''
    if [[ "$source_state" == *'[MUTED]'* ]]; then
        mic_muted=true
        mic_icon=''
    fi
    sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | sed -n 's/^[[:space:]*]*node.description = "\(.*\)"/\1/p' \
        | head -n 1)
    [[ -n "$sink" ]] || sink='Saída padrão'

    jq -nc --argjson volume "$volume" --argjson muted "$muted" \
        --argjson mic_muted "$mic_muted" --arg sink "$sink" \
        --arg icon "$icon" --arg mic_icon "$mic_icon" \
        '{volume:$volume,muted:$muted,mute_class:(if $muted then "on" else "off" end),
          mic_muted:$mic_muted,mic_class:(if $mic_muted then "on" else "off" end),
          sink:$sink,icon:$icon,mic_icon:$mic_icon}'
}

emit
pactl subscribe 2>/dev/null | while IFS= read -r _; do emit; done
