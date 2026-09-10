#!/usr/bin/env bash
# Reproduce this Hyprland desktop on openSUSE Tumbleweed x86_64 (amd64).
#
# The script installs distro packages, pinned visual assets, this Hyprland
# configuration, and the companion Waybar/Eww/Mako/Fuzzel/etc. files. Existing
# configuration is copied to a dated backup before any known file is replaced.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DRY_RUN=0
SKIP_PACKAGES=0
SKIP_THEMES=0
WITH_EXTRAS=0
SAME_HARDWARE=0
WALLPAPER_SOURCE=""
AVATAR_SOURCE=""
INTERNAL_OUTPUT="eDP-1"
TEMP_DIR=""
BACKUP_DIR=""

readonly GTK_THEME_NAME="catppuccin-mocha-peach-standard+default"
readonly GTK_THEME_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-peach-standard+default.zip"
readonly GTK_THEME_SHA256="d14dd2e61086025464e1aa577f2ff8a3c9a65d0df16ee1af9f4ec66496e5d9b8"
readonly NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.tar.xz"
readonly NERD_FONT_SHA256="ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582"
readonly BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz"
readonly BIBATA_SHA256="7d3495864e5bbef02f5e77de760b2905903b63c71495a78ef6306d19a3b556d8"
readonly KVANTUM_COMMIT="71105d224fef95dd023691303477ce3eea487457"
readonly KVANTUM_URL="https://codeload.github.com/catppuccin/Kvantum/tar.gz/${KVANTUM_COMMIT}"
readonly KVANTUM_SHA256="f2bd573f8d7500c65fd69e1629b3bcf3eba3468124b81f1d12d54b2f5dda1a0c"
readonly GRIMBLAST_COMMIT="3dcbce715ae8b93107fa8632db15bf976862a573"
readonly GRIMBLAST_URL="https://raw.githubusercontent.com/hyprwm/contrib/${GRIMBLAST_COMMIT}/grimblast/grimblast"
readonly GRIMBLAST_SHA256="1e12c15ee3b0160d053a1655019dbbb91174ff4fe7c9bae47f62141146fed091"
readonly CODEX_CLI_VERSION="0.146.1"
# Official standalone Linux amd64 releases; no remote install scripts.
readonly HERDR_URL="https://github.com/herdrdev/herdr/releases/download/v0.8.2/herdr-linux-x86_64"
readonly HERDR_SHA256="976150a14d490c94b243ea2e1a7eb2dfb67f12e36b182db90936f6728e6aecf4"
readonly MARKSMAN_URL="https://github.com/artempyanykh/marksman/releases/download/2026-02-08/marksman-linux-x64"
readonly MARKSMAN_SHA256="be5098e8213219269c47fc0d916a66fa31ce0602ec967475c722260aabf26087"

usage() {
    cat <<'EOF'
Usage:
  ./bootstrap-opensuse-tumbleweed.sh [options]

Options:
  --wallpaper FILE     Copy an image to the wallpaper path used by awww.
  --avatar FILE        Copy an image to the Eww dashboard avatar path.
  --same-hardware      Keep this machine's LG ultrawide + eDP profile.
                       Otherwise, install a safe generic monitor profile.
  --internal-output N  Replace eDP-1 with the specified internal output name.
  --with-extras        Install the Wayland diagnostic utility `wev`.
  --skip-packages      Skip zypper and Herdr/Marksman installation.
  --skip-themes        Skip font, cursor and GTK/Kvantum theme downloads.
  --dry-run            Show actions without changing the computer.
  -h, --help           Show this help.

Example:
  ./bootstrap-opensuse-tumbleweed.sh \
    --wallpaper ~/Downloads/whales-clouds.jpg \
    --avatar ~/Pictures/avatar.jpeg
EOF
}

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

print_command() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    if (( DRY_RUN )); then
        print_command "$@"
    else
        "$@"
    fi
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        case "$TEMP_DIR" in
            "${TMPDIR:-/tmp}"/hypr-bootstrap.*) rm -rf -- "$TEMP_DIR" ;;
            *) warn "Preserving unexpected temporary directory: $TEMP_DIR" ;;
        esac
    fi
}

on_error() {
    local status=$?
    printf 'ERROR: failure at line %s (status %s): %s\n' "${BASH_LINENO[0]}" "$status" "$BASH_COMMAND" >&2
    exit "$status"
}

trap cleanup EXIT
trap on_error ERR

while (( $# )); do
    case "$1" in
        --wallpaper)
            (( $# >= 2 )) || die "--wallpaper requires a file"
            WALLPAPER_SOURCE=$2
            shift 2
            ;;
        --avatar)
            (( $# >= 2 )) || die "--avatar requires a file"
            AVATAR_SOURCE=$2
            shift 2
            ;;
        --internal-output)
            (( $# >= 2 )) || die "--internal-output requires a name"
            INTERNAL_OUTPUT=$2
            shift 2
            ;;
        --same-hardware)
            SAME_HARDWARE=1
            shift
            ;;
        --with-extras)
            WITH_EXTRAS=1
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=1
            shift
            ;;
        --skip-themes)
            SKIP_THEMES=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

validate_host() {
    [[ $EUID -ne 0 ]] || die "run as a normal user; the script invokes sudo only where needed"
    [[ -r /etc/os-release ]] || die "/etc/os-release not found"

    local os_id
    os_id=$( ( . /etc/os-release; printf '%s' "${ID:-}" ) )
    [[ "$os_id" == "opensuse-tumbleweed" ]] || die "this installer requires openSUSE Tumbleweed (current ID: ${os_id:-unknown})"
    [[ $(uname -m) == "x86_64" ]] || die "this bundle supports only amd64/x86_64"

    [[ "$INTERNAL_OUTPUT" =~ ^[A-Za-z0-9_.:-]+$ ]] || die "invalid output name: $INTERNAL_OUTPUT"
    [[ -z "$WALLPAPER_SOURCE" || -f "$WALLPAPER_SOURCE" ]] || die "wallpaper not found: $WALLPAPER_SOURCE"
    [[ -z "$AVATAR_SOURCE" || -f "$AVATAR_SOURCE" ]] || die "avatar not found: $AVATAR_SOURCE"
    [[ -d "$SCRIPT_DIR/docs" ]] || die "incomplete bundle; missing $SCRIPT_DIR/docs"

    local required_source
    for required_source in \
        "$SCRIPT_DIR/LICENSE" \
        "$SCRIPT_DIR/NOTICE" \
        "$SCRIPT_DIR/THIRD_PARTY.md" \
        "$SCRIPT_DIR/third-party/README.md" \
        "$SCRIPT_DIR/third-party/obsidian-style-settings-1.0.9.tar.gz" \
        "$SCRIPT_DIR/hyprland.lua" \
        "$SCRIPT_DIR/hypridle.conf" \
        "$SCRIPT_DIR/hyprlock.conf" \
        "$SCRIPT_DIR/hyprsunset.conf" \
        "$SCRIPT_DIR/lua/autostart.lua" \
        "$SCRIPT_DIR/scripts/agent-menu.sh" \
        "$SCRIPT_DIR/scripts/anki-connect-install.sh" \
        "$SCRIPT_DIR/scripts/anki-connect.sh" \
        "$SCRIPT_DIR/scripts/anki-tts-install.sh" \
        "$SCRIPT_DIR/scripts/anki.sh" \
        "$SCRIPT_DIR/scripts/calendar-open.sh" \
        "$SCRIPT_DIR/scripts/calendar-tray.py" \
        "$SCRIPT_DIR/scripts/desktop_controls.py" \
        "$SCRIPT_DIR/scripts/desktop-control.sh" \
        "$SCRIPT_DIR/scripts/desktop-controls.css" \
        "$SCRIPT_DIR/scripts/audio_backend.py" \
        "$SCRIPT_DIR/scripts/focus_timer.py" \
        "$SCRIPT_DIR/scripts/portal-healthcheck.py" \
        "$SCRIPT_DIR/scripts/notification_control.py" \
        "$SCRIPT_DIR/scripts/clipboard_picker.py" \
        "$SCRIPT_DIR/scripts/scratchpad.py" \
        "$SCRIPT_DIR/scripts/configure-app-trays.py" \
        "$SCRIPT_DIR/scripts/cite-pick.sh" \
        "$SCRIPT_DIR/scripts/dcal.sh" \
        "$SCRIPT_DIR/scripts/monitor-listener.sh" \
        "$SCRIPT_DIR/scripts/music-open.sh" \
        "$SCRIPT_DIR/scripts/spotify-customize.sh" \
        "$SCRIPT_DIR/scripts/spotify-tray.py" \
        "$SCRIPT_DIR/scripts/spotify-tray.css" \
        "$SCRIPT_DIR/scripts/steam-tray.py" \
        "$SCRIPT_DIR/scripts/tray_data.py" \
        "$SCRIPT_DIR/scripts/tray_popup.py" \
        "$SCRIPT_DIR/scripts/tray-popups.css" \
        "$SCRIPT_DIR/scripts/zen-style.py" \
        "$SCRIPT_DIR/scripts/obsidian-style.py" \
        "$SCRIPT_DIR/scripts/study-open.sh" \
        "$SCRIPT_DIR/scripts/study-seed.sh" \
        "$SCRIPT_DIR/scripts/study-status.sh" \
        "$SCRIPT_DIR/scripts/study-tooltip.py" \
        "$SCRIPT_DIR/scripts/study-tts-check.sh" \
        "$SCRIPT_DIR/scripts/study-tts-repair.sh" \
        "$SCRIPT_DIR/scripts/study-tts-synthesize.sh" \
        "$SCRIPT_DIR/portable/anki/starter-decks.json" \
        "$SCRIPT_DIR/WORKFLOW.md" \
        "$SCRIPT_DIR/DECISIONS.md" \
        "$SCRIPT_DIR/README.md" \
        "$SCRIPT_DIR/assets/README.md" \
        "$SCRIPT_DIR/portable/alacritty/alacritty.toml" \
        "$SCRIPT_DIR/portable/kitty/kitty.conf" \
        "$SCRIPT_DIR/portable/starship/starship.toml" \
        "$SCRIPT_DIR/portable/starship/CATPPUCCIN-LICENSE" \
        "$SCRIPT_DIR/portable/obsidian/appearance.json" \
        "$SCRIPT_DIR/portable/obsidian/style-settings.json" \
        "$SCRIPT_DIR/portable/obsidian/CATPPUCCIN-LICENSE" \
        "$SCRIPT_DIR/portable/obsidian/themes/Catppuccin/theme.css" \
        "$SCRIPT_DIR/portable/obsidian/themes/Catppuccin/manifest.json" \
        "$SCRIPT_DIR/portable/obsidian/plugins/obsidian-style-settings/main.js" \
        "$SCRIPT_DIR/portable/obsidian/plugins/obsidian-style-settings/manifest.json" \
        "$SCRIPT_DIR/portable/obsidian/plugins/obsidian-style-settings/styles.css" \
        "$SCRIPT_DIR/portable/obsidian/plugins/obsidian-style-settings/LICENSE.md" \
        "$SCRIPT_DIR/portable/zen/user.js" \
        "$SCRIPT_DIR/portable/zen/CATPPUCCIN-LICENSE" \
        "$SCRIPT_DIR/portable/zen/chrome/catppuccin-mocha-peach.css" \
        "$SCRIPT_DIR/portable/zen/chrome/catppuccin-mocha-peach-content.css" \
        "$SCRIPT_DIR/portable/zen/chrome/hypr-mocha-peach.css" \
        "$SCRIPT_DIR/portable/zen/chrome/zen-logo-mocha.svg" \
        "$SCRIPT_DIR/portable/helix/config.toml" \
        "$SCRIPT_DIR/portable/helix/languages.toml" \
        "$SCRIPT_DIR/portable/helix/runtime/queries/rpmspec/highlights.scm" \
        "$SCRIPT_DIR/portable/yazi/yazi.toml" \
        "$SCRIPT_DIR/portable/yazi/theme.toml" \
        "$SCRIPT_DIR/portable/yazi/Catppuccin-mocha.tmTheme" \
        "$SCRIPT_DIR/portable/yazi/CATPPUCCIN-LICENSE" \
        "$SCRIPT_DIR/portable/herdr/config.toml" \
        "$SCRIPT_DIR/portable/zapzap/catppuccin-mocha-peach.css" \
        "$SCRIPT_DIR/portable/waybar/config.jsonc" \
        "$SCRIPT_DIR/portable/swaync/config.json" \
        "$SCRIPT_DIR/portable/swaync/style.css" \
        "$SCRIPT_DIR/portable/eww/eww.yuck" \
        "$SCRIPT_DIR/portable/eww/scripts/calendar-list.sh" \
        "$SCRIPT_DIR/portable/applications/hypr-study.desktop" \
        "$SCRIPT_DIR/portable/applications/org.kde.merkuro.calendar.desktop" \
        "$SCRIPT_DIR/portable/xdg-desktop-portal/hyprland-portals.conf" \
        "$SCRIPT_DIR/portable/systemd/user/hyprland-session.target" \
        "$SCRIPT_DIR/portable/systemd/user/dankcalendar.service" \
        "$SCRIPT_DIR/portable/systemd/user/spotify-tray.service" \
        "$SCRIPT_DIR/portable/systemd/user/steam-tray.service" \
        "$SCRIPT_DIR/portable/systemd/user/calendar-tray.service" \
        "$SCRIPT_DIR/portable/systemd/user/desktop-controls.service" \
        "$SCRIPT_DIR/portable/systemd/user/focus-timer.service" \
        "$SCRIPT_DIR/portable/systemd/user/portal-healthcheck.service" \
        "$SCRIPT_DIR/portable/systemd/user/portal-healthcheck.timer" \
        "$SCRIPT_DIR/portable/systemd/user/xdg-desktop-portal-hyprland.service.d/recovery.conf" \
        "$SCRIPT_DIR/portable/systemd/user/swaync.service.d/desktop.conf" \
        "$SCRIPT_DIR/portable/wayland-sessions/hyprland-uwsm.desktop" \
        "$SCRIPT_DIR/portable/monitors-generic.lua"; do
        [[ -f "$required_source" ]] || die "incomplete bundle; missing $required_source"
    done
}

install_packages() {
    (( SKIP_PACKAGES )) && { log "Skipping packages due to --skip-packages"; return; }

    local packages=(
        hyprland hyprland-wallpapers hypridle hyprlock hyprpicker awww
        waybar SwayNotificationCenter mako eww fuzzel wlogout
        xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        polkit hyprpolkitagent kwalletd6 pam_kwallet6
        NetworkManager NetworkManager-applet NetworkManager-connection-editor
        NetworkManager-openvpn NetworkManager-applet-openvpn
        bluez blueman
        pipewire pipewire-pulseaudio wireplumber pavucontrol pulseaudio-utils
        power-profiles-daemon upower hyprsunset wob
        wl-clipboard cliphist grim slurp
        brightnessctl playerctl swappy udiskie
        uwsm inotify-tools nwg-displays btop flatpak
        merkuro korganizer kalendarac kdepim-runtime akonadi-calendar-tools kaccounts-integration
        kaccounts-providers libkgapi6 kdialog
        nodejs24 npm24
        ghostty alacritty kitty starship yazi MozillaFirefox helix
        glow pandoc-cli lua-language-server texlab taplo shfmt ShellCheck gcc
        poppler-tools file fd ripgrep fzf zoxide 7zip ImageMagick chafa resvg ffmpeg-8
        qt6ct kvantum-manager kvantum-qt6
        papirus-icon-theme fontawesome-fonts symbols-only-nerd-fonts
        google-noto-sans-fonts google-noto-coloremoji-fonts
        python3-gobject python3-gobject-Gdk python3-gobject-cairo python3-pycairo typelib-1_0-GtkLayerShell-0_1
        libnotify-tools
        jq socat curl unzip xz tar rsync git procps gawk dbus-1-tools glib2-tools
        xdg-user-dirs
    )
    local extras=(wev)

    log "Refreshing repository metadata"
    if (( DRY_RUN )); then
        print_command sudo zypper --non-interactive refresh
        print_command sudo zypper --non-interactive install "${packages[@]}"
        (( WITH_EXTRAS )) && print_command sudo zypper --non-interactive install "${extras[@]}"
        return 0
    fi

    sudo -v
    sudo zypper --non-interactive refresh
    sudo zypper --non-interactive install "${packages[@]}"
    if (( WITH_EXTRAS )); then
        sudo zypper --non-interactive install "${extras[@]}"
    fi
}

install_dankcalendar() {
    local app_id='com.danklinux.dankcalendar'

    if command -v dcal >/dev/null 2>&1; then
        log "Native DankCalendar is already installed"
        return
    fi

    if (( DRY_RUN )); then
        log "Installing DankCalendar from Flathub for the current user"
        print_command flatpak --user remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
        print_command flatpak --user install --noninteractive flathub "$app_id"
        return
    fi

    command -v flatpak >/dev/null 2>&1 \
        || die "flatpak is unavailable after package installation"
    if flatpak info "$app_id" >/dev/null 2>&1; then
        log "DankCalendar Flatpak is already installed"
        return
    fi

    log "Installing DankCalendar from Flathub for the current user"
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install --noninteractive flathub "$app_id"
}

install_zen() {
    local app_id='app.zen_browser.zen'
    if command -v zen >/dev/null 2>&1 || command -v zen-browser >/dev/null 2>&1; then
        log "Native Zen is already installed"
        return
    fi
    if command -v flatpak >/dev/null 2>&1 && flatpak info "$app_id" >/dev/null 2>&1; then
        log "Zen Flatpak is already installed"
        return
    fi
    log "Installing Zen from Flathub for the current user"
    run flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    run flatpak --user install --noninteractive flathub "$app_id"
}

install_spotify() {
    local app_id='com.spotify.Client'

    # Spicetify needs a user-owned deployment. A system Flatpak can coexist
    # and remains untouched, while the user installation takes precedence.
    if command -v flatpak >/dev/null 2>&1 \
        && flatpak info --user "$app_id" >/dev/null 2>&1; then
        log "User-scoped Spotify Flatpak is already installed"
        return
    fi

    if (( DRY_RUN )); then
        log "Installing Spotify from Flathub for the current user"
        print_command flatpak --user remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
        print_command flatpak --user install --noninteractive flathub "$app_id"
        return
    fi

    command -v flatpak >/dev/null 2>&1 \
        || die "flatpak is unavailable after package installation"
    log "Installing Spotify from Flathub for the current user"
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install --noninteractive flathub "$app_id"
}

install_zapzap() {
    local app_id='com.rtosta.zapzap'

    if command -v flatpak >/dev/null 2>&1 \
        && flatpak info "$app_id" >/dev/null 2>&1; then
        log "ZapZap Flatpak is already installed; keeping the existing version"
        return
    fi

    if (( DRY_RUN )); then
        log "Installing ZapZap from Flathub for the current user"
        print_command flatpak --user remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
        print_command flatpak --user install --noninteractive flathub "$app_id"
        return
    fi

    command -v flatpak >/dev/null 2>&1 \
        || die "flatpak is unavailable after package installation"
    log "Installing ZapZap from Flathub for the current user"
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install --noninteractive flathub "$app_id"
}

install_anki() {
    local app_id='net.ankiweb.Anki'

    if command -v anki >/dev/null 2>&1; then
        log "Native Anki is already installed; keeping the existing version"
        return
    fi

    if command -v flatpak >/dev/null 2>&1 \
        && flatpak info "$app_id" >/dev/null 2>&1; then
        log "Anki Flatpak is already installed; keeping the existing version"
        return
    fi

    if (( DRY_RUN )); then
        log "Installing Anki from Flathub for the current user"
        print_command flatpak --user remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
        print_command flatpak --user install --noninteractive flathub "$app_id"
        return
    fi

    command -v flatpak >/dev/null 2>&1 \
        || die "flatpak is unavailable after package installation"
    log "Installing Anki from Flathub for the current user"
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install --noninteractive flathub "$app_id"
}

install_anki_addons() {
    log "Installing verified local Anki integrations"
    if (( DRY_RUN )); then
        print_command bash "$SCRIPT_DIR/scripts/anki-connect-install.sh"
        print_command bash "$SCRIPT_DIR/scripts/anki-tts-install.sh"
        return
    fi
    bash "$SCRIPT_DIR/scripts/anki-connect-install.sh"
    bash "$SCRIPT_DIR/scripts/anki-tts-install.sh"
}

configure_zapzap() {
    local app_id='com.rtosta.zapzap'
    local style_name='catppuccin-mocha-peach.css'
    local style_dir="$HOME/.var/app/$app_id/data/ZapZap/customizations/global/css"
    local settings_code
    settings_code='from PyQt6.QtCore import QSettings; s=QSettings("ZapZap", "ZapZap"); s.setValue("system/theme", "dark"); s.setValue("system/tray_theme", "symbolic_light"); s.setValue("website/open_page", False); s.setValue("custom/global/css/enabled", True); d=s.value("custom/global/css/disabled_files", []); d=[d] if isinstance(d, str) else list(d or []); s.setValue("custom/global/css/disabled_files", [v for v in d if v != "catppuccin-mocha-peach.css"]); s.sync()'

    log "Applying Catppuccin Mocha/Peach to ZapZap"
    run install -d "$style_dir"
    install_file 0644 \
        "$SCRIPT_DIR/portable/zapzap/$style_name" \
        "$style_dir/$style_name"

    if (( DRY_RUN )); then
        print_command flatpak run --command=python3 "$app_id" -c "$settings_code"
        return
    fi

    flatpak run --command=python3 "$app_id" -c "$settings_code"
}

configure_zen() {
    log "Applying Catppuccin Mocha/Peach to initialized Zen profiles"
    local args=()
    (( DRY_RUN )) && args+=(--dry-run)
    python3 "$SCRIPT_DIR/scripts/zen-style.py" "${args[@]}"
}

configure_obsidian() {
    log "Applying Catppuccin Mocha/Peach to open Obsidian vaults"
    local args=()
    (( DRY_RUN )) && args+=(--dry-run)
    python3 "$SCRIPT_DIR/scripts/obsidian-style.py" "${args[@]}"
}

configure_spotify() {
    local prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"

    if (( DRY_RUN )); then
        print_command flatpak override --user \
            --no-talk-name=org.kde.StatusNotifierWatcher \
            com.spotify.Client
    else
        flatpak override --user \
            --no-talk-name=org.kde.StatusNotifierWatcher \
            com.spotify.Client
    fi

    if [[ ! -f "$prefs" ]] || ! grep -q '^autologin\.username=' "$prefs"; then
        log "Fresh Spotify profile: customization deferred until the first login"
        return
    fi

    log "Applying Spicetify Sleek/Catppuccin and Marketplace to Spotify"
    if (( DRY_RUN )); then
        print_command bash "$SCRIPT_DIR/scripts/spotify-customize.sh"
        return
    fi
    bash "$SCRIPT_DIR/scripts/spotify-customize.sh"
}

install_wf_recorder() {
    (( SKIP_PACKAGES )) && return

    if command -v wf-recorder >/dev/null 2>&1; then
        log "wf-recorder is already installed"
        return
    fi

    if (( DRY_RUN )); then
        print_command sudo zypper --non-interactive install wf-recorder
        return
    fi

    log "Installing wf-recorder"
    if sudo zypper --non-interactive install wf-recorder; then
        return
    fi

    local packman_alias=""
    packman_alias=$(
        zypper lr -E 2>/dev/null \
            | awk -F'|' '
                tolower($2 " " $3) ~ /packman/ {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
                    print $2
                    exit
                }
            '
    )

    [[ -n "$packman_alias" ]] || die \
        "cannot install wf-recorder; resolve the repository vendor conflict and rerun"

    warn "Retrying installation from the enabled Packman repository ($packman_alias)"
    sudo zypper --non-interactive install \
        --allow-vendor-change \
        --from "$packman_alias" \
        wf-recorder
}

install_codex_cli() {
    if command -v codex >/dev/null 2>&1; then
        log "Codex CLI is already installed"
        return
    fi

    (( SKIP_PACKAGES )) && return

    if (( DRY_RUN )); then
        print_command sudo npm install --global --no-audit --no-fund \
            "@openai/codex@$CODEX_CLI_VERSION"
        return
    fi

    log "Installing Codex CLI $CODEX_CLI_VERSION"
    sudo npm install --global --no-audit --no-fund \
        "@openai/codex@$CODEX_CLI_VERSION"
}

require_hyprland_055() {
    (( DRY_RUN )) && return
    command -v Hyprland >/dev/null || die "Hyprland is not installed"

    local installed_version
    installed_version=$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || true)
    [[ -n "$installed_version" ]] || die "cannot determine the hyprland package version"
    if ! printf '%s\n%s\n' "0.55.0" "$installed_version" | sort -V -C; then
        die "Hyprland $installed_version is too old for this Lua configuration; update Tumbleweed with 'sudo zypper dup'"
    fi
}

make_temp_dir() {
    [[ -n "$TEMP_DIR" ]] && return
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hypr-bootstrap.XXXXXX")
}

download_checked() {
    local url=$1
    local expected=$2
    local destination=$3

    curl --fail --location --silent --show-error --retry 3 \
        --proto '=https' --tlsv1.2 "$url" --output "$destination"
    printf '%s  %s\n' "$expected" "$destination" | sha256sum --check --status \
        || die "invalid checksum for $url"
}

install_workflow_binary() {
    local name=$1 url=$2 checksum=$3
    if command -v "$name" >/dev/null 2>&1; then
        log "$name is already available; keeping the existing installation"
        return
    fi
    (( SKIP_PACKAGES )) && return
    if (( DRY_RUN )); then
        log "Would install $name in ~/.local/bin with verified SHA-256: $url"
        return
    fi
    [[ ! -e "$HOME/.local/bin/$name" && ! -L "$HOME/.local/bin/$name" ]] \
        || die "preserving existing non-executable file: $HOME/.local/bin/$name"
    make_temp_dir
    download_checked "$url" "$checksum" "$TEMP_DIR/$name"
    install -d "$HOME/.local/bin"
    install -m 0755 "$TEMP_DIR/$name" "$HOME/.local/bin/$name"
}

configure_helix() {
    # use-grammars in the deployed languages.toml limits this to the pinned
    # RPM-spec parser. All parsers shipped by the distro remain available.
    log "Preparing the Helix RPM-spec grammar"
    run hx --grammar fetch
    run hx --grammar build
}

install_grimblast() {
    if command -v grimblast >/dev/null 2>&1; then
        log "Grimblast is already available; keeping the existing installation"
        return
    fi
    if (( DRY_RUN )); then
        log "Would install official Grimblast pinned to commit $GRIMBLAST_COMMIT"
        return
    fi

    make_temp_dir
    log "Installing Grimblast"
    download_checked "$GRIMBLAST_URL" "$GRIMBLAST_SHA256" "$TEMP_DIR/grimblast"
    sudo install -m 0755 "$TEMP_DIR/grimblast" /usr/local/bin/grimblast
}

install_visual_assets() {
    (( SKIP_THEMES )) && { log "Skipping themes due to --skip-themes"; return; }
    if (( DRY_RUN )); then
        log "Would download JetBrains Mono Nerd Font, Bibata, Catppuccin GTK and Kvantum with pinned checksums"
        return
    fi

    make_temp_dir
    log "Downloading verified fonts and themes"
    download_checked "$GTK_THEME_URL" "$GTK_THEME_SHA256" "$TEMP_DIR/catppuccin-gtk.zip"
    download_checked "$NERD_FONT_URL" "$NERD_FONT_SHA256" "$TEMP_DIR/jetbrains-mono.tar.xz"
    download_checked "$BIBATA_URL" "$BIBATA_SHA256" "$TEMP_DIR/bibata.tar.xz"
    download_checked "$KVANTUM_URL" "$KVANTUM_SHA256" "$TEMP_DIR/kvantum.tar.gz"

    install -d "$HOME/.local/share/themes" "$HOME/.local/share/icons" \
        "$HOME/.local/share/fonts/JetBrainsMonoNF" "$HOME/.config/Kvantum"
    unzip -oq "$TEMP_DIR/catppuccin-gtk.zip" -d "$HOME/.local/share/themes"
    tar -xJf "$TEMP_DIR/jetbrains-mono.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNF" \
        --wildcards '*.ttf'
    tar -xJf "$TEMP_DIR/bibata.tar.xz" -C "$HOME/.local/share/icons"
    tar -xzf "$TEMP_DIR/kvantum.tar.gz" -C "$TEMP_DIR"
    rsync -a \
        "$TEMP_DIR/kvantum-${KVANTUM_COMMIT}/themes/catppuccin-mocha-peach/" \
        "$HOME/.config/Kvantum/catppuccin-mocha-peach/"
    fc-cache -f
}

backup_path() {
    local path=$1
    [[ -e "$path" || -L "$path" ]] || return 0
    local relative
    if [[ "$path" == "$HOME/"* ]]; then
        relative=${path#"$HOME"/}
    else
        relative="system/${path#/}"
    fi
    local destination="$BACKUP_DIR/$relative"

    if (( DRY_RUN )); then
        printf '  backup %s -> %s\n' "$path" "$destination"
        return
    fi
    mkdir -p "$(dirname "$destination")"
    cp -a -- "$path" "$destination"
}

backup_existing_configuration() {
    local stamp
    stamp=$(date +'%Y%m%d-%H%M%S')
    BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-bootstrap/backups/${stamp}-$$"
    log "Creating backup at $BACKUP_DIR"

    local path
    for path in \
        "$HOME/.config/hypr" \
        "$HOME/.config/waybar" \
        "$HOME/.config/eww" \
        "$HOME/.config/mako" \
        "$HOME/.config/swaync" \
        "$HOME/.config/fuzzel" \
        "$HOME/.config/ghostty" \
        "$HOME/.config/alacritty" \
        "$HOME/.config/kitty" \
        "$HOME/.config/starship.toml" \
        "$HOME/.config/helix" \
        "$HOME/.config/yazi" \
        "$HOME/.config/herdr/config.toml" \
        "$HOME/.config/wlogout" \
        "$HOME/.config/qt6ct" \
        "$HOME/.config/Kvantum" \
        "$HOME/.config/gtk-3.0" \
        "$HOME/.config/gtk-4.0" \
        "$HOME/.config/wob" \
        "$HOME/.config/swappy" \
        "$HOME/.config/udiskie" \
        "$HOME/.config/uwsm" \
        "$HOME/.config/xdg-desktop-portal" \
        "$HOME/.config/autostart/nm-applet.desktop" \
        "$HOME/.config/autostart/blueman.desktop" \
        "$HOME/.config/autostart/org.kde.kalendarac.desktop" \
        "$HOME/.config/systemd/user" \
        "$HOME/.local/state/hypr-study" \
        "$HOME/.local/share/applications/org.kde.merkuro.calendar.desktop" \
        "$HOME/.local/share/applications/hypr-study.desktop" \
        "$HOME/.local/share/Anki2/addons21/2055492159" \
        "$HOME/.local/share/Anki2/addons21/111623432" \
        "$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21/2055492159" \
        "$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21/111623432" \
        "$HOME/.var/app/com.rtosta.zapzap/config/ZapZap/ZapZap.conf" \
        "$HOME/.var/app/com.rtosta.zapzap/data/ZapZap/customizations" \
        "$HOME/.config/spicetify/config-xpui.ini" \
        "$HOME/.config/spicetify/Themes/Sleek" \
        "$HOME/.config/spicetify/CustomApps/marketplace" \
        "/usr/local/share/wayland-sessions/hyprland-uwsm.desktop" \
        "$HOME/.local/share/themes/$GTK_THEME_NAME" \
        "$HOME/.local/share/icons/Bibata-Modern-Classic" \
        "$HOME/.local/share/fonts/JetBrainsMonoNF" \
        "$HOME/Pictures/wallpapers/whales-clouds.jpg" \
        "$HOME/Pictures/wallpapers/hyprland-default.png" \
        "$HOME/Pictures/icon/avatar.jpeg"; do
        backup_path "$path"
    done
}

copy_tree() {
    local source=$1
    local destination=$2
    if [[ -e "$destination" && "$source" -ef "$destination" ]]; then
        printf '  keeping tree already at destination: %s\n' "$destination"
        return 0
    fi
    run install -d "$destination"
    run rsync -a "$source/" "$destination/"
}

install_file() {
    local mode=$1
    local source=$2
    local destination=$3
    if [[ -e "$destination" && "$source" -ef "$destination" ]]; then
        printf '  keeping file already at destination: %s\n' "$destination"
        return 0
    fi
    run install -m "$mode" "$source" "$destination"
}

deploy_configuration() {
    local hypr_target="$HOME/.config/hypr"
    log "Installing Hyprland and companion configuration"

    run install -d "$hypr_target" "$hypr_target/lua" "$hypr_target/conf.d" \
        "$hypr_target/scripts" "$hypr_target/portable/anki"
    install_file 0644 "$SCRIPT_DIR/hyprland.lua" "$hypr_target/hyprland.lua"
    install_file 0644 "$SCRIPT_DIR/hyprland.conf" "$hypr_target/hyprland.conf"
    install_file 0644 "$SCRIPT_DIR/hypridle.conf" "$hypr_target/hypridle.conf"
    install_file 0644 "$SCRIPT_DIR/hyprlock.conf" "$hypr_target/hyprlock.conf"
    install_file 0644 "$SCRIPT_DIR/hyprsunset.conf" "$hypr_target/hyprsunset.conf"
    copy_tree "$SCRIPT_DIR/lua" "$hypr_target/lua"
    copy_tree "$SCRIPT_DIR/conf.d" "$hypr_target/conf.d"
    copy_tree "$SCRIPT_DIR/scripts" "$hypr_target/scripts"
    # Keep the deployed bundle usable as an installation/reference source too.
    copy_tree "$SCRIPT_DIR/portable" "$hypr_target/portable"
    copy_tree "$SCRIPT_DIR/docs" "$hypr_target/docs"
    copy_tree "$SCRIPT_DIR/tests" "$hypr_target/tests"
    copy_tree "$SCRIPT_DIR/third-party" "$hypr_target/third-party"
    run install -d "$hypr_target/assets"
    install_file 0644 "$SCRIPT_DIR/assets/README.md" "$hypr_target/assets/README.md"
    install_file 0755 "$SCRIPT_DIR/bootstrap-opensuse-tumbleweed.sh" "$hypr_target/bootstrap-opensuse-tumbleweed.sh"
    install_file 0644 "$SCRIPT_DIR/README.md" "$hypr_target/README.md"
    install_file 0644 "$SCRIPT_DIR/WORKFLOW.md" "$hypr_target/WORKFLOW.md"
    install_file 0644 "$SCRIPT_DIR/DECISIONS.md" "$hypr_target/DECISIONS.md"
    install_file 0644 "$SCRIPT_DIR/LICENSE" "$hypr_target/LICENSE"
    install_file 0644 "$SCRIPT_DIR/NOTICE" "$hypr_target/NOTICE"
    install_file 0644 "$SCRIPT_DIR/THIRD_PARTY.md" "$hypr_target/THIRD_PARTY.md"
    install_file 0644 "$SCRIPT_DIR/.gitignore" "$hypr_target/.gitignore"
    if (( ! SAME_HARDWARE )); then
        install_file 0644 "$SCRIPT_DIR/portable/monitors-generic.lua" "$hypr_target/lua/monitors.lua"
        install_file 0644 "$SCRIPT_DIR/portable/monitors-generic.conf" "$hypr_target/conf.d/10-monitors.conf"
    fi

    copy_tree "$SCRIPT_DIR/portable/waybar" "$HOME/.config/waybar"
    copy_tree "$SCRIPT_DIR/portable/eww" "$HOME/.config/eww"
    copy_tree "$SCRIPT_DIR/portable/mako" "$HOME/.config/mako"
    copy_tree "$SCRIPT_DIR/portable/swaync" "$HOME/.config/swaync"
    copy_tree "$SCRIPT_DIR/portable/fuzzel" "$HOME/.config/fuzzel"
    copy_tree "$SCRIPT_DIR/portable/ghostty" "$HOME/.config/ghostty"
    copy_tree "$SCRIPT_DIR/portable/alacritty" "$HOME/.config/alacritty"
    copy_tree "$SCRIPT_DIR/portable/kitty" "$HOME/.config/kitty"
    install_file 0644 "$SCRIPT_DIR/portable/starship/starship.toml" "$HOME/.config/starship.toml"
    copy_tree "$SCRIPT_DIR/portable/helix" "$HOME/.config/helix"
    copy_tree "$SCRIPT_DIR/portable/yazi" "$HOME/.config/yazi"
    run install -d "$HOME/.config/herdr"
    install_file 0644 "$SCRIPT_DIR/portable/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    copy_tree "$SCRIPT_DIR/portable/wlogout" "$HOME/.config/wlogout"
    copy_tree "$SCRIPT_DIR/portable/qt6ct" "$HOME/.config/qt6ct"
    copy_tree "$SCRIPT_DIR/portable/Kvantum" "$HOME/.config/Kvantum"
    copy_tree "$SCRIPT_DIR/portable/gtk-3.0" "$HOME/.config/gtk-3.0"
    copy_tree "$SCRIPT_DIR/portable/gtk-4.0" "$HOME/.config/gtk-4.0"
    copy_tree "$SCRIPT_DIR/portable/wob" "$HOME/.config/wob"
    copy_tree "$SCRIPT_DIR/portable/swappy" "$HOME/.config/swappy"
    copy_tree "$SCRIPT_DIR/portable/udiskie" "$HOME/.config/udiskie"
    copy_tree "$SCRIPT_DIR/portable/uwsm" "$HOME/.config/uwsm"
    copy_tree "$SCRIPT_DIR/portable/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
    copy_tree "$SCRIPT_DIR/portable/autostart" "$HOME/.config/autostart"
    copy_tree "$SCRIPT_DIR/portable/systemd/user" "$HOME/.config/systemd/user"
    copy_tree "$SCRIPT_DIR/portable/applications" "$HOME/.local/share/applications"
    if command -v update-desktop-database >/dev/null 2>&1; then
        run update-desktop-database "$HOME/.local/share/applications"
    fi
    run sudo install -d -m 0755 /usr/local/share/wayland-sessions
    run sudo install -m 0644 \
        "$SCRIPT_DIR/portable/wayland-sessions/hyprland-uwsm.desktop" \
        /usr/local/share/wayland-sessions/hyprland-uwsm.desktop

    if [[ "$INTERNAL_OUTPUT" != "eDP-1" ]]; then
        local file
        for file in \
            "$hypr_target/lua/monitors.lua" \
            "$hypr_target/lua/keybinds.lua" \
            "$hypr_target/lua/autostart.lua" \
            "$hypr_target/conf.d/10-monitors.conf" \
            "$hypr_target/conf.d/80-autostart.conf" \
            "$hypr_target/conf.d/90-keybinds.conf" \
            "$hypr_target/scripts/monitor-autoswitch.sh" \
            "$hypr_target/scripts/monitor-listener.sh"; do
            run sed -i "s/eDP-1/${INTERNAL_OUTPUT}/g" "$file"
        done
    fi

    if (( DRY_RUN )); then
        print_command chmod 0755 "$hypr_target/scripts/"'*.sh' \
            "$hypr_target/scripts/spotify-tray.py" "$HOME/.config/eww/scripts/"'*.sh'
    else
        chmod 0755 "$hypr_target/scripts/"*.sh \
            "$hypr_target/scripts/spotify-tray.py" "$HOME/.config/eww/scripts/"*.sh
    fi
}

install_user_images() {
    local wallpaper_target="$HOME/Pictures/wallpapers/whales-clouds.jpg"
    local avatar_target="$HOME/Pictures/icon/avatar.jpeg"
    run install -d "$(dirname "$wallpaper_target")" "$(dirname "$avatar_target")" "$HOME/Pictures/Screenshots"

    local chosen_wallpaper="$WALLPAPER_SOURCE"
    [[ -n "$chosen_wallpaper" ]] || [[ ! -f "$SCRIPT_DIR/assets/whales-clouds.jpg" ]] || chosen_wallpaper="$SCRIPT_DIR/assets/whales-clouds.jpg"
    if [[ -n "$chosen_wallpaper" ]]; then
        install_file 0644 "$chosen_wallpaper" "$wallpaper_target"
        run sed -i 's/hyprland-default\.png/whales-clouds.jpg/g' \
            "$HOME/.config/hypr/lua/autostart.lua" \
            "$HOME/.config/hypr/conf.d/80-autostart.conf" \
            "$HOME/.config/hypr/scripts/wallpaper-apply.sh"
    elif [[ -f "$wallpaper_target" ]]; then
        log "Keeping the existing wallpaper"
    elif [[ -f /usr/share/hypr/wall0.png ]]; then
        local fallback_target="$HOME/Pictures/wallpapers/hyprland-default.png"
        install_file 0644 /usr/share/hypr/wall0.png "$fallback_target"
        run sed -i 's/whales-clouds\.jpg/hyprland-default.png/g' \
            "$HOME/.config/hypr/lua/autostart.lua" \
            "$HOME/.config/hypr/conf.d/80-autostart.conf" \
            "$HOME/.config/hypr/scripts/wallpaper-apply.sh"
        warn "original wallpaper not bundled; using /usr/share/hypr/wall0.png. Pass --wallpaper to reproduce the original image."
    else
        warn "no wallpaper available; pass --wallpaper FILE before your first login"
    fi

    local chosen_avatar="$AVATAR_SOURCE"
    [[ -n "$chosen_avatar" ]] || [[ ! -f "$SCRIPT_DIR/assets/avatar.jpeg" ]] || chosen_avatar="$SCRIPT_DIR/assets/avatar.jpeg"
    if [[ -n "$chosen_avatar" ]]; then
        install_file 0644 "$chosen_avatar" "$avatar_target"
    elif [[ ! -f "$avatar_target" ]]; then
        warn "Eww avatar not installed; use --avatar to fill the header circle"
    fi
}

apply_desktop_theme() {
    (( SKIP_THEMES )) && return
    (( DRY_RUN )) && { log "Would apply Catppuccin/Bibata/Papirus through GTK, Qt and gsettings"; return; }

    local gtk4_theme="$HOME/.local/share/themes/$GTK_THEME_NAME/gtk-4.0"
    if [[ -d "$gtk4_theme" ]]; then
        rsync -a "$gtk4_theme/" "$HOME/.config/gtk-4.0/"
    fi

    if command -v gsettings >/dev/null && gsettings list-schemas | grep -qx org.gnome.desktop.interface; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME"
        gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
        gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic
        gsettings set org.gnome.desktop.interface cursor-size 28
    fi
}

reload_user_units() {
    local units=(
        awww.service swaync.service eww.service desktop-controls.service focus-timer.service udiskie.service
        cliphist.service monitor-listener.service nm-applet.service kwalletd.service
        smarty-pants.service kalendarac.service dankcalendar.service spotify-tray.service
        steam-tray.service calendar-tray.service
        portal-healthcheck.timer
        waybar.service hypridle.service hyprsunset.service
        hyprpolkitagent.service
    )
    if (( DRY_RUN )); then
        print_command systemctl --user daemon-reload
        print_command systemctl --user disable mako.service wob.service
        print_command systemctl --user enable "${units[@]}"
        return
    fi
    if systemctl --user daemon-reload; then
        systemctl --user disable mako.service wob.service \
            || warn "cannot disable legacy notification/OSD units"
        systemctl --user enable "${units[@]}" \
            || warn "cannot enable all units; repeat 'systemctl --user enable ...' after login"
    else
        warn "cannot reload user systemd; do this after logging into the session"
    fi
}

validate_result() {
    (( DRY_RUN )) && return
    log "Validating installed files"

    local script
    for script in "$HOME/.config/hypr/scripts/"*.sh "$HOME/.config/eww/scripts/"*.sh; do
        bash -n "$script"
    done
    jq empty "$HOME/.config/waybar/config.jsonc"
    jq -e '.version == 1 and (.decks | type == "array")' \
        "$HOME/.config/hypr/portable/anki/starter-decks.json" >/dev/null

    if ! Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"; then
        die "Hyprland rejected the installed configuration; restore the backup at $BACKUP_DIR"
    fi

    local required_commands=(
        Hyprland hypridle hyprlock hyprsunset hyprpolkitagent awww-daemon waybar swaync swaync-client eww fuzzel
        ghostty alacritty kitty starship helix hx yazi herdr marksman glow pandoc wl-paste cliphist grimblast wpctl brightnessctl playerctl
        pdftoppm file fd rg fzf zoxide 7zz magick chafa resvg ffmpeg
        lua-language-server texlab taplo shfmt shellcheck gcc
        nmcli nm-applet blueman-manager pavucontrol pactl notify-send jq socat busctl wlogout
        wob swappy wf-recorder udiskie uwsm nwg-displays btop
        merkuro-calendar korganizer kalendarac konsolekalendar kdialog python3 codex
    )
    local missing=()
    local command_name
    for command_name in "${required_commands[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    (( ${#missing[@]} == 0 )) || die "commands missing after installation: ${missing[*]}"

    hx --health markdown
    hx --health rpmspec
    herdr config check

    if ! command -v dcal >/dev/null 2>&1 \
        && { ! command -v flatpak >/dev/null 2>&1 \
            || ! flatpak info com.danklinux.dankcalendar >/dev/null 2>&1; }; then
        die "DankCalendar missing after installation"
    fi
    if ! command -v anki >/dev/null 2>&1 \
        && { ! command -v flatpak >/dev/null 2>&1 \
            || ! flatpak info net.ankiweb.Anki >/dev/null 2>&1; }; then
        die "Anki missing after installation"
    fi
    if ! flatpak info com.rtosta.zapzap >/dev/null 2>&1; then
        die "ZapZap missing after installation"
    fi
    flatpak info --user com.spotify.Client >/dev/null 2>&1 \
        || die "User-scoped Spotify Flatpak missing after installation"
    [[ -f "$HOME/.var/app/com.rtosta.zapzap/data/ZapZap/customizations/global/css/catppuccin-mocha-peach.css" ]] \
        || die "ZapZap theme missing after installation"

    local spotify_prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
    if [[ -f "$spotify_prefs" ]] \
        && grep -q '^autologin\.username=' "$spotify_prefs"; then
        local spicetify_config="$HOME/.config/spicetify/config-xpui.ini"
        [[ -x "$HOME/.spicetify/spicetify" ]] \
            || die "Spicetify missing after installation"
        [[ -f "$HOME/.config/spicetify/Themes/Sleek/user.css" ]] \
            || die "Sleek theme missing after installation"
        [[ -f "$HOME/.config/spicetify/CustomApps/marketplace/manifest.json" ]] \
            || die "Spicetify Marketplace missing after installation"
        grep -Eq '^current_theme[[:space:]]*=[[:space:]]*Sleek$' "$spicetify_config" \
            || die "Sleek theme was not enabled"
        grep -Eq '^color_scheme[[:space:]]*=[[:space:]]*Catppuccin$' "$spicetify_config" \
            || die "Catppuccin color scheme was not enabled"
    fi

    if ! python3 - <<'PY'
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gio, Gtk, GtkLayerShell
PY
    then
        die "GTK Spotify popup integration unavailable"
    fi
}

report_service_state() {
    (( DRY_RUN )) && return
    systemctl is-active --quiet NetworkManager.service \
        || warn "NetworkManager is not active; check your network manager before running 'sudo systemctl enable --now NetworkManager'"
    systemctl is-active --quiet bluetooth.service \
        || warn "Bluetooth is not active; if needed, run 'sudo systemctl enable --now bluetooth'"
}

finish() {
    log "Configuration complete"
    printf 'Backup: %s\n' "$BACKUP_DIR"
    cat <<'EOF'

Next steps:
  1. Log out and select "Hyprland (UWSM)" in the display manager.
  2. Run `hyprctl monitors` and adjust ~/.config/hypr/lua/monitors.lua.
  3. Import VPN profiles; credentials and KWallet data are not copied.
  4. Run `codex login`. Add Google and personal Outlook in DankCalendar's
     Accounts panel, or run these commands from ~/.config/hypr/scripts:
     `./dcal.sh account add google`
     `./dcal.sh account add microsoft`
     OAuth accounts/tokens are not copied; Proton is available on the web.
  5. Handy.AppImage and smarty-pants-daemon are optional personal integrations;
     their shortcuts do nothing when the binaries are unavailable.
  6. Open Study Hub with Super+Shift+A. On first use, Anki prepares the curated
     decks and French audio. Sign in to AnkiWeb and sync manually to transfer
     your collection. Personal collection, login and media are not copied.
  7. Open ZapZap through Fuzzel, complete the setup wizard and scan the QR code
     with WhatsApp on your phone. Sessions, messages and downloads are not copied.
  8. Open Spotify with Super+M. On a fresh installation, sign in, wait at least
     60 seconds, then run ~/.config/hypr/scripts/spotify-customize.sh.
     Already-authenticated profiles receive Sleek/Catppuccin and Marketplace
     automatically. Super+Q hides Spotify while it keeps playing; Super+M
     restores it. Click the tray icon for artwork, playback, seek and volume
     controls. Use the popup's Quit Spotify action to exit the client.
  9. Super+E opens Yazi; text opens in Helix, and O offers Glow reading for
     Markdown. Start with hx --tutor and see ~/.config/hypr/WORKFLOW.md.
     Herdr is optional: run herdr inside Ghostty. Transfer projects,
     bibliographies and personal sessions separately.

The script does not automatically switch network services or edit PAM, to
avoid disrupting remote connections or login. KWallet works, but automatic
unlocking depends on the target machine's PAM configuration.

EOF
}

main() {
    validate_host
    # openSUSE adds ~/.local/bin at the next login; also use it in this run.
    export PATH="$HOME/.local/bin:$PATH"
    install_packages
    install_dankcalendar
    install_zen
    install_spotify
    install_zapzap
    install_anki
    install_wf_recorder
    install_codex_cli
    require_hyprland_055
    install_grimblast
    backup_existing_configuration
    install_workflow_binary herdr "$HERDR_URL" "$HERDR_SHA256"
    install_workflow_binary marksman "$MARKSMAN_URL" "$MARKSMAN_SHA256"
    install_anki_addons
    install_visual_assets
    deploy_configuration
    configure_helix
    configure_spotify
    configure_zapzap
    configure_zen
    configure_obsidian
    run python3 "$SCRIPT_DIR/scripts/configure-app-trays.py"
    install_user_images
    apply_desktop_theme
    reload_user_units
    validate_result
    report_service_state
    finish
}

main "$@"
