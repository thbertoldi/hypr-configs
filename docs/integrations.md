# Application integrations

[Back to the repository overview](../README.md) · [Desktop controls](desktop-controls.md)

## Terminals

Ghostty is the default on `Super+Return`. Open Alacritty or Kitty from Fuzzel,
or run `alacritty` or `kitty`, for the same Catppuccin Mocha colors,
JetBrainsMono NF at 12 pt, 92% background opacity, 12×10 padding and block cursor.
Hyprland supplies the blur, rounded corners, shadows and peach borders.
Selection copies to the clipboard, and the mouse pointer hides while typing.

The bootstrap installs both terminals and deploys their settings, backing up
existing configuration first:

| Terminal | Portable configuration | Installed location |
|---|---|---|
| Alacritty | [`portable/alacritty/alacritty.toml`](../portable/alacritty/alacritty.toml) | `~/.config/alacritty/alacritty.toml` |
| Kitty | [`portable/kitty/kitty.conf`](../portable/kitty/kitty.conf) | `~/.config/kitty/kitty.conf` |

Reopen the terminal after the initial setup. Subsequent theme edits reload live
in Alacritty; use `Ctrl+Shift+F5` to reload Kitty's configuration.
Alacritty has no native tabs and does not render Ghostty's font ligatures
([upstream tracking issue](https://github.com/alacritty/alacritty/issues/50)).
Kitty renders ligatures and keeps its existing shortcuts and slanted tab bar,
with a peach active tab. Its padding uses 7.5 vertical / 9 horizontal points
to match Ghostty's 10 / 12 pixels at 96 DPI. The settings are self-contained;
the old `dank-theme.conf` and `dank-tabs.conf` files are no longer included.
See the [Kitty configuration reference](https://sw.kovidgoyal.net/kitty/conf/).

## Desktop portal recovery

`portal-healthcheck.timer` checks the running Hyprland portal once a minute.
It restarts the portal only after two five-second D-Bus probe failures, each
accompanied by CPU use above half a core. Waiting in a screen picker, normal
screen sharing, an immediate bus error, or an inactive portal does not trigger
recovery. The timer stops with the graphical session.

This mitigates the unbounded screencast startup loop described in
[upstream issue #433](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/433),
which remains present in 1.4.1. It does not patch the upstream implementation.
A recovery interrupts portal screen sharing and portal-managed shortcuts;
applications may need to start their sharing session again.

The portal's systemd drop-in limits starts to three per ten minutes and forces
a stuck process to exit after ten seconds during a restart. If the limit is
reached, inspect the journal and the application triggering the hang before
manually recovering:

```bash
journalctl --user -u portal-healthcheck.service -u xdg-desktop-portal-hyprland.service
systemctl --user reset-failed xdg-desktop-portal-hyprland.service
systemctl --user start xdg-desktop-portal-hyprland.service
```

Disable automatic checks with `systemctl --user disable --now portal-healthcheck.timer`.
The bootstrap deploys these units and enables the timer for future sessions.

## Starship, Yazi and Obsidian

Starship uses the official Mocha palette with a Peach directory and prompt,
while retaining its default layout. Yazi uses the full Mocha/Peach theme for
its interface and icons, with matching code preview syntax highlighting.
The bootstrap deploys both configurations and backs up the existing files.
Starship updates on the next prompt; reopen Yazi to load its theme.

Obsidian uses the official Catppuccin theme and Style Settings with Mocha and
Peach selected, Noto Sans for the interface and notes, and JetBrainsMono NF
for code. The bootstrap themes already initialized, open vaults. To apply it
separately or after opening a vault on a new machine, run:

```bash
python3 ~/.config/hypr/scripts/obsidian-style.py
```

Reload Obsidian afterward. The helper supports `--dry-run`, `--vault PATH`
and `--config-folder NAME`, and backs up the affected settings before merging.
See [app theme sources and restoration](app-themes.md) for details.

## Zen browser

Zen uses Catppuccin Mocha/Peach with Noto Sans, dark sidebars and menus,
rounded controls, and a Peach marker on the selected tab. Built-in pages share
the palette. The bootstrap installs Zen if needed and themes existing default
profiles while preserving their customizations and browsing data.

On a new installation, open Zen once to initialize its profile, then run:

```bash
python3 ~/.config/hypr/scripts/zen-style.py
```

Restart Zen to load the theme. The helper supports `--dry-run` and an explicit
`--profile PATH`; it backs up the affected styles and `user.js` before changing
them. See [`portable/zen/README.md`](../portable/zen/README.md) for profile handling,
upstream sources and restoration instructions.

## Calendar

[DankCalendar](https://github.com/AvengeMedia/dankcalendar) is the main calendar
interface. The Waybar clock, `Super+O` and Eww's **Agenda** button open a
floating window sized for the monitor. Eww gets upcoming events through the
local API.

Hover over the Waybar date/time for a large local clock, full date and a
Monday-first month calendar with today highlighted. Scroll over the clock to
browse months; moving the pointer away returns the calendar to the current
month. The hover uses the same Mocha surface and peach accents as the trays.

The calendar tray opens a matching **Mocha/Peach month and agenda popup**.
Select a date to see its events, use **Upcoming** to return to the agenda, or
click an event to open its details in DankCalendar. **New event** opens a draft
for the selected date; saving happens in the calendar app. The footer also
opens the full calendar and syncs connected accounts. Middle-clicking the tray
opens the full calendar; `Esc` or an outside click dismisses the popup.

`calendar-tray.service` reads the existing daemon's local API. DankCalendar
continues syncing and showing reminders with its original tray icon hidden.

Add accounts in the **Accounts** panel or from a terminal:

```bash
~/.config/hypr/scripts/dcal.sh account add google
~/.config/hypr/scripts/dcal.sh account add microsoft
```

- Google and personal Outlook use browser-based OAuth.
- Middle-clicking the clock also opens Outlook on the web.
- Proton Calendar opens exclusively on the web.
- Merkuro/KOrganizer and Akonadi remain available as fallbacks.

Tokens stay in KWallet and are not included in the repository.

## Messaging

[ZapZap](https://github.com/rafatosta/zapzap) replaces Whatsie as the main
WhatsApp client. The bootstrap installs the user-scoped Flatpak, requests dark
mode and injects static global CSS using the desktop's Catppuccin Mocha/Peach
colors. The versioned theme is in [`portable/zapzap/`](../portable/zapzap/).

Open **ZapZap** through Fuzzel and complete its setup wizard. Sign in using the
official WhatsApp Web QR code. Whatsie is not automatically removed, so it can
remain a fallback until you have checked the migration.

Cookies, sessions, messages and downloads stay in ZapZap's private Flatpak
profile and are not versioned.

## Music

The official Spotify client supplies authentication, library access and
playback. [Spicetify](https://github.com/spicetify/cli) applies
**Sleek/Catppuccin** and adds a visual Marketplace for themes, snippets and
extensions. The user-scoped Flatpak makes customization reversible without
root access. A system-wide Spotify installation can coexist unchanged.

`Super+M` and Eww's **Spotify** button show a centered Wayland window without a
title bar, sized for the current monitor. **Super+Q hides Spotify** on its own
special workspace while playback continues; `Super+M` restores it to the current
workspace. Other applications retain their normal close behavior. To exit the
client, use **Quit Spotify** in the tray player or Spotify's own Quit command.

Click the Spotify tray icon for a **Mocha/Peach player popup** with album art,
track/artist/album, seek bar, play/pause, previous/next, shuffle, repeat and Spotify
volume. The footer opens or hides Spotify, copies the track link, or quits it.
Click outside or press `Esc` to dismiss the popup. Middle-click the tray icon to
play/pause; scroll over it to adjust Spotify's volume. Controls follow MPRIS
changes immediately and disable unavailable actions. Artwork loads in the
background with a placeholder when offline.

`spotify-tray.service` uses GTK 3, GtkLayerShell and the StatusNotifier protocol;
its colors live in `scripts/spotify-tray.css`. The tray, dashboard, `playerctl`
and hardware keys all use MPRIS. A narrowly scoped Flatpak override blocks
Spotify's redundant native tray indicator, leaving one icon. Closing to the
background uses the compositor's `Super+Q` binding and the popup's Hide action;
Spotify's own Quit command remains an actual exit.

The customization installer pins and verifies Spicetify 2.44.0, Marketplace
1.0.9 and both Sleek theme files using SHA-256. Spotify updates may require
rerunning `~/.config/hypr/scripts/spotify-customize.sh`. Login, library, history
and cache remain private to the Flatpak profile.

On a fresh installation, open Spotify, sign in and wait at least 60 seconds
before running `spotify-customize.sh`. This lets Spotify create the files
Spicetify expects. The bootstrap automatically applies customization to
already-authenticated profiles.

## Steam

The Steam tray opens a **Mocha/Blue game launcher** with cached cover art and
the four most recently played installed games. **Play** launches the selected
game; the footer opens Library, Downloads, Friends, or quits Steam. The status
shows whether Steam is running and how many updates its local manifests list
as pending. Middle-click opens Library; `Esc` or an outside click dismisses
the popup. Opening the tray itself does not start Steam.

`steam-tray.service` reads local Steam libraries and artwork, including games
on additional disks. It shares `scripts/tray-popups.css` and the GTK popup
helpers with the calendar tray. The bootstrap enables both services and runs
`scripts/configure-app-trays.py` to hide the native DankCalendar icon and block
the Steam Flatpak's duplicate indicator. Steam needs one restart for this
override to take effect. Previous preferences are backed up under
`~/.local/state/hypr-trays/backups/`. Steam itself must already be installed.

## Study Hub

Study Hub integrates [Anki](https://apps.ankiweb.net/) with Waybar, Eww, Fuzzel
and local agents.

The Anki hover in Waybar shows today's Study Hub queue, colored new/learning/
review counts, per-deck queues and today's review count across all decks.
Per-deck counts share the parent deck's daily limit and are not added together
as a daily target. The hover only reads the existing status; click to study,
middle-click for French, or right-click for the study agent.

| Deck | Notes | Cards |
|---|---:|---:|
| Kubernetes Core | 18 | 18 |
| NVIDIA GPUs on Kubernetes | 18 | 18 |
| French Essentials | 24 | 48 |
| **Total** | **60** | **84** |

Technical notes link to primary documentation. French sentences have
recognition and production cards with cached MP3s in Anki's media collection.
Seeding is idempotent and does not replace imported decks.

AnkiConnect:

- Listens only on `127.0.0.1:8765`.
- Requires a random key stored with `0600` permissions.
- Is installed from a reviewed release pinned by SHA-256.
- Never requires direct edits to Anki's SQLite database.

With Anki open, validate TTS, templates and media without playing audio:

```bash
~/.config/hypr/scripts/study-tts-check.sh
```

AnkiWeb login, collection, history and personal media are not versioned.

## Local agents

`Super+G` starts Codex in Ghostty with profiles for:

- Editing this configuration.
- Planning with the calendar.
- Creating or reviewing flashcards.
- Working in a selected folder.
- Inspecting the computer read-only.
- Resuming previous conversations.

Editing profiles use `workspace-write` and `on-request` approval. Bulk Anki
operations, template changes and deletion require explicit confirmation.
Run `codex login` before first use.
