#!/usr/bin/env bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
state_dir="$runtime_dir/hypr-screen-record"
geometry_file="$state_dir/geometry"
output_file="$state_dir/output"

[[ -r "$geometry_file" && -r "$output_file" ]] || {
    printf 'estado da gravação ausente em %s\n' "$state_dir" >&2
    exit 1
}

read -r geometry < "$geometry_file"
read -r output < "$output_file"

# The openSUSE package defaults to lossless UTVideo, producing huge files on
# ultrawide displays. H.264 with a fast preset balances quality and file size.
args=(-g "$geometry" -c libx264 -p preset=veryfast -p crf=23 -x yuv420p -f "$output")
if command -v pactl >/dev/null 2>&1; then
    sink=$(pactl get-default-sink 2>/dev/null || true)
    [[ -z "$sink" ]] || args+=(--audio="${sink}.monitor")
fi

exec wf-recorder "${args[@]}"
