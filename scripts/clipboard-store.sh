#!/usr/bin/env bash
set -euo pipefail

cliphist store
eww poll clipboard >/dev/null 2>&1 || true
