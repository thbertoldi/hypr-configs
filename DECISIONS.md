# Incorporated improvements

The following suggestions were implemented on August 8, 2026. This record
documents the decisions and components needed to reproduce the environment.

## High priority

1. **Waybar's `privacy`, `idle_inhibitor` and `power-profiles-daemon` modules.**
   The bar shows screen-sharing/microphone activity, can inhibit Hypridle,
   and switches between available power profiles.

2. **`hyprsunset`.** Native profiles switch to the identity profile at 07:00
   and 4500 K at 19:00. Eww also provides a manual toggle.

3. **Volume and brightness OSD with `wob`.** A systemd-managed FIFO receives
   values from the `wpctl` and `brightnessctl` wrappers.

4. **`hyprpolkitagent`.** The native agent replaced the MATE agent and runs
   under user-systemd supervision.

## Useful workflows

5. **Screenshot annotation with `swappy`.** `Super+Print` captures a region
   and opens the editor; existing Print shortcuts remain quick.

6. **Screen recording with `wf-recorder`.** `Super+Alt+R` selects an area,
   records H.264/FLAC to `~/Videos/Recordings`, and shows recording status
   in Waybar.

7. **`udiskie` for removable media.** Automount, notifications, LUKS support
   and a tray icon are enabled.

8. **`hyprpicker` shortcut.** `Super+Shift+C` copies a hexadecimal color
   and sends a notification.

## Eww widgets

9. **Clipboard card.** The dashboard shows the six most recent entries,
   supports copying them, and allows individual removal.

10. **Audio and brightness sliders.** They adjust PipeWire/backlight directly
    and show output, mute and microphone state.

11. **Reactive quick toggles.** Wi-Fi, Bluetooth, DND and night light reflect
    real state through `on/off` visual classes.

12. **Event-driven updates.** Media/audio use continuous streams; brightness
    uses `inotify`, avoiding once-per-second polling.

## Structural changes

13. **UWSM and systemd user services.** Waybar, Mako, Eww, awww, agents and
    utilities became supervised units. At migration time, the running session
    used the compatibility target; choosing **Hyprland (UWSM)** at the next
    login also handed the compositor lifecycle to UWSM.

14. **Plugins only for concrete needs.** No arbitrary compositor plugin was
    loaded. Plugins must match Hyprland's exact ABI; when there is a use case,
    use `hyprpm`, review the code, and do not mix `-git` packages with the
    Tumbleweed stack.

## Calendar and agents

15. **Unified modern calendar.** DankCalendar aggregates Google and personal
    Outlook with OAuth, uses Microsoft Graph, keeps synchronization/reminders
    running in the background, and supplies Eww's upcoming events through IPC.
    Its dark theme matches the desktop. Merkuro and KOrganizer/Akonadi remain
    fallbacks; Proton stays in the browser rather than using bidirectional
    CalDAV.

16. **Local agent menu.** `Super+G` starts Codex in a selected directory with
    the smallest appropriate sandbox. Changes outside the workspace still
    require escalation/approval; there is no silent unrestricted-access shortcut.

## Integrated study

17. **Anki Study Hub.** Waybar and Eww show the daily workload and open
    Kubernetes, NVIDIA/GPU on Kubernetes, or French directly. Sixty curated
    starter notes coexist with existing decks; `Super+Shift+A` opens the full
    study session.

18. **French with verifiable audio.** Starter sentences have cached MP3s and
    HyperTTS fallback. Legacy templates referring to `AwesomeTTS` are backed
    up and migrated to `HyperTTS`; a diagnostic checks versions, templates and
    synthesis without playing audio.

19. **Study agent with explicit limits.** The agent menu gained a profile
    using authenticated local AnkiConnect. Bulk changes, template edits and
    deletion require confirmation; the profile prompt prohibits direct SQLite
    access.

## Music

20. **Reliable Spotify with an alternative interface.** The official client
    supplies login, library access and playback; Spicetify applies
    Sleek/Catppuccin and adds a visual Marketplace. User-scoped Flatpak
    deployment avoids `sudo`. `Super+M`, Eww and a custom StatusNotifier open
    the client and control MPRIS. The tray shows the track/artist and provides
    play/pause, previous/next, shuffle, repeat and copy-link actions.
    Customization versions/downloads are pinned and verified with SHA-256.

## Terminal writing and portability — September 5, 2026

21. **Helix and Yazi as defaults.** Preserve the existing Helix configuration,
    Lua API settings and custom RPM-spec grammar, with a full backup before
    changes. Add standalone Marksman, visual Markdown wrapping, Glow reading
    and a small bibliography-key picker. Keep standard editor key bindings;
    do not require a Neovim or Herdr plugin.

22. **Portable preview support.** Deploy Herdr's Mocha/Peach theme and Kitty
    graphics setting, Yazi's Helix/Glow openers, and distro preview dependencies.
    New Herdr panes are required after first enabling graphics forwarding.

23. **One supported installation target.** Keep the reference focused on
    Tumbleweed amd64, with generic monitor defaults and verified standalone
    binaries. Personal data and toolchains beyond the configured baseline are
    transferred separately. SilverBullet stays optional.

24. **English documentation.** Keep the README, workflow guide, decision log,
    asset instructions and installer help in English. Existing application UI
    labels and language-learning materials are not translated as documentation.
