#!/usr/bin/env bash
set -euo pipefail
df / --output=pcent | tail -1 | tr -d ' %'
