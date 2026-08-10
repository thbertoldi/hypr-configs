#!/usr/bin/env bash
set -euo pipefail

if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
    exec uwsm stop
fi

exec hyprctl dispatch exit
