#!/usr/bin/env bash
set -euo pipefail

readonly app_id='com.danklinux.dankcalendar'

# Prefer a native installation when one exists.  On Tumbleweed the portable
# setup installs the official Flathub build, so the same commands work in both
# environments without leaking Flatpak details into widgets and keybinds.
if command -v dcal >/dev/null 2>&1; then
    exec dcal "$@"
fi

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info "$app_id" >/dev/null 2>&1; then
    flatpak_args=(run)
    if [[ "${1:-}" == run ]] && printf '%s\n' "$@" | grep -qx -- '--session'; then
        # Keep a service-launched sandbox tied to its systemd parent.  Flatpak
        # otherwise moves the app into a transient scope that survives a
        # service restart and leaves duplicate sync/reminder daemons behind.
        flatpak_args+=(--die-with-parent)
    fi
    exec flatpak "${flatpak_args[@]}" "$app_id" "$@"
fi

printf 'DankCalendar não está instalado (aplicativo %s).\n' "$app_id" >&2
exit 127
