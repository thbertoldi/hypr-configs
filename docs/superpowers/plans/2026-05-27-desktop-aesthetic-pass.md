# Desktop Aesthetic Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the warm-palette (peach + maroon) repaint, chrome theming (GTK/Qt/Ghostty/blur), and new components (wlogout, eww dashboard) defined in `docs/superpowers/specs/2026-05-27-desktop-aesthetic-pass-design.md`.

**Architecture:** Three commit-bounded waves on `trunk`. Wave 1 = palette + wallpaper engine. Wave 2 = theming chrome. Wave 3 = new components. Each wave is independently verifiable (relog into Hyprland session) and committable.

**Tech Stack:** Hyprland (compositor) · awww (wallpaper daemon) · waybar · fuzzel · mako · hyprlock · GTK4/3 with Catppuccin theme · Qt6 with Kvantum engine · Ghostty · wlogout · eww. openSUSE Tumbleweed (`zypper`).

**Why no worktree:** This repo *is* the live desktop config dir Hyprland reads from. Worktree isolation would mean the user couldn't verify visually until they merged back — defeats the per-wave verification gate. Work directly on `trunk`.

**Verification model (in lieu of automated tests):** Each editing task ends with a syntax check (`hyprctl reload` returns `ok`) and/or a `grep` for residual mauve references. Each *wave* ends with a relog into the Hyprland session and an explicit visual check. The "test" is the user looking at the screen.

---

## Pre-flight Tasks

### Task 0: Handle pre-existing uncommitted changes

The working tree has three uncommitted modifications that pre-date this plan:

- `conf.d/20-env.conf` — cursor swap from Adwaita → Bibata-Modern-Classic (done earlier this session, never committed)
- `conf.d/30-input.conf` — `gestures{}` block replaced with `gesture =` keyword (Hyprland 0.52+ syntax)
- `conf.d/80-autostart.conf` — added `nm-applet --indicator` and `/usr/bin/kwalletd6` exec-once entries

**Files:**
- Modify: working tree state of three files above (no edits — just commit)

- [ ] **Step 1: Inspect each diff to confirm intent**

Run:
```bash
git diff conf.d/20-env.conf conf.d/30-input.conf conf.d/80-autostart.conf
```
Expected: three real, useful changes. Confirm with user that all three should land (default: yes — they're improvements).

- [ ] **Step 2: Stage and commit cursor change**

```bash
git add conf.d/20-env.conf
git commit -m "$(cat <<'EOF'
Swap cursor theme from Adwaita to Bibata-Modern-Classic

Adwaita had no hyprcursor manifest installed, forcing Hyprland to fall back to
xcursor and rendering blurry on 3440×1440. Bibata-Modern-Classic ships both
hyprcursor SVG and multi-size xcursor PNGs; theme installed at
~/.local/share/icons/Bibata-Modern-Classic/. Size bumped 24 → 28 for the ultrawide.

EOF
)"
```

- [ ] **Step 3: Stage and commit gestures syntax update**

```bash
git add conf.d/30-input.conf
git commit -m "$(cat <<'EOF'
Update gestures syntax for Hyprland 0.52+

The old gestures{} block was removed; use the gesture keyword instead.
Preserves 3-finger horizontal swipe to change workspace.

EOF
)"
```

- [ ] **Step 4: Stage and commit autostart additions**

```bash
git add conf.d/80-autostart.conf
git commit -m "$(cat <<'EOF'
Add nm-applet tray icon and kwalletd autostart

nm-applet provides the NetworkManager tray indicator. kwalletd6 needs to run
early so pam_kwallet5 can hand it the login token and auto-unlock; downstream
libsecret apps (browsers, VS Code, Slack) then talk to it via ksecretd.

EOF
)"
```

- [ ] **Step 5: Verify clean working tree**

Run: `git status --short`
Expected: empty output (working tree clean).

---

## Wave 1 — Palette repaint + wallpaper engine swap

### Task 1: Move wallpaper into the Pictures/wallpapers/ directory

**Files:**
- Create directory: `~/Pictures/wallpapers/`
- Move: `~/Downloads/3440x1440-minimalista.jpg` → `~/Pictures/wallpapers/3440x1440-minimalista.jpg`

- [ ] **Step 1: Create the wallpapers dir**

Run:
```bash
mkdir -p ~/Pictures/wallpapers
```

- [ ] **Step 2: Move the file**

Run:
```bash
mv ~/Downloads/3440x1440-minimalista.jpg ~/Pictures/wallpapers/3440x1440-minimalista.jpg
```

- [ ] **Step 3: Verify**

Run:
```bash
file ~/Pictures/wallpapers/3440x1440-minimalista.jpg
```
Expected: `JPEG image data ... 3440 x 1440`.

### Task 2: Swap wallpaper engine from hyprpaper to awww

**Files:**
- Modify: `~/.config/hypr/conf.d/80-autostart.conf`
- Archive: `~/.config/hypr/hyprpaper.conf` → `~/.config/hypr/hyprpaper.conf.bak`

- [ ] **Step 1: Archive hyprpaper.conf**

Run:
```bash
mv ~/.config/hypr/hyprpaper.conf ~/.config/hypr/hyprpaper.conf.bak
```

- [ ] **Step 2: Replace the hyprpaper exec-once with awww-daemon + initial img**

In `~/.config/hypr/conf.d/80-autostart.conf`, replace this line:
```
exec-once = hyprpaper
```
with:
```
# Wallpaper daemon (awww — Codeberg fork-rename of swww, CLI-compatible)
exec-once = awww-daemon
exec-once = sleep 0.3 && awww img ~/Pictures/wallpapers/3440x1440-minimalista.jpg --transition-type none
```

The `sleep 0.3` gives awww-daemon time to bind its socket; `--transition-type none` avoids a flash on first paint.

- [ ] **Step 3: Kill any running hyprpaper, start awww-daemon, paint wallpaper**

Run:
```bash
pkill hyprpaper 2>/dev/null
awww-daemon &
sleep 0.5
awww img ~/Pictures/wallpapers/3440x1440-minimalista.jpg --transition-type none
awww query
```
Expected: `awww query` prints monitor info with the image loaded.

If the user is currently in KDE (not Hyprland) and `awww-daemon` exits immediately with "compositor doesn't support wlr-layer-shell", that's expected — it'll start cleanly on next Hyprland login. Don't fight it.

### Task 3: Repaint Hyprland active border to peach→maroon gradient

**Files:**
- Modify: `~/.config/hypr/conf.d/40-general.conf:7`

- [ ] **Step 1: Edit the border color line**

In `~/.config/hypr/conf.d/40-general.conf`, replace:
```
    col.active_border   = rgba(cba6f7ff)
```
with:
```
    col.active_border   = rgba(fab387ff) rgba(eba0acff) 45deg
```
Leaves `col.inactive_border = rgba(313244ff)` unchanged.

- [ ] **Step 2: Syntax check via reload**

Run:
```bash
hyprctl reload
```
Expected: `ok` (if Hyprland session is running). If you're in KDE, this returns an error — that's fine, the syntax will be picked up on next Hyprland login.

### Task 4: Repaint waybar style.css

**Files:**
- Modify: `~/.config/waybar/style.css`

- [ ] **Step 1: Swap color definitions**

In `~/.config/waybar/style.css`, replace the color definitions block (lines 1-11):
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
```
with:
```css
/* Catppuccin Mocha — warm accent (peach primary, maroon secondary) */
@define-color base       #1e1e2e;
@define-color mantle     #181825;
@define-color crust      #11111b;
@define-color surface0   #313244;
@define-color text       #cdd6f4;
@define-color subtext    #a6adc8;
@define-color peach      #fab387;
@define-color maroon     #eba0ac;
@define-color red        #f38ba8;
@define-color green      #a6e3a1;
@define-color yellow     #f9e2af;
```

- [ ] **Step 2: Replace each `@mauve` reference**

In `~/.config/waybar/style.css`, do a replace-all from `@mauve` to `@peach`. Specifically these two occurrences (verified):
- line 38: `color: @mauve;` (workspace button active) → `color: @peach;`
- line 72: `color: @mauve;` (battery.charging) → `color: @peach;`

- [ ] **Step 3: Add maroon hover state for inactive workspace buttons**

In `~/.config/waybar/style.css`, replace:
```css
#workspaces button:hover { background: @surface0; }
```
with:
```css
#workspaces button:hover {
    background: @surface0;
    color: @maroon;
}
```

- [ ] **Step 4: Grep verify no leftover mauve**

Run:
```bash
grep -n 'mauve\|cba6f7' ~/.config/waybar/style.css
```
Expected: no output.

- [ ] **Step 5: Reload waybar to validate CSS**

Run:
```bash
pkill -SIGUSR2 waybar 2>/dev/null || true
```
SIGUSR2 tells waybar to reload its config. If waybar isn't running (you're in KDE), this no-ops harmlessly. Validation happens visually on next Hyprland login.

### Task 5: Repaint fuzzel

**Files:**
- Modify: `~/.config/fuzzel/fuzzel.ini`

- [ ] **Step 1: Edit color values**

In `~/.config/fuzzel/fuzzel.ini`, replace the entire `[colors]` block:
```ini
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
```
with:
```ini
[colors]
background=1e1e2eee
text=cdd6f4ff
prompt=fab387ff
placeholder=a6adc8ff
input=cdd6f4ff
match=f9e2afff
selection=313244ff
selection-text=cdd6f4ff
selection-match=fab387ff
border=fab387ff
```
(Three values changed from `cba6f7ff` to `fab387ff`: `prompt`, `selection-match`, `border`.)

- [ ] **Step 2: Grep verify**

Run:
```bash
grep -n 'cba6f7' ~/.config/fuzzel/fuzzel.ini
```
Expected: no output.

- [ ] **Step 3: Smoke-test fuzzel renders without erroring**

Run:
```bash
fuzzel --help > /dev/null && echo 'fuzzel CLI ok'
```
Expected: `fuzzel CLI ok`. (Full visual validation comes from launching it on next Hyprland login via `$mod+D`.)

### Task 6: Repaint mako

**Files:**
- Modify: `~/.config/mako/config`

- [ ] **Step 1: Update the urgency=normal border color**

In `~/.config/mako/config`, replace:
```
[urgency=normal]
border-color=#cba6f7
```
with:
```
[urgency=normal]
border-color=#fab387
progress-color=over #eba0ac40
```
The `progress-color = over #eba0ac40` overlay paints a soft maroon (25% alpha) on the progress portion of notifications that include a progress hint (file copies, downloads, etc.).

- [ ] **Step 2: Grep verify**

Run:
```bash
grep -n 'cba6f7\|mauve' ~/.config/mako/config
```
Expected: no output.

- [ ] **Step 3: Reload mako**

Run:
```bash
makoctl reload 2>/dev/null || true
```
No-op if mako isn't running.

### Task 7: Repaint hyprlock

**Files:**
- Modify: `~/.config/hypr/hyprlock.conf`

- [ ] **Step 1: Swap the palette variables**

In `~/.config/hypr/hyprlock.conf`, replace the color variable block at the top:
```
$mantle = rgb(181825)
$base   = rgb(1e1e2e)
$text   = rgb(cdd6f4)
$mauve  = rgb(cba6f7)
$surface0 = rgb(313244)
```
with:
```
$mantle = rgb(181825)
$base   = rgb(1e1e2e)
$text   = rgb(cdd6f4)
$peach  = rgb(fab387)
$maroon = rgb(eba0ac)
$surface0 = rgb(313244)
```

- [ ] **Step 2: Replace `$mauve` references**

In `~/.config/hypr/hyprlock.conf`, the only `$mauve` reference is on the `input-field` block: `check_color = $mauve`. Replace it with `check_color = $peach`.

- [ ] **Step 3: Soften the input ring**

In the same `input-field` block, change:
```
    outer_color = $surface0
```
to:
```
    outer_color = $maroon
```
This gives the password field a soft maroon ring that matches the wallpaper's mountain tones.

- [ ] **Step 4: Grep verify**

Run:
```bash
grep -n 'mauve\|cba6f7' ~/.config/hypr/hyprlock.conf
```
Expected: no output.

- [ ] **Step 5: Test hyprlock syntax**

Run:
```bash
hyprlock --immediate-render --help > /dev/null 2>&1 && echo 'hyprlock binary ok'
```
This just confirms the binary works. Real validation: `hyprlock` while in a Hyprland session — but **do not actually lock yourself out right now**. Defer to manual test after Wave 1 commit.

### Task 8: Fix GTK cursor name leftover

**Files:**
- Modify: `~/.config/gtk-3.0/settings.ini`
- Modify: `~/.config/gtk-4.0/settings.ini`

- [ ] **Step 1: Update gtk-3.0 cursor**

In `~/.config/gtk-3.0/settings.ini`, replace:
```
gtk-cursor-theme-name=breeze_cursors
gtk-cursor-theme-size=24
```
with:
```
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=28
```

- [ ] **Step 2: Update gtk-4.0 cursor**

In `~/.config/gtk-4.0/settings.ini`, replace:
```
gtk-cursor-theme-name=breeze_cursors
gtk-cursor-theme-size=24
```
with:
```
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=28
```

- [ ] **Step 3: Grep verify both files**

Run:
```bash
grep -n 'breeze' ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini
```
Expected: no output.

### Task 9: Verify Wave 1 with a full grep sweep

**Files:** none (read-only)

- [ ] **Step 1: Confirm no `cba6f7` or `mauve` anywhere in the touched configs**

Run:
```bash
grep -rnE 'cba6f7|\\bmauve\\b' \
  ~/.config/hypr/conf.d/ \
  ~/.config/hypr/hyprlock.conf \
  ~/.config/waybar/ \
  ~/.config/fuzzel/ \
  ~/.config/mako/
```
Expected: no output. If anything appears, return to the relevant task and fix.

- [ ] **Step 2: Confirm `hyprctl reload` is clean (only if in Hyprland session)**

Run:
```bash
hyprctl reload 2>&1
```
Expected: `ok` (if in Hyprland) or "couldn't connect" (if in KDE — skip).

### Task 10: Commit Wave 1

**Files:** all modified Wave 1 files

- [ ] **Step 1: Stage Wave 1 files**

Run:
```bash
git add \
  conf.d/40-general.conf \
  conf.d/80-autostart.conf \
  hyprlock.conf
git add -- :/.config/waybar/style.css || true  # waybar lives outside this repo — skip if not tracked
```

Note: `~/.config/waybar/`, `~/.config/fuzzel/`, `~/.config/mako/`, `~/.config/gtk-3.0/`, `~/.config/gtk-4.0/` are NOT tracked by this git repo — only `~/.config/hypr/` is. Their edits live on disk but won't be committed. That's the existing layout; do not try to expand the repo's scope in this plan.

Stage only the files inside this repo:
```bash
git add conf.d/40-general.conf conf.d/80-autostart.conf hyprlock.conf
```

Also stage the archived hyprpaper.conf removal:
```bash
git mv hyprpaper.conf hyprpaper.conf.bak 2>/dev/null || git add hyprpaper.conf hyprpaper.conf.bak
```
(One of those two forms will succeed depending on whether the rename was already done via plain `mv`.)

- [ ] **Step 2: Verify the stage**

Run:
```bash
git status --short
```
Expected: staged changes to `conf.d/40-general.conf`, `conf.d/80-autostart.conf`, `hyprlock.conf`, and a rename `hyprpaper.conf -> hyprpaper.conf.bak`. Nothing else staged.

- [ ] **Step 3: Commit Wave 1**

```bash
git commit -m "$(cat <<'EOF'
Wave 1: warm palette repaint + awww wallpaper engine

Repaints accent from mauve (#cba6f7) to peach (#fab387) primary +
maroon (#eba0ac) secondary across Hyprland border, hyprlock, waybar,
fuzzel, and mako, pulled from the new wallpaper's coral/maroon tones.

Swaps wallpaper engine from hyprpaper to awww (running daemon, transitions
on switch, Codeberg fork-rename of swww). Archived hyprpaper.conf.

Out-of-repo files (waybar/fuzzel/mako/gtk) modified on disk but not tracked
in this repo by design.

EOF
)"
```

- [ ] **Step 4: Tag the commit for easy rollback if needed**

```bash
git tag wave-1-aesthetic
```

- [ ] **Step 5: User visual verification gate**

**STOP HERE.** Tell the user:

> Wave 1 committed (`wave-1-aesthetic`). Please relog into your Hyprland session (log out of KDE → SDDM → Hyprland) and confirm:
> 1. Wallpaper renders sharp at 3440×1440 (no blur, no tile).
> 2. Active window border shows a peach→maroon gradient.
> 3. Waybar's active workspace badge is peach, inactive hover is maroon-tinted.
> 4. `$mod+D` opens fuzzel with peach prompt + peach border.
> 5. Hyprlock (test with `$mod+Escape`) shows peach check color and maroon outer ring.
>
> If anything looks off, tell me what and we'll iterate before Wave 2.

Do NOT proceed to Wave 2 until the user confirms.

---

## Wave 2 — Theme installs (chrome polish)

### Task 11: Enable Hyprland blur

**Files:**
- Modify: `~/.config/hypr/conf.d/50-decoration.conf:16-18`

- [ ] **Step 1: Replace the disabled blur block**

In `~/.config/hypr/conf.d/50-decoration.conf`, replace:
```
    blur {
        enabled = false
    }
```
with:
```
    blur {
        enabled = true
        size = 4
        passes = 2
        new_optimizations = true
        xray = true
        noise = 0.02
        contrast = 1.0
        brightness = 1.0
    }
```

`xray = true` makes blur ignore the windows below the current one — gives the floating-on-glass effect through stacks. `passes = 2` is the polish/perf sweet spot.

- [ ] **Step 2: Reload**

Run: `hyprctl reload`
Expected: `ok` (in Hyprland) or skip if in KDE.

- [ ] **Step 3: Visual confirmation note**

The effect is most visible on translucent surfaces — waybar bar should now blur the wallpaper behind it (currently uses `alpha(@mantle, 0.92)`). Confirm at Wave 2 commit.

### Task 12: Install Catppuccin-Mocha-Standard-Peach-Dark GTK theme

**Files:**
- Create: `~/.local/share/themes/Catppuccin-Mocha-Standard-Peach-Dark/`

- [ ] **Step 1: Fetch the release tarball**

The official `catppuccin/gtk` repo is archived but releases are still hosted. Get the latest release URL programmatically:

```bash
cd /tmp
URL=$(curl -s 'https://api.github.com/repos/catppuccin/gtk/releases/latest' \
  | grep 'browser_download_url' \
  | grep -E 'Mocha-Standard-Peach-Dark\.zip"' \
  | head -1 \
  | cut -d'"' -f4)
echo "Will fetch: $URL"
curl -sL -o catppuccin-gtk.zip "$URL"
```
Expected: `catppuccin-gtk.zip` exists in `/tmp` (~2 MB).

If the URL is empty (release format changed), fall back to manual: visit `https://github.com/catppuccin/gtk/releases/latest` and download the `Catppuccin-Mocha-Standard-Peach-Dark.zip` asset.

- [ ] **Step 2: Extract to themes directory**

```bash
mkdir -p ~/.local/share/themes
unzip -q -o /tmp/catppuccin-gtk.zip -d ~/.local/share/themes/
rm /tmp/catppuccin-gtk.zip
ls ~/.local/share/themes/
```
Expected: `Catppuccin-Mocha-Standard-Peach-Dark/` listed.

### Task 13: Wire the GTK theme into settings.ini

**Files:**
- Modify: `~/.config/gtk-3.0/settings.ini`
- Modify: `~/.config/gtk-4.0/settings.ini`
- Symlink: `~/.config/gtk-4.0/{assets,gtk.css,gtk-dark.css}` → theme's gtk-4.0/

- [ ] **Step 1: Update gtk-3.0 theme name**

In `~/.config/gtk-3.0/settings.ini`, replace:
```
gtk-theme-name=Breeze
```
with:
```
gtk-theme-name=Catppuccin-Mocha-Standard-Peach-Dark
```

- [ ] **Step 2: Add theme name to gtk-4.0**

`~/.config/gtk-4.0/settings.ini` currently has no `gtk-theme-name` line. Add it under the `[Settings]` header (after `gtk-application-prefer-dark-theme=true`):
```
gtk-theme-name=Catppuccin-Mocha-Standard-Peach-Dark
```

- [ ] **Step 3: Symlink libadwaita assets**

libadwaita doesn't read `gtk-theme-name` — it needs the theme's CSS files dropped into `~/.config/gtk-4.0/` directly via symlinks. Current `~/.config/gtk-4.0/` already has `gtk.css` and other files (from a previous shell setup). Back them up, then symlink:

```bash
cd ~/.config/gtk-4.0/
THEME=~/.local/share/themes/Catppuccin-Mocha-Standard-Peach-Dark
for f in gtk.css gtk-dark.css assets; do
  [ -e "$f" ] && [ ! -L "$f" ] && mv "$f" "${f}.dms-backup"
  [ -e "$THEME/gtk-4.0/$f" ] && ln -sf "$THEME/gtk-4.0/$f" "$f"
done
ls -la gtk.css gtk-dark.css assets 2>/dev/null
```
Expected: three symlinks pointing into the theme dir. Old DMS files preserved as `.dms-backup`.

- [ ] **Step 4: Smoke-test by opening a GTK app**

Run:
```bash
GTK_DEBUG=interactive gtk-launch nautilus 2>&1 | head -5 &
sleep 1
pkill nautilus 2>/dev/null
```
This is just to flush GTK theme caching. Real validation: open Firefox or any GTK app in Hyprland session — chrome should be dark Catppuccin Peach.

### Task 14: Install papirus-folders + apply peach accent

**Files:**
- System: install package
- Modify: Papirus icon theme folder colors via `papirus-folders` tool

- [ ] **Step 1: Install package**

Run:
```bash
sudo zypper install -y papirus-folders
```
Expected: package installed (or "already installed" if present).

- [ ] **Step 2: Apply peach accent**

Run:
```bash
papirus-folders -C cat-mocha-peach --theme Papirus-Dark
```
Expected: log line like "Folders' color of `Papirus-Dark` has been changed to cat-mocha-peach."

If `cat-mocha-peach` isn't a known color (papirus-folders versions vary), list available with `papirus-folders -l` and pick the closest peach/orange Catppuccin variant.

- [ ] **Step 3: Verify in a file manager**

Run: `nautilus ~ &` (or `dolphin ~ &`)
Visually: folder icons should be peach-toned. Close the app after confirming.

### Task 15: Install Kvantum runtime + qt6ct (qt6ct already present)

**Files:**
- System: install packages

- [ ] **Step 1: Install kvantum-manager (provides Qt6 Kvantum engine)**

Run:
```bash
sudo zypper install -y kvantum-manager kvantum-qt5
```
`kvantum-manager` covers Qt6, `kvantum-qt5` covers any remaining Qt5 apps.

- [ ] **Step 2: Verify**

Run:
```bash
which kvantummanager qt6ct
```
Expected: both resolve to `/usr/bin/`.

### Task 16: Install Catppuccin Kvantum theme

**Files:**
- Create: `~/.config/Kvantum/Catppuccin-Mocha-Peach/`

- [ ] **Step 1: Clone the Catppuccin Kvantum repo**

```bash
git clone --depth 1 https://github.com/catppuccin/Kvantum.git /tmp/catp-kvantum
ls /tmp/catp-kvantum/themes/ | grep -i mocha
```
Expected: list shows `Catppuccin-Mocha-Peach` (among other Mocha variants).

- [ ] **Step 2: Copy the Mocha-Peach theme into Kvantum's config dir**

```bash
mkdir -p ~/.config/Kvantum
cp -r /tmp/catp-kvantum/themes/Catppuccin-Mocha-Peach ~/.config/Kvantum/
rm -rf /tmp/catp-kvantum
ls ~/.config/Kvantum/Catppuccin-Mocha-Peach/
```
Expected: `Catppuccin-Mocha-Peach.kvconfig`, `Catppuccin-Mocha-Peach.svg`.

### Task 17: Configure Kvantum + qt6ct to use the theme

**Files:**
- Create: `~/.config/Kvantum/kvantum.kvconfig`
- Create: `~/.config/qt6ct/qt6ct.conf`

- [ ] **Step 1: Set Kvantum's active theme**

Create `~/.config/Kvantum/kvantum.kvconfig` with content:
```ini
[General]
theme=Catppuccin-Mocha-Peach
```

- [ ] **Step 2: Configure qt6ct to use Kvantum**

Create `~/.config/qt6ct/qt6ct.conf` with content:
```ini
[Appearance]
custom_palette=false
icon_theme=Papirus-Dark
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x16\0J\0\x65\0t\0\x42\0r\0\x61\0i\0n\0s\0M\0o\0n\0o\0 \0N\0F@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x10\0N\0o\0t\0o\0 \0S\0\x61\0n\0s@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

[Interface]
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
keyboard_scheme=2
menubar_action_shortcuts=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[SettingsWindow]
geometry=@ByteArray()

[Troubleshooting]
force_raster_widgets=1
```

- [ ] **Step 3: Verify Qt env var is already set**

Run:
```bash
grep QT_QPA_PLATFORMTHEME ~/.config/hypr/conf.d/20-env.conf
```
Expected: `env = QT_QPA_PLATFORMTHEME,qt6ct` (already set — no edit needed).

- [ ] **Step 4: Test Qt theming**

Run:
```bash
qt6ct &
sleep 1
pkill qt6ct
```
Opens qt6ct itself; window should render in dark Catppuccin Peach (Kvantum-styled). If it renders default light, double-check the env var picks up on next session.

### Task 18: Write Ghostty config

**Files:**
- Create: `~/.config/ghostty/config`
- Remove: `~/.config/ghostty/config.ghostty` (empty file with wrong extension)

- [ ] **Step 1: Remove the empty wrong-named file**

Run:
```bash
[ -s ~/.config/ghostty/config.ghostty ] && echo 'NON-EMPTY — INSPECT' || rm -f ~/.config/ghostty/config.ghostty
```
Expected: no output (file removed). If it prints `NON-EMPTY — INSPECT`, stop and read the file first.

- [ ] **Step 2: Write the canonical config**

Create `~/.config/ghostty/config` with content:
```
theme = catppuccin-mocha
font-family = JetBrainsMono NF
font-size = 12
font-feature = +calt
font-feature = +liga
background-opacity = 0.92
background-blur-radius = 20
window-padding-x = 12
window-padding-y = 10
cursor-style = block
cursor-style-blink = false
copy-on-select = clipboard
mouse-hide-while-typing = true
window-decoration = false
```

`window-decoration = false` plays nicely with Hyprland's own border. `background-blur-radius` only works with Hyprland's blur enabled (Task 11).

- [ ] **Step 3: Validate by launching ghostty**

Run:
```bash
ghostty --help > /dev/null && echo 'ghostty CLI ok'
```
Expected: `ghostty CLI ok`. Visual validation: open Ghostty in Hyprland and confirm Catppuccin Mocha colors, JetBrainsMono NF font, transparent + blurred bg.

### Task 19: Verify Wave 2

**Files:** none (verification only)

- [ ] **Step 1: Confirm GTK theme is applied**

Run:
```bash
grep '^gtk-theme-name' ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini
```
Expected: both lines show `Catppuccin-Mocha-Standard-Peach-Dark`.

- [ ] **Step 2: Confirm Kvantum config**

Run:
```bash
cat ~/.config/Kvantum/kvantum.kvconfig
ls ~/.config/Kvantum/Catppuccin-Mocha-Peach/
```
Expected: theme set, theme files present.

- [ ] **Step 3: Confirm blur is enabled**

Run:
```bash
grep -A1 'blur {' ~/.config/hypr/conf.d/50-decoration.conf
```
Expected: `enabled = true` in the second line.

### Task 20: Commit Wave 2

**Files:** all Wave 2 changes

- [ ] **Step 1: Stage the in-repo files**

Wave 2 touches three in-repo files plus several out-of-repo files (GTK/Qt/Ghostty live in `~/.config/{gtk-*,Kvantum,qt6ct,ghostty}/` which are not tracked here). Stage only what this repo tracks:

```bash
git add conf.d/50-decoration.conf
git status --short
```
Expected: one staged file (`conf.d/50-decoration.conf`).

If you also want to start tracking the new component configs in this repo, that's a separate scope decision — skip for now and stay consistent with the existing layout.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
Wave 2: enable Hyprland blur (2 passes, xray)

Companion theme work (Catppuccin GTK + Kvantum + Ghostty + papirus-folders
peach accent) applied to out-of-repo config files in ~/.config/{gtk-*,
Kvantum,qt6ct,ghostty}/ — those live outside this repo by existing
convention.

EOF
)"
git tag wave-2-chrome
```

- [ ] **Step 3: User visual verification gate**

**STOP HERE.** Tell the user:

> Wave 2 committed (`wave-2-chrome`). Please relog into Hyprland and confirm:
> 1. Move a Ghostty window over Firefox — wallpaper visibly blurs behind Ghostty's transparent bg.
> 2. Open Firefox → titlebar/chrome is dark Catppuccin Peach (not Breeze grey).
> 3. Open Nautilus or Dolphin → folder icons are peach-toned.
> 4. Open `qt6ct` itself → it renders dark Catppuccin (proves Kvantum chain works).
> 5. Open Ghostty → JetBrainsMono NF, Catppuccin Mocha colors, slightly transparent bg.
>
> Tell me if any of those fail before we proceed to Wave 3.

Do NOT proceed to Wave 3 until the user confirms.

---

## Wave 3 — wlogout + eww dashboard

### Task 21: Install wlogout

**Files:** system package

- [ ] **Step 1: Install**

Run:
```bash
sudo zypper install -y wlogout
which wlogout
```
Expected: `/usr/bin/wlogout`.

### Task 22: Write wlogout layout

**Files:**
- Create: `~/.config/wlogout/layout`

- [ ] **Step 1: Create the config dir**

```bash
mkdir -p ~/.config/wlogout
```

- [ ] **Step 2: Write the 6-button layout**

Create `~/.config/wlogout/layout` with content:
```
{
    "label" : "lock",
    "action" : "hyprlock",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "suspend",
    "action" : "systemctl suspend",
    "text" : "Suspend",
    "keybind" : "u"
}
{
    "label" : "hibernate",
    "action" : "systemctl hibernate",
    "text" : "Hibernate",
    "keybind" : "h"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
```
Note: wlogout's layout file uses one JSON object per button, no array wrapper or commas between objects.

### Task 23: Write wlogout style.css

**Files:**
- Create: `~/.config/wlogout/style.css`

- [ ] **Step 1: Write Catppuccin Mocha + peach hover theme**

Create `~/.config/wlogout/style.css` with content:
```css
* {
    background-image: none;
    box-shadow: none;
    font-family: "JetBrainsMono NF", monospace;
}

window {
    background-color: rgba(30, 30, 46, 0.85);
    color: #cdd6f4;
}

button {
    color: #cdd6f4;
    background-color: #181825;
    border: 2px solid #313244;
    border-radius: 16px;
    margin: 8px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    transition: all 200ms ease;
}

button:focus, button:active, button:hover {
    background-color: #1e1e2e;
    border-color: #fab387;
    color: #fab387;
    outline-style: none;
}

#lock      { background-image: image(url("/usr/share/wlogout/icons/lock.png")); }
#logout    { background-image: image(url("/usr/share/wlogout/icons/logout.png")); }
#suspend   { background-image: image(url("/usr/share/wlogout/icons/suspend.png")); }
#hibernate { background-image: image(url("/usr/share/wlogout/icons/hibernate.png")); }
#reboot    { background-image: image(url("/usr/share/wlogout/icons/reboot.png")); }
#shutdown  { background-image: image(url("/usr/share/wlogout/icons/shutdown.png")); }
```

- [ ] **Step 2: Verify the icon paths exist**

Run:
```bash
ls /usr/share/wlogout/icons/
```
Expected: lock.png, logout.png, suspend.png, hibernate.png, reboot.png, shutdown.png. If the openSUSE package puts them elsewhere, run `find / -name 'lock.png' -path '*wlogout*' 2>/dev/null` and update the CSS paths to match.

- [ ] **Step 3: Smoke-test wlogout opens**

Run:
```bash
wlogout --protocol layer-shell &
sleep 2
pkill wlogout
```
Expected: wlogout overlay shows briefly (only visible if you're in a Hyprland session). In KDE, layer-shell isn't supported — wlogout will error out, that's fine.

### Task 24: Bind wlogout to Super+Escape (and rebind hyprlock)

**Files:**
- Modify: `~/.config/hypr/conf.d/90-keybinds.conf`

- [ ] **Step 1: Inspect current Super+Escape binding**

Run:
```bash
grep -n 'Escape' ~/.config/hypr/conf.d/90-keybinds.conf
```
Expected: line 82 reads `bind = $mod,        Escape,    exec, hyprlock`.

- [ ] **Step 2: Replace with wlogout**

In `~/.config/hypr/conf.d/90-keybinds.conf`, replace:
```
bind = $mod,        Escape,    exec, hyprlock
```
with:
```
bind = $mod,        Escape,    exec, wlogout --protocol layer-shell
```

This frees `hyprlock` to be reachable via wlogout's "Lock" button (Super+Escape, then `l`). If you'd rather keep a direct lock keybind, add:
```
bind = $mod SHIFT,  Escape,    exec, hyprlock
```
as a second line right after.

- [ ] **Step 3: Reload**

Run: `hyprctl reload`
Expected: `ok` (in Hyprland session).

### Task 25: Install eww

**Files:** system package

- [ ] **Step 1: Install**

Run:
```bash
sudo zypper install -y eww
which eww
```
Expected: `/usr/bin/eww`.

If the openSUSE package version (0.6.0) is too old and you hit yuck syntax errors later, fall back to building from `https://github.com/elkowar/eww` source (Rust toolchain required).

### Task 26: Eww scaffold — config dir, eww.yuck base, dashboard window

**Files:**
- Create: `~/.config/eww/eww.yuck`
- Create: `~/.config/eww/eww.scss`
- Create: `~/.config/eww/scripts/` (empty dir for poller scripts)

- [ ] **Step 1: Create the dir structure**

```bash
mkdir -p ~/.config/eww/scripts
```

- [ ] **Step 2: Write the eww.yuck scaffold**

Create `~/.config/eww/eww.yuck` with content:
```lisp
;; ============================================================================
;; Dashboard — slide-in side panel
;; Toggle via Super+W (see hypr/conf.d/90-keybinds.conf)
;; ============================================================================

(defwindow dashboard
  :monitor 0
  :geometry (geometry :x "16px"
                      :y "16px"
                      :width "360px"
                      :height "96%"
                      :anchor "left center")
  :stacking "overlay"
  :exclusive false
  :focusable false
  (dashboard-root))

(defwidget dashboard-root []
  (box :class "dashboard-root"
       :orientation "v"
       :spacing 14
       :space-evenly false
    (header-card)
    (clock-card)
    (calendar-card)
    (weather-card)
    (media-card)
    (stats-card)
    (actions-row)))

;; ============================================================================
;; Polled variables (each filled in by a script in scripts/)
;; ============================================================================

(defpoll time   :interval "1s"     "date +'%H:%M'")
(defpoll date   :interval "60s"    "date +'%A, %d %B %Y'")
(defpoll uptime :interval "60s"    "uptime -p | sed 's/up //'")

(defpoll cpu    :interval "2s"     "~/.config/eww/scripts/cpu.sh")
(defpoll mem    :interval "2s"     "~/.config/eww/scripts/mem.sh")
(defpoll disk   :interval "10s"    "~/.config/eww/scripts/disk.sh")

(defpoll weather :interval "1800s" "~/.config/eww/scripts/weather.sh")
(defpoll media   :interval "1s"    "~/.config/eww/scripts/media.sh")

;; placeholder widgets — concrete widgets are added in Tasks 27-33
(defwidget header-card   [] (box :class "card"))
(defwidget clock-card    [] (box :class "card"))
(defwidget calendar-card [] (box :class "card"))
(defwidget weather-card  [] (box :class "card"))
(defwidget media-card    [] (box :class "card"))
(defwidget stats-card    [] (box :class "card"))
(defwidget actions-row   [] (box :class "card"))
```

- [ ] **Step 3: Write the eww.scss base**

Create `~/.config/eww/eww.scss` with content:
```scss
// Catppuccin Mocha — warm accent
$base:     #1e1e2e;
$mantle:   #181825;
$crust:    #11111b;
$surface0: #313244;
$surface1: #45475a;
$text:     #cdd6f4;
$subtext:  #a6adc8;
$overlay:  #6c7086;
$peach:    #fab387;
$maroon:   #eba0ac;
$red:      #f38ba8;
$yellow:   #f9e2af;
$green:    #a6e3a1;
$teal:     #94e2d5;

* {
    all: unset;
    font-family: "JetBrainsMono NF", monospace;
    font-size: 13px;
}

.dashboard-root {
    background-color: transparentize($mantle, 0.10);
    border: 1px solid $surface0;
    border-radius: 18px;
    padding: 14px;
    color: $text;
}

.card {
    background-color: transparentize($base, 0.05);
    border: 1px solid $surface0;
    border-radius: 14px;
    padding: 14px;
    color: $text;
}

.card-title {
    color: $peach;
    font-weight: bold;
    font-size: 12px;
    margin-bottom: 6px;
}
```

- [ ] **Step 4: Open the window once to validate yuck/scss syntax**

Run:
```bash
eww open dashboard 2>&1 | tail -20
sleep 2
eww close dashboard
```
Expected: window opens without yuck/scss errors. Empty cards visible. If errors appear, fix them before adding widget content.

In KDE, eww may error with "compositor doesn't support wlr-layer-shell" — defer to Hyprland session for visual validation.

### Task 27: Eww widget — header card (avatar + user@host + uptime)

**Files:**
- Modify: `~/.config/eww/eww.yuck` (replace `header-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)
- Optional: `~/Pictures/icon` already exists (used as avatar if circular crop works)

- [ ] **Step 1: Replace the header-card widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget header-card   [] (box :class "card"))
```
with:
```lisp
(defwidget header-card []
  (box :class "card header-card" :orientation "h" :spacing 12 :space-evenly false
    (box :class "avatar"
         :style "background-image: url('${HOME}/Pictures/icon');")
    (box :orientation "v" :spacing 2 :space-evenly false
      (label :class "header-name"  :text "${EWW_USER}@${EWW_HOST}" :halign "start")
      (label :class "header-uptime" :text "up ${uptime}"            :halign "start"))))
```

- [ ] **Step 2: Append header-card styles to eww.scss**

Append to `~/.config/eww/eww.scss`:
```scss
.header-card {
    .avatar {
        min-width: 56px;
        min-height: 56px;
        border-radius: 28px;
        background-size: cover;
        background-position: center;
        border: 2px solid $peach;
    }
    .header-name   { color: $text;    font-weight: bold; font-size: 14px; }
    .header-uptime { color: $subtext; font-size: 11px; }
}
```

- [ ] **Step 3: If `~/Pictures/icon` doesn't exist, set a fallback color**

Run:
```bash
[ -f ~/Pictures/icon ] || echo 'No avatar file — using solid peach instead'
```
If no avatar file: in `eww.yuck` replace the avatar box's `:style` line with `:style "background-color: ${peach};"` — but `${peach}` won't interpolate in yuck. Hardcode `:style "background-color: #fab387;"`.

- [ ] **Step 4: Reload eww**

Run:
```bash
eww reload && eww open dashboard
```
Expected: header card shows avatar circle + name + uptime.

### Task 28: Eww widget — clock card

**Files:**
- Modify: `~/.config/eww/eww.yuck` (replace `clock-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Replace the clock-card widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget clock-card    [] (box :class "card"))
```
with:
```lisp
(defwidget clock-card []
  (box :class "card clock-card" :orientation "v" :spacing 2 :space-evenly false
    (label :class "clock-time" :text time :halign "center")
    (label :class "clock-date" :text date :halign "center")))
```

- [ ] **Step 2: Append clock-card styles**

Append to `~/.config/eww/eww.scss`:
```scss
.clock-card {
    .clock-time {
        font-family: "JetBrainsMono NF";
        font-weight: bold;
        font-size: 48px;
        color: $text;
    }
    .clock-date {
        color: $subtext;
        font-size: 12px;
        margin-top: 4px;
    }
}
```

- [ ] **Step 3: Reload + verify**

Run: `eww reload`
Expected: large hh:mm + date underneath.

### Task 29: Eww widget — calendar card

**Files:**
- Modify: `~/.config/eww/eww.yuck` (replace `calendar-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Replace the calendar-card widget**

eww has a built-in `calendar` widget. Replace:
```lisp
(defwidget calendar-card [] (box :class "card"))
```
with:
```lisp
(defwidget calendar-card []
  (box :class "card calendar-card" :orientation "v" :spacing 6 :space-evenly false
    (label :class "card-title" :text "CALENDAR" :halign "start")
    (calendar :class "calendar"
              :show-week-numbers false
              :show-heading true
              :show-details false
              :show-day-names true)))
```

- [ ] **Step 2: Append calendar styles**

Append to `~/.config/eww/eww.scss`:
```scss
.calendar-card {
    .calendar {
        color: $text;
        font-size: 12px;
        padding: 4px;
    }
    // GTK's calendar widget exposes :selected via .selected pseudoclass for today's cell.
    // The peach accent on today comes from GTK theme — see Wave 2 Catppuccin-Peach install.
}
```

- [ ] **Step 3: Reload + verify**

Run: `eww reload`
Expected: month view with peach-highlighted today cell (color comes from the Catppuccin GTK theme installed in Wave 2).

### Task 30: Eww widget — weather card (wttr.in poller)

**Files:**
- Create: `~/.config/eww/scripts/weather.sh`
- Modify: `~/.config/eww/eww.yuck` (replace `weather-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Write the weather poller script**

Create `~/.config/eww/scripts/weather.sh` with content:
```bash
#!/usr/bin/env bash
# Polls wttr.in every 30 min, caches to /tmp to avoid hammering the API.
# Output: JSON consumed by eww widgets, e.g. {"icon":"☀","temp":"18°C","desc":"Sunny","city":"Berlin"}
set -euo pipefail

CACHE=/tmp/eww-weather.json
TTL=1800  # 30 min — match defpoll interval
CITY=""   # blank = wttr.in auto-detects from IP

now=$(date +%s)
if [ -f "$CACHE" ]; then
  age=$(( now - $(stat -c %Y "$CACHE") ))
  if [ "$age" -lt "$TTL" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

# fetch — 4s timeout so eww doesn't block forever on network failure
raw=$(curl -sS --max-time 4 "wttr.in/${CITY}?format=j1" 2>/dev/null || echo "")

if [ -z "$raw" ]; then
  # network failure — print last cache if any, else minimal placeholder
  if [ -f "$CACHE" ]; then cat "$CACHE"; else echo '{"icon":"?","temp":"--","desc":"offline","city":"?"}'; fi
  exit 0
fi

# Parse with jq (already on most systems). Map wttr's weatherCode to a glyph.
icon=$(echo "$raw" | jq -r '.current_condition[0].weatherCode' | awk '{
  if ($1==113) print "☀"
  else if ($1==116) print "⛅"
  else if ($1>=119 && $1<=143) print "☁"
  else if ($1>=176 && $1<=296) print "🌧"
  else if ($1>=302 && $1<=389) print "⛈"
  else if ($1>=392) print "❄"
  else print "?"
}')
temp=$(echo "$raw" | jq -r '.current_condition[0].temp_C')°C
desc=$(echo "$raw" | jq -r '.current_condition[0].weatherDesc[0].value')
city=$(echo "$raw" | jq -r '.nearest_area[0].areaName[0].value')

out=$(jq -nc --arg i "$icon" --arg t "$temp" --arg d "$desc" --arg c "$city" \
      '{icon:$i, temp:$t, desc:$d, city:$c}')
echo "$out" | tee "$CACHE"
```

- [ ] **Step 2: Make the script executable**

Run:
```bash
chmod +x ~/.config/eww/scripts/weather.sh
~/.config/eww/scripts/weather.sh
```
Expected: a JSON line like `{"icon":"☀","temp":"18°C","desc":"Sunny","city":"Berlin"}`. If `jq` is missing, install with `sudo zypper install -y jq` and re-run.

- [ ] **Step 3: Replace the weather-card widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget weather-card  [] (box :class "card"))
```
with:
```lisp
(defwidget weather-card []
  (box :class "card weather-card" :orientation "h" :spacing 12 :space-evenly false
    (label :class "weather-icon" :text {weather?.icon ?: "?"})
    (box :orientation "v" :spacing 2 :space-evenly false :hexpand true
      (label :class "weather-temp" :text {weather?.temp ?: "--"} :halign "start")
      (label :class "weather-desc" :text {weather?.desc ?: ""}   :halign "start")
      (label :class "weather-city" :text {weather?.city ?: ""}   :halign "start"))))
```

- [ ] **Step 4: Append weather styles**

Append to `~/.config/eww/eww.scss`:
```scss
.weather-card {
    .weather-icon { font-size: 36px; color: $peach; }
    .weather-temp { font-size: 20px; font-weight: bold; color: $text; }
    .weather-desc { font-size: 12px; color: $subtext; }
    .weather-city { font-size: 11px; color: $overlay; }
}
```

- [ ] **Step 5: Reload + verify**

Run: `eww reload`
Expected: icon + temp + description + city. If shows "offline", check network. If shows "?", the wttr.in weatherCode mapping needs adjustment — log the raw code via `echo "$raw" | jq '.current_condition[0].weatherCode'` and add the mapping.

### Task 31: Eww widget — media player card

**Files:**
- Create: `~/.config/eww/scripts/media.sh`
- Modify: `~/.config/eww/eww.yuck` (replace `media-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Verify playerctl is installed**

Run:
```bash
which playerctl
```
Expected: `/usr/bin/playerctl`. If missing: `sudo zypper install -y playerctl`.

- [ ] **Step 2: Write the media poller script**

Create `~/.config/eww/scripts/media.sh` with content:
```bash
#!/usr/bin/env bash
# Outputs JSON of the active MPRIS player's current state.
# {"status":"Playing|Paused|Stopped","title":"...","artist":"...","icon":"⏵|⏸"}
set -euo pipefail

if ! command -v playerctl >/dev/null; then
  echo '{"status":"Stopped","title":"","artist":"","icon":"⏵"}'; exit 0
fi

status=$(playerctl status 2>/dev/null || echo "Stopped")
title=$(playerctl metadata title  2>/dev/null || echo "")
artist=$(playerctl metadata artist 2>/dev/null || echo "")
icon=$([ "$status" = "Playing" ] && echo "⏸" || echo "⏵")

jq -nc --arg s "$status" --arg t "$title" --arg a "$artist" --arg i "$icon" \
   '{status:$s, title:$t, artist:$a, icon:$i}'
```

- [ ] **Step 3: Make executable + smoke test**

```bash
chmod +x ~/.config/eww/scripts/media.sh
~/.config/eww/scripts/media.sh
```
Expected: JSON line. With nothing playing: `{"status":"Stopped","title":"","artist":"","icon":"⏵"}`.

- [ ] **Step 4: Replace the media-card widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget media-card    [] (box :class "card"))
```
with:
```lisp
(defwidget media-card []
  (box :class "card media-card" :orientation "v" :spacing 6 :space-evenly false
    (label :class "card-title" :text "MEDIA" :halign "start")
    (label :class "media-title"  :text {media?.title  ?: "—"} :halign "start" :limit-width 28 :truncate true)
    (label :class "media-artist" :text {media?.artist ?: ""}  :halign "start" :limit-width 28 :truncate true)
    (box :orientation "h" :spacing 8 :space-evenly true :halign "center"
      (button :class "media-btn" :onclick "playerctl previous" "⏮")
      (button :class "media-btn media-play" :onclick "playerctl play-pause" {media?.icon ?: "⏵"})
      (button :class "media-btn" :onclick "playerctl next" "⏭"))))
```

- [ ] **Step 5: Append media styles**

Append to `~/.config/eww/eww.scss`:
```scss
.media-card {
    .media-title  { font-size: 13px; color: $text; font-weight: bold; }
    .media-artist { font-size: 11px; color: $subtext; margin-bottom: 6px; }
    .media-btn {
        font-size: 18px;
        color: $text;
        padding: 4px 12px;
        border-radius: 8px;
        background-color: $surface0;
        transition: all 150ms ease;
        &:hover { background-color: $surface1; color: $peach; }
    }
    .media-play { color: $peach; }
}
```

- [ ] **Step 6: Reload + verify**

Run: `eww reload`
Expected: card with title/artist + three buttons. Start Spotify or any MPRIS-capable player, then verify the buttons work.

### Task 32: Eww widget — system stats card (CPU / RAM / disk)

**Files:**
- Create: `~/.config/eww/scripts/cpu.sh`
- Create: `~/.config/eww/scripts/mem.sh`
- Create: `~/.config/eww/scripts/disk.sh`
- Modify: `~/.config/eww/eww.yuck` (replace `stats-card` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Write cpu.sh**

Create `~/.config/eww/scripts/cpu.sh` with content:
```bash
#!/usr/bin/env bash
# Percent CPU used over a 1s sample, rounded int 0-100.
set -euo pipefail

read -r _ u1 n1 s1 i1 io1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 io2 _ < /proc/stat

used=$(( (u2+n2+s2) - (u1+n1+s1) ))
total=$(( used + (i2+io2) - (i1+io1) ))
[ "$total" -le 0 ] && total=1
echo $(( 100 * used / total ))
```

- [ ] **Step 2: Write mem.sh**

Create `~/.config/eww/scripts/mem.sh` with content:
```bash
#!/usr/bin/env bash
# Percent RAM used.
set -euo pipefail
free | awk '/Mem:/ { printf("%d\n", $3*100/$2) }'
```

- [ ] **Step 3: Write disk.sh**

Create `~/.config/eww/scripts/disk.sh` with content:
```bash
#!/usr/bin/env bash
# Percent root disk used.
set -euo pipefail
df / --output=pcent | tail -1 | tr -d ' %'
```

- [ ] **Step 4: Make all executable + smoke test**

```bash
chmod +x ~/.config/eww/scripts/{cpu,mem,disk}.sh
echo "cpu: $(~/.config/eww/scripts/cpu.sh)%"
echo "mem: $(~/.config/eww/scripts/mem.sh)%"
echo "disk: $(~/.config/eww/scripts/disk.sh)%"
```
Expected: three integer percentages between 0 and 100.

- [ ] **Step 5: Replace the stats-card widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget stats-card    [] (box :class "card"))
```
with:
```lisp
(defwidget stats-card []
  (box :class "card stats-card" :orientation "v" :spacing 8 :space-evenly false
    (label :class "card-title" :text "SYSTEM" :halign "start")
    (stat-row :name "CPU"  :value cpu)
    (stat-row :name "RAM"  :value mem)
    (stat-row :name "DISK" :value disk)))

(defwidget stat-row [name value]
  (box :orientation "h" :spacing 8 :space-evenly false
    (label :class "stat-name"  :text name :halign "start" :style "min-width: 40px;")
    (scale :class "stat-bar"
           :value value :min 0 :max 100
           :active false
           :hexpand true)
    (label :class "stat-pct" :text "${value}%" :halign "end" :style "min-width: 40px;")))
```

- [ ] **Step 6: Append stats styles**

Append to `~/.config/eww/eww.scss`:
```scss
.stats-card {
    .stat-name { color: $subtext; font-size: 11px; }
    .stat-pct  { color: $text;    font-size: 11px; }
    .stat-bar {
        trough {
            background-color: $surface0;
            border-radius: 4px;
            min-height: 6px;
        }
        highlight {
            background-color: $peach;
            border-radius: 4px;
            min-height: 6px;
        }
    }
}
```

- [ ] **Step 7: Reload + verify**

Run: `eww reload`
Expected: three labeled bars (CPU, RAM, DISK) updating live every 2s.

### Task 33: Eww widget — quick actions row

**Files:**
- Modify: `~/.config/eww/eww.yuck` (replace `actions-row` placeholder)
- Modify: `~/.config/eww/eww.scss` (append styles)

- [ ] **Step 1: Replace the actions-row widget**

In `~/.config/eww/eww.yuck`, replace:
```lisp
(defwidget actions-row   [] (box :class "card"))
```
with:
```lisp
(defwidget actions-row []
  (box :class "card actions-row" :orientation "h" :spacing 8 :space-evenly true :halign "center"
    (button :class "action-btn" :tooltip "Toggle wifi"
            :onclick "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on" "")
    (button :class "action-btn" :tooltip "Toggle bluetooth"
            :onclick "bluetoothctl power on || bluetoothctl power off" "")
    (button :class "action-btn" :tooltip "Toggle do-not-disturb"
            :onclick "makoctl mode | grep -q do-not-disturb && makoctl mode -r do-not-disturb || makoctl mode -a do-not-disturb" "")
    (button :class "action-btn" :tooltip "Lock screen"
            :onclick "eww close dashboard && hyprlock" "")
    (button :class "action-btn" :tooltip "Power menu"
            :onclick "eww close dashboard && wlogout --protocol layer-shell" "⏻")))
```

(Icons are Nerd Font glyphs; require JetBrainsMono NF — already the font.)

- [ ] **Step 2: Append actions-row styles**

Append to `~/.config/eww/eww.scss`:
```scss
.actions-row {
    .action-btn {
        font-size: 18px;
        color: $text;
        padding: 8px 12px;
        border-radius: 10px;
        background-color: $surface0;
        transition: all 150ms ease;
        &:hover {
            background-color: $surface1;
            color: $maroon;
        }
    }
}
```

- [ ] **Step 3: Reload + verify**

Run: `eww reload`
Expected: row of 5 icon buttons. Click each (be cautious with wifi/bluetooth toggles) to confirm they fire.

### Task 34: Wire the Super+W toggle keybind for the dashboard

**Files:**
- Modify: `~/.config/hypr/conf.d/90-keybinds.conf`
- Modify: `~/.config/hypr/conf.d/80-autostart.conf` (add eww daemon)

- [ ] **Step 1: Add eww-daemon to autostart**

In `~/.config/hypr/conf.d/80-autostart.conf`, add after the `mako` line (around the existing exec-once block):
```
# Eww daemon (dashboard widgets — toggle via Super+W)
exec-once = eww daemon
```

- [ ] **Step 2: Add the keybind**

In `~/.config/hypr/conf.d/90-keybinds.conf`, find the `# === Apps ===` section. Add a new line at the end of that section (before `# === Window ===`):
```
bind = $mod,        W,      exec, eww open --toggle dashboard
```

- [ ] **Step 3: Reload Hyprland + start eww daemon manually for this session**

Run:
```bash
hyprctl reload 2>/dev/null || true
eww daemon &
sleep 1
eww open --toggle dashboard
```
Expected: dashboard slides in. Press Super+W after relog to confirm toggle works.

### Task 35: Verify Wave 3

**Files:** none (verification only)

- [ ] **Step 1: Confirm wlogout config files exist and are valid**

Run:
```bash
ls -la ~/.config/wlogout/layout ~/.config/wlogout/style.css
```
Expected: both files present, non-empty.

- [ ] **Step 2: Confirm all eww scripts are executable**

Run:
```bash
ls -l ~/.config/eww/scripts/
```
Expected: weather.sh, media.sh, cpu.sh, mem.sh, disk.sh — all with executable bit (`-rwxr-xr-x` or similar).

- [ ] **Step 3: Confirm eww yuck parses**

Run:
```bash
eww reload 2>&1 | tail -20
```
Expected: no parse errors. (Empty output = success.)

- [ ] **Step 4: Confirm keybinds present in Hyprland config**

Run:
```bash
grep -E '(wlogout|eww)' ~/.config/hypr/conf.d/90-keybinds.conf ~/.config/hypr/conf.d/80-autostart.conf
```
Expected: shows the wlogout bind on Super+Escape, eww bind on Super+W, eww daemon in autostart.

### Task 36: Commit Wave 3

**Files:** all Wave 3 in-repo changes

- [ ] **Step 1: Stage in-repo files**

```bash
git add conf.d/80-autostart.conf conf.d/90-keybinds.conf
git status --short
```
Expected: two staged files. wlogout and eww configs live in `~/.config/wlogout/` and `~/.config/eww/` respectively — outside this repo by existing convention.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
Wave 3: wire wlogout power menu and eww dashboard

Super+Escape now opens wlogout (6-button layer-shell overlay, Catppuccin
Mocha with peach hover). Super+W toggles eww dashboard (header card, large
clock, calendar, weather via wttr.in, MPRIS media controls, CPU/RAM/disk
gauges, quick actions row). eww daemon starts at session login.

wlogout config in ~/.config/wlogout/, eww config in ~/.config/eww/ —
both outside this repo by existing convention.

EOF
)"
git tag wave-3-components
```

- [ ] **Step 3: Final user verification gate**

**STOP HERE.** Tell the user:

> Wave 3 committed (`wave-3-components`). Final relog → Hyprland verification:
> 1. `Super+Escape` → wlogout overlay shows 6 buttons, peach hover border.
> 2. Click "Lock" or press `l` → hyprlock comes up (peach check color, maroon ring).
> 3. `Super+W` → eww dashboard slides in from the left.
> 4. Header card shows your avatar + user@host + uptime.
> 5. Clock shows live hh:mm + date.
> 6. Calendar shows the month with today highlighted.
> 7. Weather card shows a temp + city (or "offline" if no network).
> 8. Media card responds to playerctl (start a song to test).
> 9. CPU/RAM/disk bars are live and peach-filled.
> 10. Quick action buttons fire (test wifi toggle gently!).
>
> If everything works → tag `aesthetic-pass-complete`:
> `git tag aesthetic-pass-complete`
>
> If anything fails — pinpoint which task, we'll iterate.

---

## Self-review notes

**Spec coverage check:** Every spec section maps to tasks above —
- Palette role assignment → Tasks 3–8 (each component repaint)
- Wallpaper engine swap → Tasks 1–2
- Hyprland blur → Task 11
- GTK Catppuccin → Tasks 12–13
- Papirus folder accent → Task 14
- Qt/Kvantum → Tasks 15–17
- Ghostty → Task 18
- wlogout → Tasks 21–24
- eww full dashboard (7 widgets) → Tasks 26–34
- Verification gates after each wave → Tasks 10, 20, 36

**Out-of-scope items in spec** (SDDM, Plymouth, mpvpaper, helix/nvim themes, Firefox userChrome, KDE session) — correctly not implemented in any task.

**Repo scope assumption** — this plan assumes `~/.config/hypr/` is the only tracked dir in the repo, so out-of-repo files (waybar, fuzzel, mako, gtk-*, Kvantum, qt6ct, ghostty, wlogout, eww) are edited on disk but not committed. The user previously chose this layout; expanding repo scope is a separate decision they can raise.
