#!/usr/bin/env bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
state_dir="$runtime_dir/hypr-screen-record"
output=''
[[ ! -r "$state_dir/output" ]] || read -r output < "$state_dir/output"

if [[ -n "$output" && -s "$output" ]]; then
    notify-send -a Hyprland 'Gravação concluída' "$output"
elif [[ "${SERVICE_RESULT:-}" != success ]]; then
    notify-send -a Hyprland -u critical 'Falha na gravação' "Resultado: ${SERVICE_RESULT:-desconhecido}"
fi

rm -f -- "$state_dir/geometry" "$state_dir/output"
rmdir "$state_dir" 2>/dev/null || true
pkill -RTMIN+10 waybar 2>/dev/null || true
