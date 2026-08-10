#!/usr/bin/env bash
set -euo pipefail

signal_waybar() {
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

if systemctl --user is-active --quiet screen-recorder.service; then
    systemctl --user stop screen-recorder.service
    signal_waybar
    exit 0
fi

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify-send -a Hyprland -u critical 'Gravação indisponível' 'wf-recorder não está instalado.'
    exit 1
fi

geometry=$(slurp) || exit 0
[[ -n "$geometry" ]] || exit 0

runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
state_dir="$runtime_dir/hypr-screen-record"
output_dir="$HOME/Videos/Recordings"
output="$output_dir/recording-$(date +%Y%m%d-%H%M%S).mkv"

install -d -m 700 "$state_dir" "$output_dir"
printf '%s\n' "$geometry" > "$state_dir/geometry"
printf '%s\n' "$output" > "$state_dir/output"

systemctl --user start screen-recorder.service
signal_waybar
notify-send -a Hyprland 'Gravação iniciada' 'Use Super+Alt+R ou clique em REC para encerrar.'
