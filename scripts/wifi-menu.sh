#!/usr/bin/env bash
# Shared network picker for Waybar, Eww and existing shortcuts.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$script_dir/desktop-control.sh" network
