#!/usr/bin/env bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
state_file="$runtime_dir/hyprsunset-mode"

ensure_daemon() {
    if ! pgrep -x hyprsunset >/dev/null 2>&1; then
        systemctl --user start hyprsunset.service
        sleep 0.3
    fi
}

mode() {
    if [[ -r "$state_file" ]]; then
        read -r saved_mode < "$state_file"
        case "$saved_mode" in
            on|off) printf '%s\n' "$saved_mode"; return ;;
        esac
    fi
    printf 'auto\n'
}

effective_status() {
    local current_mode hour
    current_mode=$(mode)
    case "$current_mode" in
        on|off) printf '%s\n' "$current_mode" ;;
        auto)
            hour=$(date +%H)
            if (( 10#$hour >= 19 || 10#$hour < 7 )); then
                printf 'on\n'
            else
                printf 'off\n'
            fi
            ;;
    esac
}

case "${1:-toggle}" in
    toggle)
        ensure_daemon
        if [[ "$(effective_status)" == on ]]; then
            hyprctl hyprsunset identity >/dev/null
            printf 'off\n' > "$state_file"
        else
            hyprctl hyprsunset temperature 4500 >/dev/null
            printf 'on\n' > "$state_file"
        fi
        ;;
    auto)
        ensure_daemon
        hyprctl hyprsunset reset >/dev/null
        rm -f -- "$state_file"
        ;;
    status) effective_status ;;
    mode) mode ;;
    *)
        printf 'uso: %s {toggle|auto|status|mode}\n' "${0##*/}" >&2
        exit 64
        ;;
esac
