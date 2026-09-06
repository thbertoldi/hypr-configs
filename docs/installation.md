# Installation and portability

[Back to the repository overview](../README.md)

### 1. Get the repository

```bash
git clone https://github.com/thbertoldi/hypr-configs.git ~/hypr-bootstrap
cd ~/hypr-bootstrap
```

To transfer a reviewed, committed snapshot without `.git/` history or ignored
local files, create a source archive:

```bash
git archive --format=tar --output=../hypr-configs.tar HEAD
```

Extract that archive on the destination machine. Supply personal wallpaper and
avatar files separately. See the [sharing guide](sharing.md) before distribution.

### 2. Review the plan

```bash
chmod +x bootstrap-opensuse-tumbleweed.sh
./bootstrap-opensuse-tumbleweed.sh --dry-run
```

### 3. Install

Run as your normal user; the installer requests `sudo` where needed.

```bash
./bootstrap-opensuse-tumbleweed.sh \
  --with-extras \
  --wallpaper ~/Pictures/my-wallpaper.jpg \
  --avatar ~/Pictures/my-avatar.jpeg
```

The bootstrap:

1. Checks for openSUSE Tumbleweed x86_64 and installs dependencies.
2. Installs DankCalendar, Zen, Spotify, ZapZap and Anki from Flathub where needed.
3. Downloads visual assets and Herdr/Marksman binaries with pinned SHA-256 hashes.
4. Backs up configuration under `~/.local/state/hypr-bootstrap/backups/`,
   including the **entire Helix directory**.
5. Deploys the UWSM session, settings, writing tools and user services.
6. Uses a safe generic monitor profile on different hardware.
7. Validates Bash, JSON, Hyprland, Helix and Herdr.

The goal is a **similar configured experience**, not an immutable OS snapshot:
distro packages follow Tumbleweed, and existing Herdr/Marksman binaries are
retained. Distributable app settings live in `portable/`; update those too
when a local customization should carry over to the next installation.
The complete installation bundle and guides remain in `~/.config/hypr/`.

At the next login, select **Hyprland (UWSM)** in the display manager.

### Bootstrap options

| Option | Effect |
|---|---|
| `--with-extras` | Also install the `wev` Wayland event inspector |
| `--same-hardware` | Keep this computer's LG ultrawide + `eDP-1` profile |
| `--internal-output eDP-2` | Replace the expected internal display name |
| `--wallpaper FILE` | Install the wallpaper used by awww |
| `--avatar FILE` | Install the Eww avatar |
| `--skip-packages` | Skip zypper and Herdr/Marksman installation; dependencies must already exist |
| `--skip-themes` | Skip font, cursor and theme downloads |
| `--dry-run` | Show actions without changing the machine |

## Monitors and portability

This machine's [`lua/monitors.lua`](../lua/monitors.lua) implements a
**single-active-display** workflow:

- Docked: LG ultrawide at `3440x1440@85`, internal display off.
- Undocked: `monitor-listener.sh` re-enables the laptop display.
- Workspaces are not tied to a connector, so switching from `DP-1` to
  `HDMI-A-1` does not leave them stranded.

The LG is matched by its
[`desc:`](https://wiki.hypr.land/Configuring/Basics/Monitors/), not an unstable
connector name. On another computer, the bootstrap installs
[`portable/monitors-generic.lua`](../portable/monitors-generic.lua), which uses
preferred modes and automatic positioning. Only use `--same-hardware` on a
genuinely equivalent machine.

After your first login:

```bash
hyprctl monitors
$EDITOR ~/.config/hypr/lua/monitors.lua
hyprctl reload
```
