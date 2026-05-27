---
title: Desktop aesthetic pass (warm palette + polish + dashboard)
date: 2026-05-27
status: approved
---

# Desktop Aesthetic Pass

## Goal

Promote the existing minimal Hyprland stack from "functional with a cool Catppuccin accent" to "fully composed warm-palette desktop." Pull the accent color out of the new wallpaper, repaint every existing component, fill in the components still on system defaults (GTK, Qt, terminal), and add a styled power menu and a full Eww dashboard.

Wallpaper drives the palette: `/home/thbertoldi/Downloads/3440x1440-minimalista.jpg` (low-poly coral/maroon/teal landscape, native 3440×1440).

## Palette

Catppuccin Mocha base stays. Accents change.

| Role | Color | Hex | Used for |
|---|---|---|---|
| Primary accent | peach | `#fab387` | active workspace, active border (start), prompt, primary CTAs, focused outlines |
| Secondary accent | maroon | `#eba0ac` | active border (end), hover states, secondary highlights, urgency=normal border |
| Error | red (unchanged) | `#f38ba8` | critical notifications, error states |
| Warning | yellow (unchanged) | `#f9e2af` | warning notifications, match highlights |
| Success | green (unchanged) | `#a6e3a1` | battery good, success states |
| Surface 0 | surface0 (unchanged) | `#313244` | inactive border, panel fills |
| Base | base (unchanged) | `#1e1e2e` | window bg |
| Mantle | mantle (unchanged) | `#181825` | bar bg, lock bg |
| Text | text (unchanged) | `#cdd6f4` | primary text |
| Subtext | subtext (unchanged) | `#a6adc8` | secondary text, inactive workspace |

Mauve `#cba6f7` is **removed** from all configs.

## Constraints

- openSUSE Tumbleweed; `zypper` for system packages, manual GitHub releases for things not in repos.
- Edits stay inside the `~/.config/hypr/` modular `conf.d/` layout — never put rules in `hyprland.conf`, which only sources fragments.
- Existing autostart, keybinds, monitors, animations are unchanged unless explicitly listed.
- SDDM theme is **deferred** (login screen polish is a separate later task).
- Don't break anything that already works in KDE Plasma session (this user dual-sessions — KDE is the daily driver; Hyprland is the polish target).

## Scope decomposition: three waves

Each wave is a single commit on the `trunk` branch. Verify visually after each wave (relog into Hyprland session) before moving to the next.

### Wave 1 — Palette repaint + wallpaper engine swap

**Wallpaper engine.** Replace `hyprpaper` with `awww` (already installed at `/usr/bin/awww` v0.12.0; CLI-compatible with swww — same subcommands: `img`, `restore`, `query`).
- `conf.d/80-autostart.conf`: remove `exec-once = hyprpaper`. Add `exec-once = awww-daemon` followed by `exec-once = sleep 0.3 && awww img ~/Pictures/wallpapers/3440x1440-minimalista.jpg --transition-type none`.
- Move the wallpaper into `~/Pictures/wallpapers/` (create dir; move file from `~/Downloads/`).
- Delete/archive `~/.config/hypr/hyprpaper.conf` (rename to `.bak` rather than delete — easy revert).

**Hyprland border** (`conf.d/40-general.conf`):
- `col.active_border = rgba(fab387ff) rgba(eba0acff) 45deg` (peach→maroon gradient)
- `col.inactive_border = rgba(313244ff)` (unchanged)

**Waybar** (`~/.config/waybar/style.css`):
- `@define-color mauve` → `@define-color peach #fab387` + add `@define-color maroon #eba0ac`
- Every `@mauve` reference → `@peach`. Add `@maroon` for hover states on `#workspaces button:hover` and any secondary highlight.

**Fuzzel** (`~/.config/fuzzel/fuzzel.ini`):
- `prompt = cba6f7ff` → `fab387ff`
- `selection-match = cba6f7ff` → `fab387ff`
- `border = cba6f7ff` → `fab387ff`

**Mako** (`~/.config/mako/config`):
- `[urgency=normal] border-color = #cba6f7` → `#fab387`
- `progress-color = over #eba0ac40` (maroon at 25% alpha — fills the progress portion of notifications with a soft maroon overlay; mako uses this `over <color>` syntax).

**Hyprlock** (`hyprlock.conf`):
- Replace `$mauve = rgb(cba6f7)` with `$peach = rgb(fab387)` and `$maroon = rgb(eba0ac)`.
- Every `$mauve` reference → `$peach` (notably `check_color` on the input field).
- Optional: change `outer_color = $surface0` → `$maroon` for a softer ring.

**GTK cursor leftover** (`~/.config/gtk-3.0/settings.ini`):
- `gtk-cursor-theme-name=breeze_cursors` → `Bibata-Modern-Classic`
- `gtk-cursor-theme-size=24` → `28`

### Wave 2 — Theme installs (chrome polish)

**Hyprland blur** (`conf.d/50-decoration.conf`):
- `blur { enabled = true; size = 4; passes = 2; new_optimizations = true; xray = true; noise = 0.02; contrast = 1.0; brightness = 1.0; }`
- Keep existing shadow block (already well-tuned).

**GTK Catppuccin theme.** Install `Catppuccin-Mocha-Standard-Peach-Dark` from `https://github.com/catppuccin/gtk/releases` (manual — not in openSUSE repos). Extract to `~/.local/share/themes/`.
- `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`: set `gtk-theme-name=Catppuccin-Mocha-Standard-Peach-Dark`.
- libadwaita apps: symlink the gtk-4.0/ assets per the catppuccin/gtk README.

**Icon theme.** Keep Papirus-Dark base, accent the folders peach:
- `papirus-folders -C cat-mocha-peach` (one command, recolors all folder icons).
- If `papirus-folders` is not installed: `zypper install papirus-folders` (or grab from GitHub if not packaged).

**Qt theming.**
- Install `qt6ct kvantum` (`sudo zypper install qt6ct kvantum`).
- Clone Catppuccin Kvantum themes: `git clone https://github.com/catppuccin/Kvantum.git /tmp/catp-kvantum && mkdir -p ~/.config/Kvantum && cp -r /tmp/catp-kvantum/themes/Catppuccin-Mocha-Peach ~/.config/Kvantum/`.
- `~/.config/Kvantum/kvantum.kvconfig`: `[General] theme=Catppuccin-Mocha-Peach`.
- `~/.config/qt6ct/qt6ct.conf`: `[Appearance] style=kvantum-dark; icon_theme=Papirus-Dark; color_scheme_path=~/.config/qt6ct/colors/Catppuccin-Mocha.conf`.

**Ghostty terminal.** Create `~/.config/ghostty/config` if missing:
```
theme = catppuccin-mocha
font-family = JetBrainsMono NF
font-size = 12
font-feature = +calt, +liga
background-opacity = 0.92
background-blur-radius = 20
window-padding-x = 12
window-padding-y = 10
cursor-style = block
cursor-style-blink = false
```

### Wave 3 — New components

**wlogout** (styled power menu).
- Install: `sudo zypper install wlogout`.
- Config dir: `~/.config/wlogout/`.
- `layout`: 6 buttons (lock, logout, suspend, hibernate, reboot, shutdown) with proper labels and `action`/`keybind` per the upstream format.
- `style.css`: Catppuccin Mocha background `#1e1e2eee`, peach hover border, JetBrainsMono NF font. Buttons in a 3×2 grid, full-screen overlay with backdrop blur.
- Hyprland keybind (`conf.d/90-keybinds.conf`): `bind = SUPER, Escape, exec, wlogout --protocol layer-shell`.

**eww** (full dashboard sidebar).
- Install: `sudo zypper install eww` (or build from `https://github.com/elkowar/eww` if not packaged).
- Config dir: `~/.config/eww/`.
- Layout: left-side slide-in panel, ~360px wide, full monitor height, triggered by `SUPER + W`.
- Widgets, top to bottom:
  1. **Header card** — avatar (use existing `~/Pictures/icon` if present, else initials), `user@host`, uptime.
  2. **Clock** — large hh:mm in JetBrainsMono NF Bold 48, full date below.
  3. **Calendar** — current month, peach-highlighted today cell, mauve-removed.
  4. **Weather** — `wttr.in` polled via shell command, current temp + condition icon + 3-day mini forecast. Cache file in `/tmp/eww-weather` to avoid hammering the API.
  5. **Media player** — `playerctl` wrapper showing current track, peach play/pause button, prev/next controls.
  6. **System stats** — CPU bar, RAM bar, disk-root bar, all peach-filled, polled every 2s.
  7. **Quick actions row** — toggle buttons for wifi (`nmcli`), bluetooth (`bluetoothctl`), DND (`makoctl set-mode`), lock (`hyprlock`), logout (`wlogout`). Maroon hover.
- Eww keybind: `bind = SUPER, W, exec, eww open --toggle dashboard`.

## Stack additions

| Role | Tool | Status |
|---|---|---|
| Wallpaper | `awww` + `awww-daemon` | already installed; replaces hyprpaper |
| GTK theme | Catppuccin-Mocha-Standard-Peach-Dark | manual install (GitHub) |
| Icon folder accent | `papirus-folders` | install via zypper |
| Qt theme engine | `qt6ct` + `kvantum` | install via zypper |
| Qt theme | Catppuccin Kvantum (Mocha-Peach) | manual install (GitHub) |
| Power menu | `wlogout` | install via zypper |
| Widget framework | `eww` | install via zypper (fallback build from source) |
| Cursor | Bibata-Modern-Classic (hyprcursor) | **already installed** earlier this session |

## Out of scope (this spec)

- SDDM login theme (deferred).
- Plymouth boot splash.
- Animated wallpaper via `mpvpaper` (revisit if static via awww feels static).
- Helix / nvim themes (assumed already on Catppuccin; verify and skip if so).
- Browser theme (Firefox Catppuccin via userChrome.css — separate task).
- KDE session aesthetic (user's KDE side is its own world; do not touch).

## Verification (per wave)

- **Wave 1:** relog into Hyprland. Confirm wallpaper renders sharp, borders show peach→maroon gradient, waybar/fuzzel/mako/hyprlock all show peach where mauve used to be. No leftover mauve anywhere visible. Run `grep -rn 'cba6f7\|mauve' ~/.config/hypr/conf.d/ ~/.config/waybar/ ~/.config/fuzzel/ ~/.config/mako/ ~/.config/hypr/hyprlock.conf` — should return zero hits.
- **Wave 2:** open Firefox → menu should be in Catppuccin Peach GTK. Open a Qt app (e.g., `dolphin` or `kate` if installed; else `qt6ct` itself) — should render dark Catppuccin. Open Ghostty → Catppuccin Mocha + opacity. Move a window over another — blur visible on inactive.
- **Wave 3:** `Super+Escape` → wlogout overlay appears, peach hover. `Super+W` → eww dashboard slides in from left with all widgets populated, peach accents, no broken polls.
