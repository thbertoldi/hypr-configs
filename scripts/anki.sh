#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
app_id='net.ankiweb.Anki'

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info "$app_id" >/dev/null 2>&1; then
    exec "$script_dir/app-launch.sh" flatpak run "$app_id" "$@"
fi

if command -v anki >/dev/null 2>&1; then
    exec "$script_dir/app-launch.sh" anki "$@"
fi

notify-send -a Hyprland -u critical \
    'Anki indisponível' \
    'Execute o bootstrap para instalar o Anki e a integração de estudos.'
exit 1
