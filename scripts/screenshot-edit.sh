#!/usr/bin/env bash
set -euo pipefail

geometry=$(slurp) || exit 0
[[ -n "$geometry" ]] || exit 0

grim -g "$geometry" - | swappy -f -
