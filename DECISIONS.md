# Incorporated improvements

The following suggestions were implemented on August 8, 2026. This record
documents the decisions and components needed to reproduce the environment.

## High priority

1. **Waybar's `privacy`, `idle_inhibitor` and `power-profiles-daemon` modules.**
   The bar shows screen-sharing/microphone activity, can inhibit Hypridle,
   and switches between available power profiles.

2. **`hyprsunset`.** Native profiles switch to the identity profile at 07:00
   and 4500 K at 19:00. Eww also provides a manual toggle.

3. **Original volume and brightness OSD with `wob`.** Superseded by desktop
   controls below; retained as an optional fallback. A systemd-managed FIFO receives
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

13. **UWSM and systemd user services.** Waybar, notifications, Eww, awww, agents and
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

25. **Matching Alacritty style.** Reproduce Ghostty's Catppuccin Mocha palette,
    JetBrainsMono NF at 12 pt, 92% opacity, padding and block cursor. Hyprland
    supplies the shared window effects. Keep Ghostty as the default terminal;
    include Alacritty's settings, package and backup in the portable bootstrap.

26. **Matching Kitty style.** Replace the old Dank theme includes with the
    shared terminal palette, font, opacity and steady block cursor. Convert
    padding from pixels to Kitty's points; retain ligatures, existing shortcuts
    and tab layout with Mocha/Peach colors. Back up the Kitty directory and
    include the package and self-contained configuration in the bootstrap.

27. **Matching Zen browser style.** Use the official Catppuccin Mocha/Peach
    theme with local adjustments for Zen's current toolbar backgrounds, Noto
    Sans and selected tabs. Bundle the verified CSS, logo and license. Apply
    marked imports and appearance preferences to the installation's default
    profile with a backup; keep browsing data outside the portable bundle.

28. **Complete Mocha/Peach application themes.** Give Starship an explicit
    official Mocha palette and Peach prompt accents without changing its layout.
    Replace Yazi's small overlay with the full official theme, retaining Peach
    tabs and adding Catppuccin syntax previews. Apply the official Obsidian
    theme with Mocha/Peach selected through Style Settings and shared desktop
    fonts. Pin the bundled sources and licenses; merge vault appearance and
    plugin settings with a manifest and backup, without copying vault content.

## Desktop controls — September 5, 2026

29. **One notification center.** SwayNC replaces the running Mako daemon and
    supplies history, grouping, actions and real DND. Bar, keyboard and Eww
    controls share one interface. Mako remains an inactive fallback with an
    actual suppression rule for its DND mode.

30. **Sound controls and a passive OSD.** Reuse the native GTK tray card style
    for device/port selection, microphone mute and application volumes. Route
    existing streams when selecting a device. Refreshes never write volume or
    routing. The supervised overlay handles volume, mic and backlight feedback
    without taking keyboard or pointer input; Wob stays disabled by default.

31. **Focus without overwriting DND.** A persistent 25/50-minute timer acquires
    a dedicated SwayNC inhibitor and releases only that inhibitor on completion
    or cancellation. Pausing retains quiet notifications. Preserve user DND
    changes and other applications' inhibitors. The daemon handles deadlines
    independently of whether Waybar or the popup is open.

32. **A visual clipboard without a second history.** Fuzzel searches Cliphist
    with text previews and temporary image previews for the first 40 images.
    Selection copies original bytes; cancellation leaves the clipboard alone.
    Temporary previews are removed on exit and never enter the repository.

33. **A quieter bar and reusable scratchpads.** Move Bluetooth, power profile,
    keep-awake, CPU and memory into a hover drawer while leaving recording,
    microphone privacy and VPN indicators visible. Dedicated Ghostty app IDs
    and launch locks make terminal/notes shortcuts reuse one window each.
    Hide through Lua's `follow=false`; keep notes in the user's data directory.
