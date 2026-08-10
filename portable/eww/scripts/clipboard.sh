#!/usr/bin/env bash
set -euo pipefail

list_items() {
    cliphist list | jq -Rsc '
      split("\n")
      | map(select(length > 0))[:6]
      | map(capture("^(?<id>[0-9]+)\\t(?<preview>.*)$")
          | .preview |= (gsub("[[:space:]]+"; " ") | if length > 62 then .[:59] + "…" else . end))'
}

refresh() {
    eww poll clipboard >/dev/null 2>&1 || true
}

case "${1:-list}" in
    list) list_items ;;
    copy)
        id=${2:-}
        [[ "$id" =~ ^[0-9]+$ ]] || exit 64
        printf '%s\t\n' "$id" | cliphist decode | wl-copy
        refresh
        ;;
    delete)
        id=${2:-}
        [[ "$id" =~ ^[0-9]+$ ]] || exit 64
        printf '%s\t\n' "$id" | cliphist delete
        refresh
        ;;
    *)
        printf 'uso: %s {list|copy ID|delete ID}\n' "${0##*/}" >&2
        exit 64
        ;;
esac
