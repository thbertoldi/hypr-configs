#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

send_wob() {
    local value=$1 style=$2
    local runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
    local fifo="$runtime_dir/wob.sock"
    [[ -p "$fifo" ]] || return 0
    # shellcheck disable=SC2016 # parâmetros pertencem ao bash interno
    timeout 0.2s bash -c 'printf "%s %s\n" "$2" "$3" > "$1"' \
        _ "$fifo" "$value" "$style" 2>/dev/null || true
}

show_state() {
    local target=$1 kind=$2 state volume style
    state=$(wpctl get-volume "$target")
    volume=$(awk '{printf "%.0f", $2 * 100}' <<<"$state")
    style=$kind
    if [[ "$state" == *'[MUTED]'* ]]; then
        style=muted
    fi
    "$script_dir/desktop-control.sh" osd "$kind" "$volume" "$style" 2>/dev/null \
        || send_wob "$volume" "$style"
}

sink_state() {
    show_state @DEFAULT_AUDIO_SINK@ volume
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
        show_state @DEFAULT_AUDIO_SOURCE@ mic
        ;;
    show)
        sink_state
        ;;
    *)
        printf 'uso: %s {up|down|toggle|set PERCENTUAL|mic-toggle|show}\n' "${0##*/}" >&2
        exit 64
        ;;
esac
