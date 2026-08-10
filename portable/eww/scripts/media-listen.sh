#!/usr/bin/env bash
set -euo pipefail

emit() {
    local status=${1:-Stopped} title=${2:-} artist=${3:-} icon='⏵'
    [[ "$status" != Playing ]] || icon='⏸'
    jq -nc --arg status "$status" --arg title "$title" --arg artist "$artist" --arg icon "$icon" \
        '{status:$status,title:$title,artist:$artist,icon:$icon}'
}

emit Stopped '' ''
playerctld daemon >/dev/null 2>&1 || true

while true; do
    if ! playerctl --player=playerctld status >/dev/null 2>&1; then
        playerctld shift >/dev/null 2>&1 || true
    fi

    if playerctl --player=playerctld status >/dev/null 2>&1; then
        playerctl --player=playerctld --follow metadata \
            --format '{{status}}|||{{title}}|||{{artist}}' 2>/dev/null \
            | while IFS= read -r line; do
                status=${line%%\|\|\|*}
                rest=${line#*|||}
                title=${rest%%\|\|\|*}
                artist=${rest#*|||}
                emit "$status" "$title" "$artist"
            done
        emit Stopped '' ''
    fi
    sleep 1
done
