#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

if [[ ${1:-} != osd ]]; then
    (( $# )) || set -- audio
    exec python3 "$script_dir/desktop_controls.py" "$@"
fi

# Hardware repeat uses this small D-Bus client, without importing GTK each time.
kind=${2:-}
value=${3:-}
case "$kind" in volume|mic|brightness) ;; *) exit 64 ;; esac
[[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 64
muted=false
[[ ${4:-} != muted ]] || muted=true
read -r x y < <(hyprctl cursorpos -j | jq -r '[.x,.y] | @tsv')
systemctl --user start desktop-controls.service
gdbus call --session --dest org.thbertoldi.DesktopControls \
    --object-path /org/thbertoldi/DesktopControls \
    --method org.thbertoldi.DesktopControls.OSD \
    "$kind" "$value" "$muted" "$x" "$y" >/dev/null
