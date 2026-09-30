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
   including the **entire Helix and Fish directories**.
5. Deploys the UWSM session, settings, writing tools and user services.
6. Uses a safe generic monitor profile on different hardware.
7. Validates Bash, Fish, JSON, Hyprland, Helix and Herdr.
8. Sets Fish as the installing user's login shell, with zoxide and Starship.

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

## Fish shell

The bootstrap installs `fish`, `zoxide` and `starship` from Tumbleweed and uses
`sudo chsh` to select `/usr/bin/fish` for the user running the installer, after
configuration validation succeeds. Log out and back in for terminals to pick
up the new login shell. Reinstalling skips the shell change if Fish is already
selected. With `--skip-packages`, these commands must already be installed.

[`portable/fish/conf.d/hypr-bootstrap.fish`](../portable/fish/conf.d/hypr-bootstrap.fish)
is deployed to `~/.config/fish/conf.d/`. It makes `~/.local/bin` available and
initializes zoxide (`z` and `zi`) and Starship in interactive shells. Existing
`config.fish`, functions and other snippets are preserved. Fish and Starship
settings use `$XDG_CONFIG_HOME` instead of `~/.config` when it is set.
An explicit `STARSHIP_CONFIG` keeps precedence over the bundled prompt theme.

When the login shell changes, its previous path is saved in the backup's
`login-shell` file. To undo the change, run `chsh -s /path/to/previous-shell`,
using that saved path, and log in again. Restore the backed-up Fish settings
and `starship.toml` as needed; remove `fish/conf.d/hypr-bootstrap.fish` if it did
not exist before installation.

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
