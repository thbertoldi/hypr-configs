#!/usr/bin/env bash
# Print current xkb layout short code for waybar custom module.
# Looks at the first keyboard with a non-empty active_keymap.

layout=$(hyprctl -j devices 2>/dev/null \
    | jq -r '[.keyboards[]?.active_keymap | select(length > 0)][0] // empty' \
    2>/dev/null)

case "$layout" in
    *"Portuguese (Brazil"*|*"Brazil"*) echo "BR" ;;
    *"English"*|*"US"*)                echo "US" ;;
    *)                                 echo "${layout:0:2}" ;;
esac
