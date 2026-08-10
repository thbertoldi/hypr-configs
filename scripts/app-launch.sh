#!/usr/bin/env bash
set -euo pipefail

if (( $# == 0 )); then
    printf 'uso: %s COMANDO [ARGUMENTOS...]\n' "${0##*/}" >&2
    exit 64
fi

if command -v uwsm >/dev/null 2>&1; then
    exec uwsm app -- "$@"
fi

exec "$@"
