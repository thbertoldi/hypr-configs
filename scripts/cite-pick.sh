#!/usr/bin/env bash
# Pick a real BibTeX/BibLaTeX key and copy a Pandoc citation to Wayland.
# Run in a terminal pane; this does not edit the bibliography or manuscript.
set -Eeuo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    printf 'Usage: %s path/to/references.bib\nPick by key, author, year or title; paste in Helix with Space p.\n' "$0"
    exit 0
fi
if [[ $# -ne 1 || ! -r "$1" || ! -f "$1" ]]; then
    printf 'Provide one readable .bib file. Use --help for usage.\n' >&2
    exit 2
fi
for command_name in pandoc jq fzf wl-copy; do
    command -v "$command_name" >/dev/null || {
        printf 'Missing command: %s\n' "$command_name" >&2
        exit 1
    }
done

# Pandoc handles multiline fields, escaped characters and BibTeX syntax.
# Parse before opening the picker so a bad bibliography cannot copy a result.
entries=$(pandoc --from=biblatex --to=csljson -- "$1" | jq -r '
    sort_by(.id)[] | [
        .id,
        ([.author[]? | .family // .literal // .given // ""] | join(", ")),
        (.issued["date-parts"][0][0] // "" | tostring),
        (.title // "")
    ] | @tsv
')
if [[ -z "$entries" ]]; then
    printf 'No bibliography entries found.\n' >&2
    exit 1
fi
if selected=$(printf '%s\n' "$entries" | fzf --delimiter='\t' \
    --height=80% --layout=reverse --prompt='Cite > ' \
    --header='Key | authors | year | title — Enter copies; Esc cancels'); then
    printf -v citation '[@%s]' "${selected%%$'\t'*}"
    printf '%s' "$citation" | wl-copy
    printf 'Copied %s\n' "$citation"
else
    status=$?
    # A cancelled picker must leave the clipboard unchanged.
    [[ $status == 1 || $status == 130 ]] || exit "$status"
fi
