#!/usr/bin/env bash
# Keep the laptop panel available unless an external monitor has a usable mode.
# A disconnected display, Hyprland's virtual FALLBACK output, or a failed 0x0
# modeset must not leave the laptop panel disabled. DPMS-off displays still
# count as usable, so normal idle blanking does not turn the laptop panel on.
set -euo pipefail

# Wake first, then allow the HDMI link to disconnect/reconnect before checking.
# The listener also runs this check on hotplug; --wake covers missed events.
case "${1:-}" in
    --wake)
        hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
        sleep 3
        ;;
    "") ;;
    *) printf 'Usage: %s [--wake]\n' "$0" >&2; exit 2 ;;
esac

# Lid events and the monitor listener can arrive together. One reconciliation
# owns the transition; its fresh snapshots also see events arriving while it waits.
exec 9>"${XDG_RUNTIME_DIR:?}/hypr-monitor-autoswitch.lock"
flock -n 9 || exit 0

# A compositor on an inactive VT cannot apply DRM modes. Do not mistake that
# for a failed wake or try to take the seat back from the user's text console.
display_session=$(loginctl show-user "$UID" -p Display --value)
[[ -n "$display_session" ]] || exit 0
[[ $(loginctl show-session "$display_session" -p Active --value) == "yes" ]] || exit 0

read_state() {
    monitors=$(hyprctl monitors all -j) || return 1
    [[ -n "$monitors" ]] || return 1
    jq -e 'type == "array"' <<< "$monitors" >/dev/null || return 1
    external=$(jq -r 'any(.[];
        .name != "eDP-1" and .name != "FALLBACK" and
        .disabled == false and .width > 0 and .height > 0
    )' <<< "$monitors")
    broken=$(jq -r 'any(.[];
        .name != "eDP-1" and .name != "FALLBACK" and
        .disabled == false and .dpmsStatus == true and
        (.width <= 0 or .height <= 0)
    )' <<< "$monitors")
    asleep=$(jq -r 'any(.[];
        .name != "eDP-1" and .name != "FALLBACK" and
        .disabled == false and .dpmsStatus == false
    )' <<< "$monitors")
    panel=$(jq -r '[.[] | select(.name == "eDP-1")] | first |
        if . == null then "missing"
        elif .disabled then "disabled"
        elif .width > 0 and .height > 0 then "enabled"
        else "unconfigured" end
    ' <<< "$monitors")
}

# A successful IPC reply only means the command was accepted. In the observed
# 0x0 failure, monitor eval commands returned "ok" without changing the output;
# reloading the saved configuration restored its mode. Bound retries across
# queued hotplug events so a persistent driver failure cannot cause a loop.
refresh_config() {
    local last_attempt=0
    local stamp="$XDG_RUNTIME_DIR/hypr-monitor-recovery.at"
    if [[ -r "$stamp" ]]; then
        read -r last_attempt < "$stamp" || last_attempt=0
    fi
    [[ "$last_attempt" =~ ^[0-9]+$ ]] || last_attempt=0
    if (( EPOCHSECONDS - last_attempt < 30 )); then
        return 1
    fi
    printf '%s\n' "$EPOCHSECONDS" > "$stamp"
    printf 'Refreshing Hyprland configuration after an unusable display mode.\n' >&2
    if ! hyprctl reload config-only; then
        printf 'Display configuration refresh failed.\n' >&2
        return 1
    fi
    sleep 1
}

read_state
[[ "$external" == "false" && "$broken" == "false" && "$asleep" == "true" ]] && exit 0

# HDMI can disappear for about two seconds while waking from DPMS. Switching
# immediately creates FALLBACK -> eDP -> HDMI churn and races Waybar's initial
# layer configuration. Give the link three seconds to return before undocking.
# A real unplug or failed modeset still enables the laptop after that grace period.
if [[ "$broken" == "true" || ( "$external" == "false" && "$panel" != "missing" && "$panel" != "enabled" ) ]]; then
    for _attempt in 1 2 3; do
        sleep 1
        read_state
        [[ "$broken" == "false" && ( "$external" == "true" || "$panel" == "missing" || "$panel" == "enabled" ) ]] && break
    done
fi

if [[ "$broken" == "true" ]]; then
    if refresh_config; then
        read_state
        if [[ "$broken" == "false" && "$external" == "true" ]]; then
            printf 'External display recovered with a valid resolution.\n' >&2
        fi
    fi
fi

# On docking, leave the working panel up while Wayland clients attach to the
# external output. Removing it in the middle of GTK's initial configure roundtrip
# can unmap the new bar too. Recheck before retiring the panel: the link may drop.
if [[ "$external" == "true" && "$panel" == "enabled" ]]; then
    sleep 2
    read_state
fi

# Avoid redundant changes when the listener receives events from our own update.
if [[ "$panel" == "missing" ]]; then
    exit 0
elif [[ "$external" == "true" ]]; then
    if [[ "$panel" != "disabled" ]]; then
        hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'
    fi
elif [[ "$panel" != "enabled" ]]; then
    hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = false, mode = "preferred", position = "auto", scale = 1 })'
    sleep 1
    read_state
    if [[ "$panel" != "enabled" && "$external" == "false" ]]; then
        # A saved output override can also prevent the panel from enabling.
        if refresh_config; then
            read_state
            if [[ "$panel" != "enabled" && "$panel" != "missing" && "$external" == "false" ]]; then
                hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = false, mode = "preferred", position = "auto", scale = 1 })'
                sleep 1
                read_state
            fi
        fi
    fi
    if [[ "$panel" != "enabled" && "$external" == "false" ]]; then
        printf 'Display recovery did not produce a usable output; keeping the session running.\n' >&2
        exit 1
    fi
fi
