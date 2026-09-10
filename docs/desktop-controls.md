# Desktop controls

The network/sound/focus cards, notification center and OSD use the same Mocha surfaces
as the Spotify, Steam and calendar tray controls. The bootstrap deploys their
configuration and enables the services at login.

| Control | Action |
|---|---|
| Workspace number | Switch to that workspace, like `Super+number` |
| Network icon: left or right click / dashboard Wi-Fi | Open the shared network picker |
| Volume icon | Open output/input selection, microphone mute and app volumes |
| Volume scroll | Adjust playback volume with OSD feedback |
| Volume middle-click | Toggle the default microphone's mute state |
| Volume right-click | Open Pavucontrol |
| Bell / `Super+Ctrl+N` | Toggle notification center |
| Bell right-click / dashboard DND | Toggle Do Not Disturb |
| `Super+N` / `Super+Shift+N` | Hide latest/all floating notifications; keep history |
| `Super+Ctrl+Space` | Open notification history |
| Focus icon / `Super+Alt+F` | Choose 25 or 50 minutes; pause/resume or finish |
| Focus middle-click / right-click | Pause/resume / finish the session |
| System gear hover | Reveal Bluetooth, power profile, keep-awake, CPU and memory |
| System gear click | Toggle the Eww dashboard |
| `Super+V` | Search clipboard text and image previews; Enter copies, Esc cancels |
| `Super+Alt+Return` | Launch, hide or restore the quick terminal |
| `Super+Alt+N` | Launch, hide or restore quick notes in Helix |

Click outside the sound/focus cards or press Escape to dismiss them. Device
selection moves existing audio streams to the chosen output/input; the advanced
mixer remains available for profiles and more detailed routing. Hardware keys
show a passive overlay on the pointer's monitor. Brightness controls adjust the
laptop backlight, including while it is disabled by the docked display profile.

During focus, notifications collect in the center. Pausing stops the countdown
and keeps notifications quiet. Completion or **Finish session** removes the
timer's notification inhibitor; your DND setting and other apps' inhibitors stay
as they are. The countdown uses a stored deadline, so it also accounts for time
spent suspended. Stopping the timer service cancels the session and releases
its inhibitor before exiting.
If SwayNC restarts during a session, the timer renews its inhibitor within 15 seconds.

Quick notes live in `~/.local/share/hypr-notes/quick-notes.md` (or the corresponding
`XDG_DATA_HOME` directory). Normal Helix editing/saving applies. The same shortcut
hides and restores the existing window; `Super+Q` closes it normally. The generic
`Super+S` scratchpad remains available, and `Super+Shift+F` still toggles full screen.

Cliphist remains the only clipboard history. Up to 40 image entries receive
previews in a private temporary directory, removed when the picker exits.
Clipboard contents, quick notes and focus state are not part of the portable bundle.

## Workspace switching

Click a workspace number at the left of Waybar to switch to it. The active
workspace keeps its highlighted indicator; `Super+1` through `Super+0` continue
to select workspaces 1 through 10 using the Lua bindings.

The bar uses `ext/workspaces` with `on-click: activate`, so clicks go through
Wayland's `ext_workspace_manager_v1` protocol. This avoids the legacy
`hyprctl dispatch workspace` command used by Waybar 0.15's Hyprland module,
which is incompatible with the Lua dispatch syntax in Hyprland 0.56. Numeric
workspace names sort numerically, and hidden special workspaces stay out of
the list. The module uses the existing `#workspaces` styles.

## Display wake and docking

Some HDMI displays briefly disconnect while waking from DPMS (screen power
saving). The monitor reconciler waits up to three seconds before enabling the
laptop panel, checking fresh output state each second. A returning external
display therefore keeps the docked layout; a real unplug or failed modeset still
enables the laptop. A valid external display with DPMS off still counts as docked.
On docking, the laptop stays active for two seconds while Wayland clients attach
to the external display. The reconciler checks the link again before disabling
the panel, avoiding an output removal in the middle of the bar's configuration.
Lid and hotplug events share a runtime `flock` so they cannot change the layout
concurrently.

Waybar accepts real outputs and explicitly excludes Hyprland's temporary
`FALLBACK` output with `"output": ["!FALLBACK", "*"]`. Creating bars across a
rapid `HDMI -> FALLBACK -> laptop -> HDMI` transition can hit
[GTK layer shell's initial configuration timeout](https://github.com/wmww/gtk-layer-shell/blob/master/src/custom-shell-surface.c).
That timeout unmaps the bar while leaving its process alive, so systemd's
`Restart=on-failure` cannot restore it. The filter and delays reduce output
churn, but proved insufficient for the overnight failure on Aquamarine 0.15.0.

Both the live Waybar configuration and `portable/waybar/config.jsonc` carry this
output filter. The monitor listener reads `scripts/monitor-autoswitch.sh` for
each event. It also verifies nonzero output dimensions after wake, skips
inactive VTs, and bounds configuration recovery attempts with a cooldown.

The underlying failure was a rejected DRM disconnect cleanup, followed by an
enabled **0×0** HDMI output. Hyprlock remained alive but had no usable screen.
The targeted Aquamarine patch and upstream Waybar callback fix are documented
in [Display wake fixes](../packaging/display-wake/README.md), together with
reproduction evidence, package sources and validation limits. Activating the
backend fix requires a fresh login; configuration reloads cannot replace the
running compositor's library. The monitor recovery script is a fallback, not
the backend fix.

## Network selection

Both mouse buttons on the bar's network indicator open the same Mocha/Blue
network card. The dashboard Wi-Fi button opens it too. The current network is
marked **Connected**; choosing it again leaves the connection alone.

- Select a saved network to switch using its existing NetworkManager profile.
- Select a new personal network, enter its password, and press Enter or **Connect**.
- Open networks connect without a password prompt. **Refresh** scans in the
  background; search filters the results. Duplicate access points are grouped.
- The Wi-Fi switch controls the radio explicitly. **Advanced settings** opens
  profile management for enterprise credentials, hidden-network setup, IP
  configuration and VPNs. Saved hidden networks appear in the picker afterward.

The card shows connection progress until NetworkManager reports activation,
including address configuration. Errors allow a retry. Closing the card clears
the password field; an already-started connection can finish in the background.
The existing NetworkManager applet handles additional authentication prompts.

The picker uses [libnm](https://networkmanager.dev/docs/libnm/latest/NMClient.html)
and keeps original SSID bytes and saved profile identities. Display labels are
never parsed back into network names. Passwords are sent through D-Bus and kept
by NetworkManager, outside this repository. Scripts do not put them in command
arguments or temporary files. The bootstrap includes the libnm Python typelib.

## Services and configuration

```bash
systemctl --user status swaync desktop-controls focus-timer waybar
hyprctl configerrors
python3 ~/.config/hypr/scripts/focus_timer.py status
```

Network UI and operations live in `scripts/network_popup.py` and
`scripts/network_backend.py`, served by the existing `desktop-controls` service.
`scripts/wifi-menu.sh` is the common launcher for the bar and dashboard.
Notification settings live in `~/.config/swaync/`; their portable copies are in
`portable/swaync/`. Mixer/focus/OSD styling lives in `scripts/desktop-controls.css`
and shares `scripts/tray-popups.css` with Steam and calendar. Update the portable
Waybar and Eww files alongside their live copies.

Mako and Wob are retained as optional fallbacks but are disabled by default.
Stop `focus-timer.service` before switching notification daemons so its quiet
state can be released. The initial live configuration and Mako history were
backed up under `~/.local/state/hypr-desktop/backups/`.

## Verification

```bash
cd ~/.config/hypr
NO_AT_BRIDGE=1 PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests
Hyprland --verify-config --config "$PWD/hyprland.lua"
./bootstrap-opensuse-tumbleweed.sh --dry-run
```

Behavior tests cover network/profile selection and activation states, password
cancellation, focus expiry/pause/restoration, audio routing and refresh guards,
and clipboard cancellation/binary copying. Live checks exercised both
scratchpads through launch/hide/restore, focus pause/resume/cancel, image previews,
the notification center and the passive OSD.
