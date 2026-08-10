#!/usr/bin/env bash
set -euo pipefail
free | awk '/Mem:/ { printf("%d\n", $3*100/$2) }'
