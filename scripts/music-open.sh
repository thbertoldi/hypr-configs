#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly spotify_id='com.spotify.Client'
readonly spotify_cache="$HOME/.var/app/$spotify_id/cache/spotify"

spotify_window_exists() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    hyprctl clients -j 2>/dev/null \
        | jq -e '.[] | select(
            (.class // "") == "spotify"
            and .mapped
            and (.hidden | not)
        )' >/dev/null 2>&1
}

focus_spotify() {
    spotify_window_exists || return 1

    # Prefer Spotify's standard MPRIS Raise method. It handles activation
    # tokens correctly on Wayland and also powers the tray's Open action.
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session \
            --dest org.mpris.MediaPlayer2.spotify \
            --object-path /org/mpris/MediaPlayer2 \
            --method org.mpris.MediaPlayer2.Raise \
            >/dev/null 2>&1 || true
    fi

    local _attempt
    for _attempt in $(seq 1 10); do
        if [[ $(hyprctl activewindow -j 2>/dev/null \
            | jq -r '.class // ""') == spotify ]]; then
            return 0
        fi
        sleep 0.05
    done

    local workspace_id
    workspace_id=$(hyprctl clients -j 2>/dev/null \
        | jq -r '[.[] | select(
            (.class // "") == "spotify"
            and .mapped
            and (.hidden | not)
        )][0].workspace.id // empty')
    [[ "$workspace_id" =~ ^-?[0-9]+$ ]] || return 1
    hyprctl dispatch "hl.dsp.focus({ workspace = $workspace_id })" >/dev/null

    # Hyprland 0.55's Lua focus dispatcher expects a window selector string.
    hyprctl dispatch 'hl.dsp.focus({ window = "class:spotify" })' >/dev/null

    for _attempt in $(seq 1 60); do
        if [[ $(hyprctl activewindow -j 2>/dev/null \
            | jq -r '.class // ""') == spotify ]]; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

spotify_is_running() {
    command -v flatpak >/dev/null 2>&1 || return 1
    flatpak ps --columns=application 2>/dev/null \
        | grep -Fxq "$spotify_id"
}

clear_stale_singleton_locks() {
    spotify_is_running && return 0

    # Flatpak's PID namespace can make Chromium mistake locks left by a
    # terminated system-scoped Spotify instance for a live process.
    rm -f -- \
        "$spotify_cache/SingletonLock" \
        "$spotify_cache/SingletonSocket" \
        "$spotify_cache/SingletonCookie"
}

launch_flatpak_spotify() {
    local installation=$1
    shift

    # Flathub's /app/bin/spotify wrapper backgrounds the real process. Running
    # the executable in the foreground lets UWSM keep the correct app scope.
    exec "$script_dir/app-launch.sh" flatpak run "$installation" \
        --env=LD_PRELOAD=/app/lib/spotify-preload.so \
        --env=PULSE_PROP_application.icon_name=com.spotify.Client \
        --command=/app/extra/bin/spotify \
        "$spotify_id" "$@"
}

if focus_spotify; then
    exit 0
fi

clear_stale_singleton_locks

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info --user "$spotify_id" >/dev/null 2>&1; then
    launch_flatpak_spotify --user "$@"
fi

if command -v spotify >/dev/null 2>&1; then
    exec "$script_dir/app-launch.sh" spotify "$@"
fi

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info --system "$spotify_id" >/dev/null 2>&1; then
    launch_flatpak_spotify --system "$@"
fi

notify-send -a Hyprland -u critical 'Música indisponível' \
    'Spotify não está instalado.'
exit 1
