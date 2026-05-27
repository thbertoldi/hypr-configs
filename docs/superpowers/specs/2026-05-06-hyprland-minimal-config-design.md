---
title: Minimal Hyprland config (post-DMS)
date: 2026-05-06
status: approved
---

# Minimal Hyprland Configuration

## Goal

Replace the current DankMaterialShell-based Hyprland config with a clean, minimal stack the user can read end-to-end and modify confidently. Aesthetic: dark, low-contrast (Catppuccin Mocha). Keybindings follow tiling-WM conventions (vim-style, mnemonic).

## Constraints

- Distro: openSUSE Tumbleweed (`zypper`).
- Hardware: laptop with 34" 2K ultrawide external monitor (3440×1440). Internal lid usually closed; internal display disabled by default.
- No removals — installs only. The existing DankMaterialShell config dir stays on disk; the user can switch back.
- Existing `hyprland.conf` already has a backup (`hyprland.conf.backup.2025-11-30_16-27-12`). We will overwrite the live file.

## Stack

| Role | Tool | Notes |
|---|---|---|
| Compositor | Hyprland | already installed |
| Status bar | Waybar | install |
| Launcher | Fuzzel | install — Wayland-native, lighter than Wofi |
| Notifications | Mako | install |
| Wallpaper | Hyprpaper | install |
| Lock | Hyprlock | install |
| Idle | Hypridle | install |
| Terminal | Ghostty | already installed |
| File manager | nnn (in Ghostty) | install nnn only |
| Browser | Firefox | already installed |
| Clipboard | wl-clipboard + cliphist | install wl-clipboard; cliphist already there |
| Screenshots | grimblast | already installed |
| Audio control | wpctl (PipeWire) | already on system |
| Brightness | brightnessctl | install |
| Media keys | playerctl | install |
| Polkit agent | polkit-gnome | install (replaces mate agent in current config) |
| Portal | xdg-desktop-portal-hyprland | install |
| Fonts | JetBrains Mono Nerd, Font Awesome | install |

## File layout

Modular split — one short entry file sourcing topical fragments:

```
~/.config/hypr/
├── hyprland.conf                # source = conf.d/*.conf
├── conf.d/
│   ├── 10-monitors.conf
│   ├── 20-env.conf
│   ├── 30-input.conf
│   ├── 40-general.conf
│   ├── 50-decoration.conf
│   ├── 60-animations.conf
│   ├── 70-rules.conf
│   ├── 80-autostart.conf
│   └── 90-keybinds.conf
├── hyprpaper.conf
├── hyprlock.conf
└── hypridle.conf

~/.config/waybar/
├── config.jsonc
└── style.css

~/.config/fuzzel/fuzzel.ini
~/.config/mako/config
```

## Theme — Catppuccin Mocha

Reference palette (used consistently across waybar, fuzzel, mako, hyprlock, Hyprland borders):

| Role | Hex |
|---|---|
| base | `#1e1e2e` |
| mantle | `#181825` |
| crust | `#11111b` |
| surface0 | `#313244` |
| text | `#cdd6f4` |
| subtext | `#a6adc8` |
| accent (mauve) | `#cba6f7` |
| red | `#f38ba8` |
| green | `#a6e3a1` |
| yellow | `#f9e2af` |

Borders: 2px, mauve when active, `surface0` when inactive.
Rounding: 10px windows, 8px bar/popups.
Gaps: 6 inner / 12 outer.
Inactive opacity: 0.95. No blur (cleaner, less GPU).
Font: JetBrains Mono Nerd, 11pt UI / 12pt waybar.

## Hyprland config — section by section

### 10-monitors.conf
- `monitor = DP-1, 3440x1440@100, 0x0, 1` (placeholder name — verify with `hyprctl monitors` after first boot)
- `monitor = eDP-1, disable`
- Workspaces 1–10 bound to the ultrawide.

### 20-env.conf
- `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_TYPE=wayland`, `XDG_SESSION_DESKTOP=Hyprland`
- `QT_QPA_PLATFORM=wayland;xcb`
- `QT_QPA_PLATFORMTHEME=qt6ct`
- `ELECTRON_OZONE_PLATFORM_HINT=auto`
- `MOZ_ENABLE_WAYLAND=1`
- `TERMINAL=ghostty`, `BROWSER=firefox`, `EDITOR=helix`
- `HYPRCURSOR_THEME=Adwaita`, `XCURSOR_THEME=Adwaita`, `XCURSOR_SIZE=24` (easy to swap later).

### 30-input.conf
- `kb_layout = us`
- `numlock_by_default = true`
- `repeat_delay = 250`, `repeat_rate = 35`
- Touchpad: `natural_scroll = true`, `tap = true`, `dwt = true`, `disable_while_typing = true`

### 40-general.conf
- `gaps_in = 6`, `gaps_out = 12`
- `border_size = 2`
- `col.active_border = rgba(cba6f7ff)`
- `col.inactive_border = rgba(313244ff)`
- `layout = dwindle`
- `resize_on_border = true`

### 50-decoration.conf
- `rounding = 10`
- `active_opacity = 1.0`, `inactive_opacity = 0.95`
- `shadow { enabled = true, range = 20, render_power = 3, color = rgba(11111b80) }`
- `blur { enabled = false }` (explicit — cleaner, lower GPU)

### 60-animations.conf
- Custom bezier `easeOutQuint = 0.22, 1, 0.36, 1`
- `windows`, `border`, `fade`, `workspaces` short (3–5 frames) with that bezier.

### 70-rules.conf
- Float: `pavucontrol`, `nm-connection-editor`, `blueman-manager`, `org.gnome.Calculator`, picture-in-picture.
- Tile: `pavucontrol` is float (overriding above); just keep float for system dialogs.
- `noborder` for fullscreen-friendly apps (firefox PiP).
- `idleinhibit fullscreen` for video.
- `layerrule = blur, waybar` (kept off by default since blur is disabled — comment in file).

### 80-autostart.conf
- `polkit-gnome-authentication-agent-1`
- `wl-paste --watch cliphist store`
- `waybar`, `mako`, `hyprpaper`, `hypridle`
- `[workspace 1 silent] firefox` (optional, comment out by default)

### 90-keybinds.conf
See keybind table below.

## Keybinds

`$mod = SUPER`

### Apps
| Bind | Action |
|---|---|
| `Mod+Return` | `ghostty` |
| `Mod+D` | `fuzzel` |
| `Mod+Shift+D` | `fuzzel --dmenu` (run mode) |
| `Mod+B` | `firefox` |
| `Mod+E` | `ghostty -e nnn` |
| `Mod+V` | `cliphist list \| fuzzel --dmenu \| cliphist decode \| wl-copy` |

### Window
| Bind | Action |
|---|---|
| `Mod+Q` | `killactive` |
| `Mod+F` | `fullscreen, 1` (maximize within gaps) |
| `Mod+Shift+F` | `fullscreen, 0` (true fullscreen) |
| `Mod+Shift+Space` | `togglefloating` |
| `Mod+P` | `pseudo` |
| `Mod+R` | `togglesplit` |

### Focus / move (vim hjkl only)
| Bind | Action |
|---|---|
| `Mod+H/J/K/L` | `movefocus l/d/u/r` |
| `Mod+Shift+H/J/K/L` | `movewindow l/d/u/r` |
| `Mod+Ctrl+H/J/K/L` | `focusmonitor l/d/u/r` |
| `Mod+Alt+H/J/K/L` | `resizeactive ±60` (binde) |

### Workspaces
| Bind | Action |
|---|---|
| `Mod+1..9, 0` | `workspace 1..10` |
| `Mod+Shift+1..9, 0` | `movetoworkspace 1..10` |
| `Mod+Tab` / `Mod+Shift+Tab` | `workspace e+1` / `e-1` |
| `Mod+S` | `togglespecialworkspace` |
| `Mod+Shift+S` | `movetoworkspace special` |
| `Mod+mouse_down/up` | scroll workspaces |

### System
| Bind | Action |
|---|---|
| `Mod+Escape` | `hyprlock` |
| `Mod+Shift+E` | `exit` |
| `Mod+N` | `makoctl dismiss` |
| `Mod+Shift+N` | `makoctl dismiss -a` |
| `Mod+Ctrl+Space` | `makoctl restore` |

### Screenshots (grimblast)
| Bind | Action |
|---|---|
| `Print` | `grimblast --notify copysave area ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png` |
| `Shift+Print` | same, `screen` |
| `Ctrl+Print` | same, `active` |

### Media (XF86)
- `XF86AudioRaiseVolume` / `Lower` / `Mute` → `wpctl`
- `XF86AudioMicMute` → `wpctl`
- `XF86MonBrightnessUp/Down` → `brightnessctl`
- `XF86AudioPlay/Next/Prev` → `playerctl`

### Mouse
- `Mod + LMB drag` → move window
- `Mod + RMB drag` → resize window

## Waybar

- Single bar on `DP-1`, position top, height 30, transparent margin 6px.
- **Modules left**: `hyprland/workspaces`, `hyprland/window`
- **Modules center**: `clock` — `format = {:%a %d %b · %H:%M}`, tooltip with month calendar
- **Modules right**: `tray`, `network`, `bluetooth`, `pulseaudio`, `battery`, `cpu`, `memory`, `custom/power`
- `custom/power` runs a small Fuzzel menu: lock / logout / suspend / reboot / shutdown
- Style: Catppuccin Mocha CSS, JetBrains Mono Nerd 12pt, 8px corner radius on the bar pill, mauve highlight for active workspace.

## Fuzzel

`~/.config/fuzzel/fuzzel.ini` — Catppuccin Mocha colors, JetBrains Mono Nerd 12pt, terminal=ghostty, prompt `❯ `, lines=8, width=40, border-radius=10, padding 16.

## Mako

`~/.config/mako/config` — top-right anchor, 320px wide, 5s default / 0s for critical, mauve border on critical, JetBrains Mono Nerd 11pt, group by app.

## Hyprpaper

```
preload = ~/Pictures/harpy.webp
wallpaper = , ~/Pictures/harpy.webp
```
Easy to swap to any other file in `~/Pictures/`.

## Hyprlock

Black-mantle background, single centered input, time + date above, mauve focused input border. Catppuccin Mocha throughout.

## Hypridle

| Timeout | Action |
|---|---|
| 5 min | dim screen (`brightnessctl set 10%-`) and remember previous |
| 10 min | `loginctl lock-session` (triggers hyprlock) |
| 15 min | DPMS off |
| Lid close | lock + DPMS off |
| Resume | restore brightness, DPMS on |

## Out of scope

- DankMaterialShell removal — leave installed and configured, just stop calling it from Hyprland autostart.
- Color picker, screen recorder, GPU OC tools, gaming tweaks.
- Multi-bar / per-monitor waybar (one monitor used).
- Theme-switching scripts. Theme is a single hardcoded palette.

## Risks / verification

- Monitor names (`DP-1`, `eDP-1`) are guesses. After packages install and a test login, run `hyprctl monitors` and correct.
- openSUSE package names may differ from upstream (e.g. `nnn` is fine, `polkit-gnome` package name should be confirmed). Resolve at install time.
- DMS ipc bindings disappear — user loses spotlight/clipboard/notifications panels. Replacement: Fuzzel for spotlight, `cliphist+fuzzel` for clipboard, Mako for notifications, Waybar power menu for power.
- Hyprland config syntax: this config targets a recent Hyprland (uses `windowrulev2` is now just `windowrule`; `bindd`, `bindmd` etc. exist). We'll use `windowrule = ...` syntax (current docs) and source-check at first reload.

## Implementation order (high level)

1. Install packages.
2. Prepare directory structure (`conf.d/`, waybar, fuzzel, mako dirs).
3. Write Hyprland fragments (entry file + 9 fragments).
4. Write hyprpaper / hyprlock / hypridle / waybar / fuzzel / mako configs.
5. Reload Hyprland (`hyprctl reload`), verify monitors, fix names.
6. Smoke test: launcher opens, terminal opens, screenshots save, brightness keys work, lock works, notifications appear, lid close locks.

A detailed step-by-step plan will follow in the writing-plans phase.
