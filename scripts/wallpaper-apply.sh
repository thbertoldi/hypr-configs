#!/usr/bin/env bash
set -euo pipefail

wallpaper=${HYPR_WALLPAPER:-"$HOME/Pictures/wallpapers/whales-clouds.jpg"}
if [[ ! -f "$wallpaper" ]]; then
    printf 'wallpaper não encontrado: %s\n' "$wallpaper" >&2
    exit 1
fi

for _ in {1..40}; do
    if awww query >/dev/null 2>&1; then
        exec awww img "$wallpaper" --transition-type none
    fi
    sleep 0.1
done

printf 'awww-daemon não ficou disponível a tempo\n' >&2
exit 1
