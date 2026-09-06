# Hyprland Minimal Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the user's DankMaterialShell-based Hyprland setup with a minimal, modular Hyprland + Waybar + Fuzzel + Mako stack themed in Catppuccin Mocha.

**Architecture:** Modular Hyprland config — short entry file sources `~/.config/hypr/conf.d/*.conf` fragments (one per concern). Helper apps (waybar, fuzzel, mako, hyprpaper, hyprlock, hypridle) live in their own `~/.config/<tool>/` dirs. Catppuccin Mocha palette is hardcoded once per config; no runtime theming.

**Tech Stack:** Hyprland, Waybar, Fuzzel, Mako, Hyprpaper, Hyprlock, Hypridle, Ghostty (terminal), nnn (file manager), grimblast (screenshots), wl-clipboard + cliphist, openSUSE Tumbleweed (zypper).

**Spec:** `docs/superpowers/specs/2026-05-06-hyprland-minimal-config-design.md`

**Note on commits:** `~/.config/hypr` is not a git repo. We back up the current config in Task 1 instead of committing per task. Task 23 (optional) initializes a git repo for ongoing tracking.

---

## File Structure

| Path | Purpose |
|---|---|
| `~/.config/hypr/hyprland.conf` | Entry — sources `conf.d/*.conf` |
| `~/.config/hypr/conf.d/10-monitors.conf` | Monitor + workspace-to-monitor binding |
| `~/.config/hypr/conf.d/20-env.conf` | XDG, Qt, cursor, toolkit env vars |
| `~/.config/hypr/conf.d/30-input.conf` | Keyboard + touchpad |
| `~/.config/hypr/conf.d/40-general.conf` | Gaps, borders, layout |
| `~/.config/hypr/conf.d/50-decoration.conf` | Rounding, opacity, shadow |
| `~/.config/hypr/conf.d/60-animations.conf` | Bezier + animation lines |
| `~/.config/hypr/conf.d/70-rules.conf` | Window + layer rules |
| `~/.config/hypr/conf.d/80-autostart.conf` | exec-once block |
| `~/.config/hypr/conf.d/90-keybinds.conf` | All keybindings |
| `~/.config/hypr/hyprpaper.conf` | Wallpaper |
| `~/.config/hypr/hyprlock.conf` | Lockscreen |
| `~/.config/hypr/hypridle.conf` | Idle behavior |
| `~/.config/waybar/config.jsonc` | Waybar modules |
| `~/.config/waybar/style.css` | Waybar styling |
| `~/.config/fuzzel/fuzzel.ini` | Launcher |
| `~/.config/mako/config` | Notifications |

---

## Task 1: Back up the current config

**Files:**
- Create: `~/.config/hypr/_pre-redesign-backup-2026-05-06/` (snapshot of everything currently in `~/.config/hypr/`)

- [ ] **Step 1: Snapshot current config**

```bash
cp -a ~/.config/hypr ~/.config/hypr-backup-2026-05-06
```

- [ ] **Step 2: Verify the backup exists and has the live config**

```bash
ls ~/.config/hypr-backup-2026-05-06/hyprland.conf
diff ~/.config/hypr/hyprland.conf ~/.config/hypr-backup-2026-05-06/hyprland.conf
```

Expected: file listed, `diff` produces no output (identical).

---

## Task 2: Install packages

**Files:** none (system install)

- [ ] **Step 1: Install the main package set**

```bash
sudo zypper install -y \
  waybar fuzzel mako hyprpaper hyprlock hypridle \
  wl-clipboard brightnessctl playerctl pavucontrol \
  nnn qt6ct papirus-icon-theme xdg-desktop-portal-hyprland
```

Expected: zypper installs all packages or reports any not-found. If any package name is rejected, search for it (`zypper se <name>`) and install the matching one. Common openSUSE name differences: nerd font packages may be `nerd-fonts` or per-family `jetbrains-mono-fonts`; if `xdg-desktop-portal-hyprland` is unavailable, fall back to whatever portal openSUSE provides.

- [ ] **Step 2: Install JetBrains Mono Nerd Font**

```bash
zypper se -i jetbrains 2>/dev/null | grep -i nerd || \
  sudo zypper install -y nerd-fonts || \
  echo "MANUAL: install JetBrainsMono Nerd Font from https://www.nerdfonts.com/font-downloads to ~/.local/share/fonts and run 'fc-cache -fv'"
```

Expected: either the openSUSE nerd-fonts package installs, or a manual instruction is printed for the user to follow.

- [ ] **Step 3: Verify all required commands resolve**

```bash
for c in waybar fuzzel mako hyprpaper hyprlock hypridle nnn brightnessctl playerctl wl-copy wl-paste cliphist grimblast ghostty; do
  command -v $c >/dev/null && echo "OK $c" || echo "MISSING $c"
done
```

Expected: every line says `OK`. If anything says `MISSING`, install it before continuing.

- [ ] **Step 4: Verify a Nerd Font is available**

```bash
fc-list | grep -i 'JetBrains Mono.*Nerd' | head -3
```

Expected: at least one line of output. If empty, font installation didn't take — fix before continuing (waybar/fuzzel will look broken without nerd glyphs).

---

## Task 3: Create directory structure

**Files:** new directories only

- [ ] **Step 1: Make the required directories**

```bash
mkdir -p ~/.config/hypr/conf.d \
         ~/.config/waybar \
         ~/.config/fuzzel \
         ~/.config/mako \
         ~/Pictures/Screenshots
```

- [ ] **Step 2: Verify**

```bash
ls -d ~/.config/hypr/conf.d ~/.config/waybar ~/.config/fuzzel ~/.config/mako ~/Pictures/Screenshots
```

Expected: all five paths listed without "No such file or directory".

---

## Task 4: Detect monitor names

This task only collects info — no files written. The output drives Task 6 (monitors fragment).

- [ ] **Step 1: List connected outputs from a running Hyprland session**

If Hyprland is currently running:

```bash
hyprctl monitors all | grep -E '^Monitor|disabled'
```

If Hyprland is **not** currently running, fall back to:

```bash
ls /sys/class/drm/ | grep -E '^card[0-9]+-' | sed 's/^card[0-9]*-//'
```

Expected: a list of output names. The 34" 2K ultrawide is most likely `DP-1`, `DP-2`, `DP-3`, or `HDMI-A-1`. The internal laptop panel is most likely `eDP-1`. Note both names — they go into Task 6.

- [ ] **Step 2: Record the names**

Hold these in mind (or note them in a scratch file). The plan from here on assumes:
- External (ultrawide): `DP-1`
- Internal (laptop panel): `eDP-1`

If your detection in Step 1 returned different names, substitute them everywhere `DP-1` or `eDP-1` appears below.

---

## Task 5: Write the entry `hyprland.conf`

**Files:**
- Modify: `~/.config/hypr/hyprland.conf` (overwrite — backup made in Task 1)

- [ ] **Step 1: Replace the entry file**

Write `~/.config/hypr/hyprland.conf` with exactly this content:

```conf
# Hyprland entry — fragments live in conf.d/, sourced in numeric order.
# Edit the fragments, not this file.

source = ~/.config/hypr/conf.d/10-monitors.conf
source = ~/.config/hypr/conf.d/20-env.conf
source = ~/.config/hypr/conf.d/30-input.conf
source = ~/.config/hypr/conf.d/40-general.conf
source = ~/.config/hypr/conf.d/50-decoration.conf
source = ~/.config/hypr/conf.d/60-animations.conf
source = ~/.config/hypr/conf.d/70-rules.conf
source = ~/.config/hypr/conf.d/80-autostart.conf
source = ~/.config/hypr/conf.d/90-keybinds.conf
```

- [ ] **Step 2: Verify file written**

```bash
wc -l ~/.config/hypr/hyprland.conf
```

Expected: 11 lines (9 source lines + 2 comment lines + blank).

---

## Task 6: Write `conf.d/10-monitors.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/10-monitors.conf`

- [ ] **Step 1: Create the file**

```conf
# 34" 2K ultrawide as primary, internal panel disabled.
# If your monitor names differ, change DP-1 / eDP-1 to match `hyprctl monitors`.

monitor = DP-1, 3440x1440@100, 0x0, 1
monitor = eDP-1, disable

# Workspaces 1-10 bound to the ultrawide
workspace = 1, monitor:DP-1, default:true
workspace = 2, monitor:DP-1
workspace = 3, monitor:DP-1
workspace = 4, monitor:DP-1
workspace = 5, monitor:DP-1
workspace = 6, monitor:DP-1
workspace = 7, monitor:DP-1
workspace = 8, monitor:DP-1
workspace = 9, monitor:DP-1
workspace = 10, monitor:DP-1
```

- [ ] **Step 2: Verify**

```bash
test -s ~/.config/hypr/conf.d/10-monitors.conf && echo OK
```

Expected: `OK`.

---

## Task 7: Write `conf.d/20-env.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/20-env.conf`

- [ ] **Step 1: Create the file**

```conf
# Session
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Toolkits
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_QPA_PLATFORMTHEME,qt6ct
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# Defaults
env = TERMINAL,ghostty
env = BROWSER,firefox
env = EDITOR,helix

# Cursor
env = HYPRCURSOR_THEME,Adwaita
env = HYPRCURSOR_SIZE,24
env = XCURSOR_THEME,Adwaita
env = XCURSOR_SIZE,24
```

- [ ] **Step 2: Verify**

```bash
grep -c '^env = ' ~/.config/hypr/conf.d/20-env.conf
```

Expected: `15`.

---

## Task 8: Write `conf.d/30-input.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/30-input.conf`

- [ ] **Step 1: Create the file**

```conf
input {
    kb_layout = us
    numlock_by_default = true

    repeat_delay = 250
    repeat_rate  = 35

    follow_mouse = 1
    sensitivity = 0     # -1.0 to 1.0; 0 = libinput default

    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
        scroll_factor = 0.4
    }
}

gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 200
}
```

- [ ] **Step 2: Verify**

```bash
grep -E 'kb_layout|natural_scroll|workspace_swipe' ~/.config/hypr/conf.d/30-input.conf
```

Expected: three lines printed.

---

## Task 9: Write `conf.d/40-general.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/40-general.conf`

- [ ] **Step 1: Create the file**

```conf
general {
    gaps_in  = 6
    gaps_out = 12

    border_size = 2
    col.active_border   = rgba(cba6f7ff)
    col.inactive_border = rgba(313244ff)

    layout = dwindle

    resize_on_border = true
    allow_tearing    = false
}

dwindle {
    pseudotile = true
    preserve_split = true
    smart_split = false
}

master {
    new_status = master
    mfact = 0.55
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    vrr = 1
    focus_on_activate = true
    middle_click_paste = false
}
```

- [ ] **Step 2: Verify**

```bash
grep -E 'gaps_in|border_size|layout = ' ~/.config/hypr/conf.d/40-general.conf
```

Expected: three lines.

---

## Task 10: Write `conf.d/50-decoration.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/50-decoration.conf`

- [ ] **Step 1: Create the file**

```conf
decoration {
    rounding = 10

    active_opacity   = 1.00
    inactive_opacity = 0.95
    fullscreen_opacity = 1.00

    shadow {
        enabled = true
        range = 20
        render_power = 3
        color = rgba(11111b80)
        offset = 0 4
    }

    blur {
        enabled = false
    }
}
```

- [ ] **Step 2: Verify**

```bash
grep -E 'rounding|enabled = ' ~/.config/hypr/conf.d/50-decoration.conf
```

Expected: at least three lines (rounding + 2 enabled).

---

## Task 11: Write `conf.d/60-animations.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/60-animations.conf`

- [ ] **Step 1: Create the file**

```conf
animations {
    enabled = true

    bezier = easeOutQuint,   0.22, 1.00, 0.36, 1.00
    bezier = easeInOutCubic, 0.65, 0.00, 0.35, 1.00

    animation = windows,     1, 4, easeOutQuint
    animation = windowsIn,   1, 4, easeOutQuint, popin 90%
    animation = windowsOut,  1, 4, easeOutQuint, popin 80%
    animation = border,      1, 6, easeInOutCubic
    animation = fade,        1, 4, easeOutQuint
    animation = workspaces,  1, 5, easeOutQuint, slide
    animation = layers,      1, 3, easeOutQuint, fade
}
```

- [ ] **Step 2: Verify**

```bash
grep -c '^    animation = ' ~/.config/hypr/conf.d/60-animations.conf
```

Expected: `7`.

---

## Task 12: Write `conf.d/70-rules.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/70-rules.conf`

- [ ] **Step 1: Create the file**

```conf
# Float utility / dialog windows
windowrule = float, class:^(pavucontrol)$
windowrule = float, class:^(nm-connection-editor)$
windowrule = float, class:^(blueman-manager)$
windowrule = float, class:^(org\.gnome\.Calculator)$
windowrule = float, class:^(qt6ct|qt5ct|kvantummanager)$
windowrule = float, class:^(file_progress)$
windowrule = float, class:^(xdg-desktop-portal-gtk)$

# Picture-in-picture
windowrule = float, title:^(Picture-in-Picture)$
windowrule = pin,   title:^(Picture-in-Picture)$
windowrule = size 480 270, title:^(Picture-in-Picture)$
windowrule = move 100%-490 100%-280, title:^(Picture-in-Picture)$

# Inhibit idle while watching video / fullscreen
windowrule = idleinhibit fullscreen, class:.*
windowrule = idleinhibit focus, class:^(mpv|com\.github\.rafostar\.Clapper)$

# Inactive opacity off for fullscreen
windowrule = opacity 1.0 1.0, fullscreen:1

# Layer rules — ignore animations on the bar to keep it snappy
layerrule = ignorezero, waybar
layerrule = blur, notifications
```

- [ ] **Step 2: Verify**

```bash
grep -cE '^(windowrule|layerrule) = ' ~/.config/hypr/conf.d/70-rules.conf
```

Expected: `15`.

---

## Task 13: Write `conf.d/80-autostart.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/80-autostart.conf`

- [ ] **Step 1: Create the file**

```conf
# Polkit agent (the user's existing config used the mate agent — keep it)
exec-once = /usr/libexec/polkit-mate-authentication-agent-1

# Clipboard history daemon
exec-once = wl-paste --watch cliphist store

# Wallpaper, bar, notifications, idle daemon
exec-once = hyprpaper
exec-once = waybar
exec-once = mako
exec-once = hypridle

# XDG portal (most distros launch this via systemd user units; harmless if it duplicates)
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```

- [ ] **Step 2: Verify**

```bash
grep -c '^exec-once = ' ~/.config/hypr/conf.d/80-autostart.conf
```

Expected: `8`.

---

## Task 14: Write `conf.d/90-keybinds.conf`

**Files:**
- Create: `~/.config/hypr/conf.d/90-keybinds.conf`

- [ ] **Step 1: Create the file**

```conf
$mod = SUPER

# === Apps ===
bind = $mod,        Return, exec, ghostty
bind = $mod,        D,      exec, fuzzel
bind = $mod SHIFT,  D,      exec, fuzzel --dmenu
bind = $mod,        B,      exec, firefox
bind = $mod,        E,      exec, ghostty -e nnn
bind = $mod,        V,      exec, sh -c 'cliphist list | fuzzel --dmenu | cliphist decode | wl-copy'

# === Window ===
bind = $mod,        Q,      killactive
bind = $mod,        F,      fullscreen, 1
bind = $mod SHIFT,  F,      fullscreen, 0
bind = $mod SHIFT,  space,  togglefloating
bind = $mod,        P,      pseudo
bind = $mod,        R,      togglesplit

# === Focus (vim hjkl) ===
bind = $mod,        H, movefocus, l
bind = $mod,        J, movefocus, d
bind = $mod,        K, movefocus, u
bind = $mod,        L, movefocus, r

# === Move window ===
bind = $mod SHIFT,  H, movewindow, l
bind = $mod SHIFT,  J, movewindow, d
bind = $mod SHIFT,  K, movewindow, u
bind = $mod SHIFT,  L, movewindow, r

# === Focus monitor ===
bind = $mod CTRL,   H, focusmonitor, l
bind = $mod CTRL,   J, focusmonitor, d
bind = $mod CTRL,   K, focusmonitor, u
bind = $mod CTRL,   L, focusmonitor, r

# === Resize active ===
binde = $mod ALT,   H, resizeactive, -60 0
binde = $mod ALT,   L, resizeactive,  60 0
binde = $mod ALT,   K, resizeactive, 0 -60
binde = $mod ALT,   J, resizeactive, 0  60

# === Workspaces ===
bind = $mod,        1, workspace, 1
bind = $mod,        2, workspace, 2
bind = $mod,        3, workspace, 3
bind = $mod,        4, workspace, 4
bind = $mod,        5, workspace, 5
bind = $mod,        6, workspace, 6
bind = $mod,        7, workspace, 7
bind = $mod,        8, workspace, 8
bind = $mod,        9, workspace, 9
bind = $mod,        0, workspace, 10

bind = $mod SHIFT,  1, movetoworkspace, 1
bind = $mod SHIFT,  2, movetoworkspace, 2
bind = $mod SHIFT,  3, movetoworkspace, 3
bind = $mod SHIFT,  4, movetoworkspace, 4
bind = $mod SHIFT,  5, movetoworkspace, 5
bind = $mod SHIFT,  6, movetoworkspace, 6
bind = $mod SHIFT,  7, movetoworkspace, 7
bind = $mod SHIFT,  8, movetoworkspace, 8
bind = $mod SHIFT,  9, movetoworkspace, 9
bind = $mod SHIFT,  0, movetoworkspace, 10

bind = $mod,        Tab,   workspace, e+1
bind = $mod SHIFT,  Tab,   workspace, e-1

# Special / scratchpad
bind = $mod,        S, togglespecialworkspace
bind = $mod SHIFT,  S, movetoworkspace, special

# Mouse wheel switches workspace
bind = $mod,        mouse_down, workspace, e+1
bind = $mod,        mouse_up,   workspace, e-1

# Drag move/resize with mouse
bindm = $mod,       mouse:272, movewindow
bindm = $mod,       mouse:273, resizewindow

# === System ===
bind = $mod,        Escape,    exec, hyprlock
bind = $mod SHIFT,  E,         exit
bind = $mod CTRL,   R,         exec, hyprctl reload
bind = $mod,        N,         exec, makoctl dismiss
bind = $mod SHIFT,  N,         exec, makoctl dismiss -a
bind = $mod CTRL,   space,     exec, makoctl restore

# === Screenshots (grimblast → clipboard + file) ===
bind = ,            Print,        exec, grimblast --notify copysave area   ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png
bind = SHIFT,       Print,        exec, grimblast --notify copysave screen ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png
bind = CTRL,        Print,        exec, grimblast --notify copysave active ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png

# === Audio (PipeWire via wpctl) ===
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioMicMute,     exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# === Brightness ===
bindel = , XF86MonBrightnessUp,   exec, brightnessctl set +5%
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# === Media keys ===
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous

# === Lid switch ===
bindl = , switch:on:Lid Switch,  exec, hyprctl keyword monitor "eDP-1, disable"
bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"
```

- [ ] **Step 2: Verify**

```bash
grep -cE '^(bind|binde|bindl|bindel|bindm) = ' ~/.config/hypr/conf.d/90-keybinds.conf
```

Expected: at least `60`.

---

## Task 15: Write `hyprpaper.conf`

**Files:**
- Create: `~/.config/hypr/hyprpaper.conf`

- [ ] **Step 1: Pick a wallpaper that exists**

```bash
ls ~/Pictures/*.{webp,jpg,jpeg,png} 2>/dev/null | head -5
```

If `~/Pictures/harpy.webp` exists, use it. Otherwise pick the first file from the listing and substitute its path below.

- [ ] **Step 2: Create the config**

```conf
preload   = ~/Pictures/harpy.webp
wallpaper = , ~/Pictures/harpy.webp

# Slight memory savings; turn off if you want sharper scaling on the ultrawide.
splash = false
ipc = on
```

(If you picked a different file in Step 1, replace both occurrences of `harpy.webp` with that filename.)

- [ ] **Step 3: Verify**

```bash
test -s ~/.config/hypr/hyprpaper.conf && \
  test -f "$(grep '^preload' ~/.config/hypr/hyprpaper.conf | awk -F= '{print $2}' | xargs)" && echo OK
```

Expected: `OK`.

---

## Task 16: Write `hyprlock.conf`

**Files:**
- Create: `~/.config/hypr/hyprlock.conf`

- [ ] **Step 1: Create the file**

```conf
# Catppuccin Mocha lockscreen — minimal: time + date + input
$mantle = rgb(181825)
$base   = rgb(1e1e2e)
$text   = rgb(cdd6f4)
$mauve  = rgb(cba6f7)
$surface0 = rgb(313244)

general {
    grace = 2
    hide_cursor = true
    no_fade_in = false
}

background {
    monitor =
    color = $mantle
    blur_passes = 0
}

# Time
label {
    monitor =
    text = cmd[update:1000] echo "$(date +'%H:%M')"
    color = $text
    font_size = 96
    font_family = JetBrainsMono Nerd Font Bold
    position = 0, 80
    halign = center
    valign = center
}

# Date
label {
    monitor =
    text = cmd[update:60000] echo "$(date +'%A, %d %B')"
    color = $text
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 0
    halign = center
    valign = center
}

# Input field
input-field {
    monitor =
    size = 320, 50
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.4
    outer_color = $surface0
    inner_color = $base
    font_color = $text
    check_color = $mauve
    fail_color = rgb(f38ba8)
    placeholder_text = <span foreground="##a6adc8">password</span>
    fade_on_empty = true
    rounding = 10
    position = 0, -120
    halign = center
    valign = center
}
```

- [ ] **Step 2: Validate config syntax**

```bash
hyprlock --immediate-render --no-fade-in &
sleep 1
pkill hyprlock
```

(Skip if you can't safely test a lockscreen right now — Task 22 will verify.)

Expected: hyprlock starts and is killed without printing parse errors.

---

## Task 17: Write `hypridle.conf`

**Files:**
- Create: `~/.config/hypr/hypridle.conf`

- [ ] **Step 1: Create the file**

```conf
general {
    lock_cmd       = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd  = hyprctl dispatch dpms on
    ignore_dbus_inhibit = false
}

# 5 min: dim
listener {
    timeout = 300
    on-timeout = brightnessctl -s set 10%
    on-resume  = brightnessctl -r
}

# 10 min: lock
listener {
    timeout = 600
    on-timeout = loginctl lock-session
}

# 15 min: screen off
listener {
    timeout = 900
    on-timeout = hyprctl dispatch dpms off
    on-resume  = hyprctl dispatch dpms on
}
```

- [ ] **Step 2: Verify**

```bash
grep -c '^listener {' ~/.config/hypr/hypridle.conf
```

Expected: `3`.

---

## Task 18: Write Waybar `config.jsonc`

**Files:**
- Create: `~/.config/waybar/config.jsonc`

- [ ] **Step 1: Create the file**

```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 6,
    "margin-top": 6,
    "margin-left": 12,
    "margin-right": 12,

    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio", "battery", "cpu", "memory", "custom/power"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
            "6": "6", "7": "7", "8": "8", "9": "9", "10": "0",
            "active": "●",
            "default": "○"
        },
        "on-click": "activate"
    },

    "hyprland/window": {
        "format": "{title}",
        "max-length": 80,
        "separate-outputs": true
    },

    "clock": {
        "format": "{:%a %d %b · %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
    },

    "tray": {
        "icon-size": 16,
        "spacing": 8
    },

    "network": {
        "format-wifi": "  {essid} ({signalStrength}%)",
        "format-ethernet": "  {ifname}",
        "format-disconnected": "  off",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "ghostty -e nmtui"
    },

    "bluetooth": {
        "format": " {status}",
        "format-connected": " {device_alias}",
        "on-click": "blueman-manager"
    },

    "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "  muted",
        "format-icons": {"default": ["", "", ""]},
        "on-click": "pavucontrol",
        "scroll-step": 5
    },

    "battery": {
        "states": {"warning": 30, "critical": 15},
        "format": "{icon}  {capacity}%",
        "format-charging": "  {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },

    "cpu": {
        "format": "  {usage}%",
        "interval": 5
    },

    "memory": {
        "format": "  {percentage}%",
        "interval": 5
    },

    "custom/power": {
        "format": "",
        "tooltip": false,
        "on-click": "sh -c 'echo -e \"lock\\nlogout\\nsuspend\\nreboot\\nshutdown\" | fuzzel --dmenu --prompt=\"⏻ \" | xargs -I{} sh -c \"case {} in lock) hyprlock;; logout) hyprctl dispatch exit;; suspend) systemctl suspend;; reboot) systemctl reboot;; shutdown) systemctl poweroff;; esac\"'"
    }
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json,re; from pathlib import Path; s=Path('~/.config/waybar/config.jsonc').expanduser().read_text(); s=re.sub(r'(?<!:)//.*','',s); json.loads(s)" && echo OK
```

Expected: `OK`. (jsonc allows comments; we strip `//` lines before parsing.)

---

## Task 19: Write Waybar `style.css`

**Files:**
- Create: `~/.config/waybar/style.css`

- [ ] **Step 1: Create the file**

```css
/* Catppuccin Mocha */
@define-color base       #1e1e2e;
@define-color mantle     #181825;
@define-color crust      #11111b;
@define-color surface0   #313244;
@define-color text       #cdd6f4;
@define-color subtext    #a6adc8;
@define-color mauve      #cba6f7;
@define-color red        #f38ba8;
@define-color green      #a6e3a1;
@define-color yellow     #f9e2af;

* {
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", monospace;
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
    padding: 0;
    margin: 0;
}

window#waybar {
    background: alpha(@mantle, 0.92);
    color: @text;
    border-radius: 12px;
    border: 1px solid @surface0;
}

#workspaces { padding: 0 6px; }
#workspaces button {
    color: @subtext;
    padding: 0 6px;
    border-radius: 8px;
    transition: 150ms ease;
}
#workspaces button.active {
    color: @mauve;
    background: @surface0;
}
#workspaces button:hover { background: @surface0; }

#window {
    color: @subtext;
    padding: 0 12px;
}

#clock {
    color: @text;
    background: @surface0;
    padding: 2px 12px;
    border-radius: 8px;
    font-weight: bold;
}

#tray, #network, #bluetooth, #pulseaudio,
#battery, #cpu, #memory, #custom-power {
    padding: 2px 10px;
    margin: 4px 2px;
    border-radius: 8px;
    background: @surface0;
}

#network                       { color: @green; }
#bluetooth                     { color: @subtext; }
#bluetooth.disabled            { color: @subtext; }
#pulseaudio                    { color: @yellow; }
#pulseaudio.muted              { color: @subtext; }
#battery                       { color: @green; }
#battery.warning               { color: @yellow; }
#battery.critical              { color: @red; }
#battery.charging              { color: @mauve; }
#cpu                           { color: @subtext; }
#memory                        { color: @subtext; }
#custom-power                  { color: @red; padding: 2px 14px; }
```

- [ ] **Step 2: Verify**

```bash
test -s ~/.config/waybar/style.css && grep -c '^@define-color' ~/.config/waybar/style.css
```

Expected: `10` (Catppuccin palette colors defined).

---

## Task 20: Write Fuzzel `fuzzel.ini`

**Files:**
- Create: `~/.config/fuzzel/fuzzel.ini`

- [ ] **Step 1: Create the file**

```ini
[main]
font=JetBrainsMono Nerd Font:size=12
prompt="❯ "
icon-theme=Papirus-Dark
terminal=ghostty
lines=8
width=40
horizontal-pad=20
vertical-pad=12
inner-pad=8
fuzzy=yes

[colors]
background=1e1e2eee
text=cdd6f4ff
prompt=cba6f7ff
placeholder=a6adc8ff
input=cdd6f4ff
match=f9e2afff
selection=313244ff
selection-text=cdd6f4ff
selection-match=cba6f7ff
border=cba6f7ff

[border]
width=2
radius=10

[dmenu]
exit-immediately-if-empty=yes
```

- [ ] **Step 2: Sanity launch**

```bash
fuzzel --version && echo OK
```

Expected: a version string then `OK`. (Don't actually open fuzzel here without a Hyprland session; Task 22 covers that.)

---

## Task 21: Write Mako `config`

**Files:**
- Create: `~/.config/mako/config`

- [ ] **Step 1: Create the file**

```ini
sort=-time
layer=overlay
background-color=#1e1e2eee
text-color=#cdd6f4
border-color=#313244
border-size=2
border-radius=10
font=JetBrainsMono Nerd Font 11
padding=12
margin=8
max-icon-size=48
default-timeout=5000
ignore-timeout=false
anchor=top-right
width=320
height=120
icons=true
markup=true

[urgency=low]
border-color=#a6adc8
default-timeout=3000

[urgency=normal]
border-color=#cba6f7

[urgency=critical]
border-color=#f38ba8
default-timeout=0

[grouped]
format=<b>%s</b>\n%b
```

- [ ] **Step 2: Verify**

```bash
test -s ~/.config/mako/config && echo OK
```

Expected: `OK`.

---

## Task 22: Reload Hyprland and smoke test

**Files:** none

- [ ] **Step 1: Reload Hyprland (only if a Hyprland session is currently running)**

```bash
hyprctl reload
```

Expected: no error output. If you're not currently in a Hyprland session, log out of your current session and log back in via Hyprland — then continue with Step 2 below.

- [ ] **Step 2: Verify monitor names**

```bash
hyprctl monitors | grep -E '^Monitor|disabled'
```

Expected: the ultrawide listed as enabled and the laptop panel listed as disabled. If the names don't match `DP-1`/`eDP-1`, edit `~/.config/hypr/conf.d/10-monitors.conf` (and the lid lines in `90-keybinds.conf`) and `hyprctl reload`.

- [ ] **Step 3: Smoke test the bindings**

Run these in order. After each, confirm the expected behavior:

| Action | Bind | Expect |
|---|---|---|
| Open terminal | `Mod+Return` | Ghostty appears |
| Open launcher | `Mod+D` | Fuzzel appears with mauve border |
| Type "firefox" + Enter | (in Fuzzel) | Firefox launches |
| Open file manager | `Mod+E` | nnn appears in a Ghostty window |
| Switch workspace | `Mod+2`, `Mod+1` | active workspace changes |
| Move window to ws 3 | `Mod+Shift+3` | window leaves current workspace |
| Take screenshot | `Print` | grimblast crosshair appears |
| Volume up | `XF86AudioRaiseVolume` | mako notification shows new volume (if your volume key emits it) |
| Lock | `Mod+Escape` | hyprlock takes over the screen — type password to unlock |
| Reload config | `Mod+Ctrl+R` | brief flash, no error |

- [ ] **Step 4: Verify autostart processes are running**

```bash
pgrep -a waybar; pgrep -a mako; pgrep -a hyprpaper; pgrep -a hypridle
```

Expected: each prints one running process line. If any is missing, run it manually (`waybar &`) and check `journalctl --user -t <name> -n 50` for errors.

- [ ] **Step 5: Verify clipboard history works**

Copy some text from any window, then:

```
Mod+V
```

Expected: Fuzzel appears listing recent clipboard entries. Selecting one re-copies it.

---

## Task 23 (optional): Initialize a git repo for the config

**Files:**
- Create: `~/.config/hypr/.gitignore`

- [ ] **Step 1: Init**

```bash
cd ~/.config/hypr
git init
```

- [ ] **Step 2: Add a tiny `.gitignore`**

Write `~/.config/hypr/.gitignore`:

```
*.backup.*
*-backup-*
```

- [ ] **Step 3: Initial commit**

```bash
cd ~/.config/hypr
git add -A
git commit -m "Initial minimal Hyprland config (Catppuccin Mocha, modular conf.d/)"
```

Expected: a commit is created. From here on you can `git diff` config changes before applying them.

---

## Self-review notes

- Spec coverage: all sections from the spec map to tasks 5–21. Smoke test (Task 22) covers the spec's "Risks / verification" section.
- Monitor name uncertainty: explicitly handled in Tasks 4 and 22 Step 2.
- Package name uncertainty (openSUSE): handled in Task 2 Step 1 with a search-and-substitute fallback note.
- Per-task git commits skipped: substituted by Task 1 (backup) and Task 23 (optional repo init), per plan header note.
