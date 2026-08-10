#!/usr/bin/env bash
set -euo pipefail

send_wob() {
    local value=$1 style=$2
    local runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
    local fifo="$runtime_dir/wob.sock"
    [[ -p "$fifo" ]] || return 0
    # shellcheck disable=SC2016 # parâmetros pertencem ao bash interno
    timeout 0.2s bash -c 'printf "%s %s\n" "$2" "$3" > "$1"' \
        _ "$fifo" "$value" "$style" 2>/dev/null || true
}

sink_state() {
    local state volume muted style
    state=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    volume=$(awk '{printf "%.0f", $2 * 100}' <<<"$state")
    muted=0
    style=volume
    if [[ "$state" == *'[MUTED]'* ]]; then
        muted=1
        style=muted
    fi
    (( muted )) && volume=0
    send_wob "$volume" "$style"
}

case "${1:-}" in
    up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        sink_state
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        sink_state
        ;;
    toggle)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        sink_state
        ;;
    set)
        value=${2:-}
        [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 64
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${value}%"
        sink_state
        ;;
    mic-toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        state=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
        if [[ "$state" == *'[MUTED]'* ]]; then
            send_wob 0 muted
        else
            send_wob 100 mic
        fi
        ;;
    show)
        sink_state
        ;;
    *)
        printf 'uso: %s {up|down|toggle|set PERCENTUAL|mic-toggle|show}\n' "${0##*/}" >&2
        exit 64
        ;;
esac
