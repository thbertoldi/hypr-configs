#!/usr/bin/env bash
# Print current xkb layout short code for waybar custom module.
# Looks at the first keyboard with a non-empty active_keymap.

layout=$(hyprctl -j devices 2>/dev/null \
    | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in data.get("keyboards", []):
    name = k.get("active_keymap", "")
    if name:
        print(name)
        break
' 2>/dev/null)

case "$layout" in
    *"Portuguese (Brazil"*|*"Brazil"*) echo "BR" ;;
    *"English"*|*"US"*)                echo "US" ;;
    *)                                 echo "${layout:0:2}" ;;
esac
