#!/usr/bin/env bash
# Reproduce this Hyprland desktop on openSUSE Tumbleweed.
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

usage() {
    cat <<'EOF'
Uso:
  ./bootstrap-opensuse-tumbleweed.sh [opções]

Opções:
  --wallpaper ARQUIVO  Copia a imagem para o caminho usado pelo awww.
  --avatar ARQUIVO     Copia a imagem para o avatar do painel Eww.
  --same-hardware      Mantém o perfil LG ultrawide + eDP desta máquina.
                       Sem esta opção, instala um perfil genérico seguro.
  --internal-output N  Troca eDP-1 pelo nome do painel interno informado.
  --with-extras        Instala o utilitário diagnóstico Wayland `wev`.
  --skip-packages      Não executa zypper (útil se tudo já estiver instalado).
  --skip-themes        Não baixa fontes, cursor e temas GTK/Kvantum.
  --dry-run            Mostra as ações sem modificar o computador.
  -h, --help           Exibe esta ajuda.

Exemplo:
  ./bootstrap-opensuse-tumbleweed.sh \
    --wallpaper ~/Downloads/whales-clouds.jpg \
    --avatar ~/Pictures/avatar.jpeg
EOF
}

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'AVISO: %s\n' "$*" >&2
}

die() {
    printf 'ERRO: %s\n' "$*" >&2
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
            *) warn "Diretório temporário inesperado preservado: $TEMP_DIR" ;;
        esac
    fi
}

on_error() {
    local status=$?
    printf 'ERRO: falha na linha %s (status %s): %s\n' "${BASH_LINENO[0]}" "$status" "$BASH_COMMAND" >&2
    exit "$status"
}

trap cleanup EXIT
trap on_error ERR

while (( $# )); do
    case "$1" in
        --wallpaper)
            (( $# >= 2 )) || die "--wallpaper requer um arquivo"
            WALLPAPER_SOURCE=$2
            shift 2
            ;;
        --avatar)
            (( $# >= 2 )) || die "--avatar requer um arquivo"
            AVATAR_SOURCE=$2
            shift 2
            ;;
        --internal-output)
            (( $# >= 2 )) || die "--internal-output requer um nome"
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
            die "opção desconhecida: $1"
            ;;
    esac
done

validate_host() {
    [[ $EUID -ne 0 ]] || die "execute como usuário normal; o script chama sudo somente quando necessário"
    [[ -r /etc/os-release ]] || die "/etc/os-release não encontrado"

    local os_id
    os_id=$( ( . /etc/os-release; printf '%s' "${ID:-}" ) )
    [[ "$os_id" == "opensuse-tumbleweed" ]] || die "este instalador requer openSUSE Tumbleweed (ID atual: ${os_id:-desconhecido})"

    [[ "$INTERNAL_OUTPUT" =~ ^[A-Za-z0-9_.:-]+$ ]] || die "nome de saída inválido: $INTERNAL_OUTPUT"
    [[ -z "$WALLPAPER_SOURCE" || -f "$WALLPAPER_SOURCE" ]] || die "wallpaper não encontrado: $WALLPAPER_SOURCE"
    [[ -z "$AVATAR_SOURCE" || -f "$AVATAR_SOURCE" ]] || die "avatar não encontrado: $AVATAR_SOURCE"

    local required_source
    for required_source in \
        "$SCRIPT_DIR/hyprland.lua" \
        "$SCRIPT_DIR/hypridle.conf" \
        "$SCRIPT_DIR/hyprlock.conf" \
        "$SCRIPT_DIR/hyprsunset.conf" \
        "$SCRIPT_DIR/lua/autostart.lua" \
        "$SCRIPT_DIR/scripts/agent-menu.sh" \
        "$SCRIPT_DIR/scripts/calendar-open.sh" \
        "$SCRIPT_DIR/scripts/dcal.sh" \
        "$SCRIPT_DIR/scripts/monitor-listener.sh" \
        "$SCRIPT_DIR/portable/waybar/config.jsonc" \
        "$SCRIPT_DIR/portable/eww/eww.yuck" \
        "$SCRIPT_DIR/portable/eww/scripts/calendar-list.sh" \
        "$SCRIPT_DIR/portable/applications/org.kde.merkuro.calendar.desktop" \
        "$SCRIPT_DIR/portable/xdg-desktop-portal/hyprland-portals.conf" \
        "$SCRIPT_DIR/portable/systemd/user/hyprland-session.target" \
        "$SCRIPT_DIR/portable/systemd/user/dankcalendar.service" \
        "$SCRIPT_DIR/portable/wayland-sessions/hyprland-uwsm.desktop" \
        "$SCRIPT_DIR/portable/monitors-generic.lua"; do
        [[ -f "$required_source" ]] || die "bundle incompleto; falta $required_source"
    done
}

install_packages() {
    (( SKIP_PACKAGES )) && { log "Pacotes ignorados por --skip-packages"; return; }

    local packages=(
        hyprland hyprland-wallpapers hypridle hyprlock hyprpicker awww
        waybar mako eww fuzzel wlogout
        xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        polkit hyprpolkitagent kwalletd6 pam_kwallet6
        NetworkManager NetworkManager-applet NetworkManager-connection-editor
        NetworkManager-openvpn NetworkManager-applet-openvpn
        bluez blueman
        pipewire pipewire-pulseaudio wireplumber pavucontrol
        power-profiles-daemon upower hyprsunset wob
        wl-clipboard cliphist grim slurp
        brightnessctl playerctl swappy udiskie
        uwsm inotify-tools nwg-displays btop flatpak
        merkuro korganizer kalendarac kdepim-runtime akonadi-calendar-tools kaccounts-integration
        kaccounts-providers libkgapi6 kdialog
        nodejs24 npm24
        ghostty nnn MozillaFirefox helix
        qt6ct kvantum-manager kvantum-qt6
        papirus-icon-theme fontawesome-fonts symbols-only-nerd-fonts
        google-noto-sans-fonts google-noto-coloremoji-fonts
        libnotify-tools
        jq socat curl unzip xz tar rsync git procps gawk dbus-1-tools glib2-tools
        xdg-user-dirs
    )
    local extras=(wev)

    log "Atualizando metadados dos repositórios"
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
        log "DankCalendar nativo já instalado"
        return
    fi

    if (( DRY_RUN )); then
        log "Instalando DankCalendar pelo Flathub para o usuário atual"
        print_command flatpak --user remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
        print_command flatpak --user install --noninteractive flathub "$app_id"
        return
    fi

    command -v flatpak >/dev/null 2>&1 \
        || die "flatpak não está disponível após a instalação de pacotes"
    if flatpak info "$app_id" >/dev/null 2>&1; then
        log "DankCalendar Flatpak já instalado"
        return
    fi

    log "Instalando DankCalendar pelo Flathub para o usuário atual"
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install --noninteractive flathub "$app_id"
}

install_wf_recorder() {
    (( SKIP_PACKAGES )) && return

    if command -v wf-recorder >/dev/null 2>&1; then
        log "wf-recorder já está instalado"
        return
    fi

    if (( DRY_RUN )); then
        print_command sudo zypper --non-interactive install wf-recorder
        return
    fi

    log "Instalando wf-recorder"
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
        "não foi possível instalar wf-recorder; resolva o conflito de fornecedores dos repositórios e execute novamente"

    warn "Repetindo a instalação pelo repositório Packman habilitado ($packman_alias)"
    sudo zypper --non-interactive install \
        --allow-vendor-change \
        --from "$packman_alias" \
        wf-recorder
}

install_codex_cli() {
    if command -v codex >/dev/null 2>&1; then
        log "Codex CLI já está instalado"
        return
    fi

    (( SKIP_PACKAGES )) && return

    if (( DRY_RUN )); then
        print_command sudo npm install --global --no-audit --no-fund \
            "@openai/codex@$CODEX_CLI_VERSION"
        return
    fi

    log "Instalando Codex CLI $CODEX_CLI_VERSION"
    sudo npm install --global --no-audit --no-fund \
        "@openai/codex@$CODEX_CLI_VERSION"
}

require_hyprland_055() {
    (( DRY_RUN )) && return
    command -v Hyprland >/dev/null || die "Hyprland não está instalado"

    local installed_version
    installed_version=$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || true)
    [[ -n "$installed_version" ]] || die "não foi possível determinar a versão do pacote hyprland"
    if ! printf '%s\n%s\n' "0.55.0" "$installed_version" | sort -V -C; then
        die "Hyprland $installed_version é antigo para esta configuração Lua; atualize o snapshot do Tumbleweed com 'sudo zypper dup'"
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
        || die "checksum inválido para $url"
}

install_grimblast() {
    if command -v grimblast >/dev/null 2>&1; then
        log "Grimblast já está disponível; mantendo a instalação existente"
        return
    fi
    if (( DRY_RUN )); then
        log "Instalaria o Grimblast oficial fixado no commit $GRIMBLAST_COMMIT"
        return
    fi

    make_temp_dir
    log "Instalando Grimblast"
    download_checked "$GRIMBLAST_URL" "$GRIMBLAST_SHA256" "$TEMP_DIR/grimblast"
    sudo install -m 0755 "$TEMP_DIR/grimblast" /usr/local/bin/grimblast
}

install_visual_assets() {
    (( SKIP_THEMES )) && { log "Temas ignorados por --skip-themes"; return; }
    if (( DRY_RUN )); then
        log "Baixaria JetBrains Mono Nerd Font, Bibata, Catppuccin GTK e Catppuccin Kvantum com checksums fixados"
        return
    fi

    make_temp_dir
    log "Baixando fontes e temas verificados"
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
    log "Criando backup em $BACKUP_DIR"

    local path
    for path in \
        "$HOME/.config/hypr" \
        "$HOME/.config/waybar" \
        "$HOME/.config/eww" \
        "$HOME/.config/mako" \
        "$HOME/.config/fuzzel" \
        "$HOME/.config/ghostty" \
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
        "$HOME/.local/share/applications/org.kde.merkuro.calendar.desktop" \
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
        printf '  mantendo árvore já posicionada: %s\n' "$destination"
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
        printf '  mantendo arquivo já posicionado: %s\n' "$destination"
        return 0
    fi
    run install -m "$mode" "$source" "$destination"
}

deploy_configuration() {
    local hypr_target="$HOME/.config/hypr"
    log "Instalando Hyprland e configurações auxiliares"

    run install -d "$hypr_target" "$hypr_target/lua" "$hypr_target/conf.d" "$hypr_target/scripts"
    install_file 0644 "$SCRIPT_DIR/hyprland.lua" "$hypr_target/hyprland.lua"
    install_file 0644 "$SCRIPT_DIR/hyprland.conf" "$hypr_target/hyprland.conf"
    install_file 0644 "$SCRIPT_DIR/hypridle.conf" "$hypr_target/hypridle.conf"
    install_file 0644 "$SCRIPT_DIR/hyprlock.conf" "$hypr_target/hyprlock.conf"
    install_file 0644 "$SCRIPT_DIR/hyprsunset.conf" "$hypr_target/hyprsunset.conf"
    copy_tree "$SCRIPT_DIR/lua" "$hypr_target/lua"
    copy_tree "$SCRIPT_DIR/conf.d" "$hypr_target/conf.d"
    copy_tree "$SCRIPT_DIR/scripts" "$hypr_target/scripts"

    if (( ! SAME_HARDWARE )); then
        install_file 0644 "$SCRIPT_DIR/portable/monitors-generic.lua" "$hypr_target/lua/monitors.lua"
        install_file 0644 "$SCRIPT_DIR/portable/monitors-generic.conf" "$hypr_target/conf.d/10-monitors.conf"
    fi

    copy_tree "$SCRIPT_DIR/portable/waybar" "$HOME/.config/waybar"
    copy_tree "$SCRIPT_DIR/portable/eww" "$HOME/.config/eww"
    copy_tree "$SCRIPT_DIR/portable/mako" "$HOME/.config/mako"
    copy_tree "$SCRIPT_DIR/portable/fuzzel" "$HOME/.config/fuzzel"
    copy_tree "$SCRIPT_DIR/portable/ghostty" "$HOME/.config/ghostty"
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
        print_command chmod 0755 "$hypr_target/scripts/"'*.sh' "$HOME/.config/eww/scripts/"'*.sh'
    else
        chmod 0755 "$hypr_target/scripts/"*.sh "$HOME/.config/eww/scripts/"*.sh
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
        log "Mantendo wallpaper já existente"
    elif [[ -f /usr/share/hypr/wall0.png ]]; then
        local fallback_target="$HOME/Pictures/wallpapers/hyprland-default.png"
        install_file 0644 /usr/share/hypr/wall0.png "$fallback_target"
        run sed -i 's/whales-clouds\.jpg/hyprland-default.png/g' \
            "$HOME/.config/hypr/lua/autostart.lua" \
            "$HOME/.config/hypr/conf.d/80-autostart.conf" \
            "$HOME/.config/hypr/scripts/wallpaper-apply.sh"
        warn "wallpaper original não veio no bundle; usando /usr/share/hypr/wall0.png. Passe --wallpaper para reproduzir a imagem atual."
    else
        warn "nenhum wallpaper disponível; passe --wallpaper ARQUIVO antes do primeiro login"
    fi

    local chosen_avatar="$AVATAR_SOURCE"
    [[ -n "$chosen_avatar" ]] || [[ ! -f "$SCRIPT_DIR/assets/avatar.jpeg" ]] || chosen_avatar="$SCRIPT_DIR/assets/avatar.jpeg"
    if [[ -n "$chosen_avatar" ]]; then
        install_file 0644 "$chosen_avatar" "$avatar_target"
    elif [[ ! -f "$avatar_target" ]]; then
        warn "avatar do Eww não instalado; use --avatar para preencher o círculo do cabeçalho"
    fi
}

apply_desktop_theme() {
    (( SKIP_THEMES )) && return
    (( DRY_RUN )) && { log "Aplicaria Catppuccin/Bibata/Papirus via GTK, Qt e gsettings"; return; }

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
        awww.service mako.service eww.service wob.service udiskie.service
        cliphist.service monitor-listener.service nm-applet.service kwalletd.service
        smarty-pants.service kalendarac.service dankcalendar.service waybar.service hypridle.service hyprsunset.service
        hyprpolkitagent.service
    )
    if (( DRY_RUN )); then
        print_command systemctl --user daemon-reload
        print_command systemctl --user enable "${units[@]}"
        return
    fi
    if systemctl --user daemon-reload; then
        systemctl --user enable "${units[@]}" \
            || warn "não foi possível habilitar todas as unidades; repita 'systemctl --user enable ...' após o login"
    else
        warn "não foi possível recarregar o systemd do usuário; faça isso após entrar na sessão"
    fi
}

validate_result() {
    (( DRY_RUN )) && return
    log "Validando arquivos instalados"

    local script
    for script in "$HOME/.config/hypr/scripts/"*.sh "$HOME/.config/eww/scripts/"*.sh; do
        bash -n "$script"
    done
    jq empty "$HOME/.config/waybar/config.jsonc"

    if ! Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"; then
        die "Hyprland rejeitou a configuração instalada; restaure o backup em $BACKUP_DIR"
    fi

    local required_commands=(
        Hyprland hypridle hyprlock hyprsunset hyprpolkitagent awww-daemon waybar mako eww fuzzel
        ghostty nnn wl-paste cliphist grimblast wpctl brightnessctl playerctl
        nmcli nm-applet blueman-manager pavucontrol notify-send jq socat wlogout
        wob swappy wf-recorder udiskie uwsm nwg-displays btop
        merkuro-calendar korganizer kalendarac konsolekalendar kdialog python3 codex
    )
    local missing=()
    local command_name
    for command_name in "${required_commands[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done
    (( ${#missing[@]} == 0 )) || die "comandos ausentes após a instalação: ${missing[*]}"

    if ! command -v dcal >/dev/null 2>&1 \
        && { ! command -v flatpak >/dev/null 2>&1 \
            || ! flatpak info com.danklinux.dankcalendar >/dev/null 2>&1; }; then
        die "DankCalendar ausente após a instalação"
    fi
}

report_service_state() {
    (( DRY_RUN )) && return
    systemctl is-active --quiet NetworkManager.service \
        || warn "NetworkManager não está ativo; confirme seu gerenciador de rede antes de executar 'sudo systemctl enable --now NetworkManager'"
    systemctl is-active --quiet bluetooth.service \
        || warn "Bluetooth não está ativo; se necessário execute 'sudo systemctl enable --now bluetooth'"
}

finish() {
    log "Configuração concluída"
    printf 'Backup: %s\n' "$BACKUP_DIR"
    cat <<'EOF'

Próximos passos:
  1. Termine a sessão e escolha "Hyprland (UWSM)" no gerenciador de login.
  2. Execute `hyprctl monitors` e ajuste ~/.config/hypr/lua/monitors.lua.
  3. Importe os perfis VPN; credenciais e KWallet não são copiados.
  4. Execute `codex login`. Depois adicione Google e Outlook pessoal pelo
     painel Contas do DankCalendar ou, dentro de ~/.config/hypr/scripts,
     execute `./dcal.sh account add google` e
     `./dcal.sh account add microsoft`.
     OAuth, contas e tokens não são copiados; Proton fica disponível pela web.
  5. Handy.AppImage e smarty-pants-daemon são integrações pessoais opcionais;
     os atalhos ficam inertes quando os binários não existem.

O script não troca automaticamente o serviço de rede nem altera PAM, evitando
derrubar uma conexão remota ou bloquear o login. KWallet funciona, mas o
desbloqueio automático depende da configuração PAM da máquina de destino.
EOF
}

main() {
    validate_host
    install_packages
    install_dankcalendar
    install_wf_recorder
    install_codex_cli
    require_hyprland_055
    install_grimblast
    backup_existing_configuration
    install_visual_assets
    deploy_configuration
    install_user_images
    apply_desktop_theme
    reload_user_units
    validate_result
    report_service_state
    finish
}

main "$@"
