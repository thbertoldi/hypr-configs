#!/usr/bin/env bash
set -euo pipefail

send_wob() {
    local value=$1
    local runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
    local fifo="$runtime_dir/wob.sock"
    [[ -p "$fifo" ]] || return 0
    # shellcheck disable=SC2016 # parâmetros pertencem ao bash interno
    timeout 0.2s bash -c 'printf "%s brightness\n" "$2" > "$1"' \
        _ "$fifo" "$value" 2>/dev/null || true
}

current_percent() {
    brightnessctl --class=backlight --machine-readable info \
        | awk -F, 'NR == 1 {gsub(/%/, "", $4); print $4}'
}

case "${1:-}" in
    up)
        brightnessctl --class=backlight --quiet set +5%
        ;;
    down)
        brightnessctl --class=backlight --quiet --min-value=1 set 5%-
        ;;
    set)
        value=${2:-}
        [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 64
        brightnessctl --class=backlight --quiet --min-value=1 set "${value}%"
        ;;
    show) ;;
    *)
        printf 'uso: %s {up|down|set PERCENTUAL|show}\n' "${0##*/}" >&2
        exit 64
        ;;
esac

send_wob "$(current_percent)"
