#!/usr/bin/env bash
set -euo pipefail

readonly spotify_id='com.spotify.Client'
readonly spicetify_version='2.44.0'
readonly spicetify_sha256='115045610a609a2084af389e65aa4f60351a4b8ef1497ce98bdbdf379544ef9b'
readonly theme_commit='3508edd96a2adebd6daa78d1f2c9e7367ef693f8'
readonly theme_color_sha256='4f5a883afd9e71ddf515e8c7ecf44ca55688f4824b12294f4fdcc0f90745ed68'
readonly theme_css_sha256='b5741a6e4caf5d9911fdd53010d48fd0e41f81336dc21e9f7da833d349b0a10a'
readonly marketplace_version='1.0.9'
readonly marketplace_sha256='2713054703c2365e391658a58c782dd2ebdd8d573f2015b5a2bab58b7eee8685'
readonly spicetify_dir="$HOME/.spicetify"
readonly spicetify="$spicetify_dir/spicetify"
readonly config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
work_dir=$(mktemp -d /tmp/hypr-spotify-customize.XXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
    printf 'spotify-customize: %s\n' "$*" >&2
    exit 1
}

verified_download() {
    local url=$1
    local destination=$2
    local expected=$3

    curl --fail --silent --show-error --location "$url" -o "$destination"
    printf '%s  %s\n' "$expected" "$destination" | sha256sum --check --status \
        || fail "checksum inválido para $url"
}

install_spicetify() {
    if [[ -x "$spicetify" ]] \
        && [[ $($spicetify --version 2>/dev/null) == "$spicetify_version" ]]; then
        return
    fi

    local archive="$work_dir/spicetify.tar.gz"
    verified_download \
        "https://github.com/spicetify/cli/releases/download/v${spicetify_version}/spicetify-${spicetify_version}-linux-amd64.tar.gz" \
        "$archive" "$spicetify_sha256"
    install -d "$spicetify_dir"
    tar -xzf "$archive" -C "$spicetify_dir"
    chmod 0755 "$spicetify"
}

install_sleek_theme() {
    local theme_dir="$config_dir/Themes/Sleek"
    local color_tmp="$work_dir/color.ini"
    local css_tmp="$work_dir/user.css"

    verified_download \
        "https://raw.githubusercontent.com/spicetify/spicetify-themes/${theme_commit}/Sleek/color.ini" \
        "$color_tmp" "$theme_color_sha256"
    verified_download \
        "https://raw.githubusercontent.com/spicetify/spicetify-themes/${theme_commit}/Sleek/user.css" \
        "$css_tmp" "$theme_css_sha256"

    install -d "$theme_dir"
    install -m 0644 "$color_tmp" "$theme_dir/color.ini"
    install -m 0644 "$css_tmp" "$theme_dir/user.css"
}

install_marketplace() {
    local archive="$work_dir/marketplace.zip"
    local extract_dir="$work_dir/marketplace"
    local source_dir target_dir

    verified_download \
        "https://github.com/spicetify/marketplace/releases/download/v${marketplace_version}/marketplace.zip" \
        "$archive" "$marketplace_sha256"
    install -d "$extract_dir"
    unzip -q "$archive" -d "$extract_dir"
    source_dir="$extract_dir/marketplace-dist"
    target_dir="$config_dir/CustomApps/marketplace"
    [[ -f "$source_dir/manifest.json" ]] \
        || fail 'arquivo do Marketplace incompleto'
    install -d "$target_dir"
    rsync -a --delete "$source_dir/" "$target_dir/"
}

command -v flatpak >/dev/null 2>&1 || fail 'flatpak não encontrado'
command -v curl >/dev/null 2>&1 || fail 'curl não encontrado'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum não encontrado'
command -v unzip >/dev/null 2>&1 || fail 'unzip não encontrado'
command -v rsync >/dev/null 2>&1 || fail 'rsync não encontrado'

spotify_location=$(flatpak info --user --show-location "$spotify_id" 2>/dev/null) \
    || fail 'instale o Spotify Flatpak para o usuário antes de personalizá-lo'
spotify_path="$spotify_location/files/extra/share/spotify"
prefs_path="$HOME/.var/app/$spotify_id/config/spotify/prefs"
[[ -d "$spotify_path/Apps" ]] || fail "instalação do Spotify incompleta em $spotify_path"
[[ -f "$prefs_path" ]] \
    || fail 'abra o Spotify, faça login, aguarde 60 segundos e tente novamente'
grep -q '^autologin\.username=' "$prefs_path" \
    || fail 'faça login no Spotify, aguarde 60 segundos e tente novamente'

install_spicetify
install_sleek_theme
install_marketplace

# Spotify's built-in AppIndicator only offers minimize/exit and would duplicate
# the richer host-side tray. Block just its watcher access; MPRIS stays enabled.
flatpak override --user \
    --no-talk-name=org.kde.StatusNotifierWatcher \
    "$spotify_id"

"$spicetify" config \
    spotify_path "$spotify_path" \
    prefs_path "$prefs_path" \
    current_theme Sleek \
    color_scheme Catppuccin \
    custom_apps marketplace \
    inject_css 1 \
    replace_colors 1 \
    overwrite_assets 0 \
    inject_theme_js 1

was_running=0
was_playing=0
if flatpak ps --columns=application 2>/dev/null | grep -Fxq "$spotify_id"; then
    was_running=1
    if command -v playerctl >/dev/null 2>&1 \
        && [[ $(playerctl --player=spotify status 2>/dev/null || true) == Playing ]]; then
        was_playing=1
    fi
    while IFS= read -r instance; do
        [[ -n "$instance" ]] || continue
        flatpak kill "$instance" 2>/dev/null || true
    done < <(
        flatpak ps --columns=instance,application 2>/dev/null \
            | awk -v app="$spotify_id" '$2 == app { print $1 }'
    )

    # Flatpak can disappear a moment before Hyprland removes the old window.
    # Wait for both so music-open does not mistake that closing window for a
    # live instance and skip the relaunch.
    for _attempt in $(seq 1 100); do
        flatpak_running=0
        spotify_window=0
        if flatpak ps --columns=application 2>/dev/null \
            | grep -Fxq "$spotify_id"; then
            flatpak_running=1
        fi
        if command -v hyprctl >/dev/null 2>&1 \
            && command -v jq >/dev/null 2>&1 \
            && hyprctl clients -j 2>/dev/null \
                | jq -e '.[] | select((.class // "") == "spotify" and .mapped)' \
                    >/dev/null 2>&1; then
            spotify_window=1
        fi
        (( flatpak_running || spotify_window )) || break
        sleep 0.1
    done
fi

backup_version=$(awk '
    $0 == "[Backup]" { in_backup = 1; next }
    /^\[/ { in_backup = 0 }
    in_backup && $1 == "version" {
        sub(/^[^=]*=[[:space:]]*/, "")
        print
        exit
    }
' "$config_dir/config-xpui.ini")
spotify_version=$(flatpak list --user --app --columns=application,version \
    | awk -F '\t' -v app="$spotify_id" '$1 == app { print $2; exit }')
[[ -n "$spotify_version" ]] || fail 'não foi possível detectar a versão do Spotify'
if [[ -n "$backup_version" && "$backup_version" == "$spotify_version" ]]; then
    "$spicetify" apply
else
    "$spicetify" backup apply
fi

if (( was_running )) && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    if command -v systemd-run >/dev/null 2>&1; then
        relaunch_unit="hypr-spotify-relaunch-$(date +%s%N)"
        systemd-run --user --collect --quiet \
            --unit="$relaunch_unit" \
            "$script_dir/music-open.sh"
    else
        setsid "$script_dir/music-open.sh" </dev/null >/dev/null 2>&1 &
    fi
    if (( was_playing )) && command -v playerctl >/dev/null 2>&1; then
        for _attempt in $(seq 1 100); do
            if playerctl --player=spotify status >/dev/null 2>&1; then
                playerctl --player=spotify play >/dev/null 2>&1 || true
                break
            fi
            sleep 0.1
        done
    fi
fi
