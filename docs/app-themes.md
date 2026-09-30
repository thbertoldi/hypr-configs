# Starship, Yazi and Obsidian themes

These applications use Catppuccin Mocha, with Peach (`#fab387`) as the primary
accent. The bundled files work offline. Original download hashes, versions and
paths are recorded in [`portable/catppuccin-app-sources.json`](../portable/catppuccin-app-sources.json).

## Sources

| Asset | Pinned upstream revision |
|---|---|
| [Starship Mocha palette](https://github.com/catppuccin/starship) | `5906cc369dd8207e063c0e6e2d27bd0c0b567cb8` |
| [Yazi Mocha/Peach theme](https://github.com/catppuccin/yazi) | `d62802be39210ea10e54b3e3b09735c6cb9e57c1` |
| [Mocha syntax highlighting](https://github.com/catppuccin/bat) | `6810349b28055dce54076712fc05fc68da4b8ec0` |
| [Obsidian Catppuccin theme](https://github.com/catppuccin/obsidian) | `1316e03af5c31964116661ab08e7784bfa1d00b3` (0.4.49; Obsidian 1.13.0+) |
| [Obsidian Style Settings](https://github.com/community-archive/obsidian-style-settings/tree/1.0.9) | `1.0.9`, official release assets |

Catppuccin's MIT license accompanies each bundle. The Style Settings bundle
includes its GPL license; the linked tag provides the corresponding source.
The original Yazi and Starship files have the adaptations described below;
Obsidian's upstream theme and plugin files are unmodified.

## Starship

[`portable/starship/starship.toml`](../portable/starship/starship.toml) installs
to `~/.config/starship.toml`. It retains the default prompt layout and module
detection, using Peach for the directory, successful prompt and package version.
Errors stay red and Vim's normal mode uses green. The complete official Mocha
palette is embedded, with aliases for default ANSI color names and overrides
for modules that otherwise use fixed indexed or RGB colors.

The bootstrap installs Fish, zoxide and Starship, backs up existing settings,
and selects Fish as the login shell. Its managed Fish snippet initializes
Starship and zoxide for interactive sessions while preserving `config.fish`.
The theme takes effect in new shells after login. Fish and Starship settings
follow `$XDG_CONFIG_HOME` when set; see the [shell setup and restoration
instructions](installation.md#fish-shell). Other shells can use Starship's
[shell integration instructions](https://starship.rs/guide/#step-2-set-up-your-shell-to-use-starship).

## Yazi

[`portable/yazi/theme.toml`](../portable/yazi/theme.toml) contains the full
official Mocha/Peach theme, including file icons, menus, help, confirmations,
status indicators and file types. Local changes set the overall foreground to
Mocha Text, the working directory and active tab to Peach, borders to Surface 1,
and the progress label to Mocha Text.

`Catppuccin-mocha.tmTheme` provides the preview pane's syntax highlighting.
The configured path is `~/.config/yazi/Catppuccin-mocha.tmTheme`; update
`mgr.syntect_theme` if you move Yazi's configuration to a custom location.
The Helix/Glow openers remain in `yazi.toml`. Reopen Yazi after installation.

## Obsidian

[`scripts/obsidian-style.py`](../scripts/obsidian-style.py) installs the theme
and Style Settings into the vault's configuration folder. It merges the
appearance preferences and the two Catppuccin flavor/accent settings, and
adds Style Settings to the existing enabled plugin list. Noto Sans is used for
the interface and note text; JetBrainsMono NF is used for code.

The helper reads the native and Flatpak registries to find open vaults. It does
not search or read notes. An explicit vault and a custom configuration folder
are also supported:

```bash
python3 ~/.config/hypr/scripts/obsidian-style.py --dry-run
python3 ~/.config/hypr/scripts/obsidian-style.py --vault "/path/to/vault"
python3 ~/.config/hypr/scripts/obsidian-style.py --vault "/path/to/vault" --config-folder .obsidian-desktop
```

The bootstrap applies this to already initialized, open vaults. Obsidian itself
must already be installed; on a new machine, open the vault once before running
the helper. Reload Obsidian after the first application. Style Settings exposes
the theme's Mocha flavor and Peach accent in Obsidian's settings UI.

Before writing, the helper snapshots only the files it will replace beneath
`~/.local/state/hypr-bootstrap/backups/<timestamp>-obsidian-<pid>/`. Its
`manifest.json` records the vault, affected paths and newly created files.
Repeated application is idempotent. Unrelated appearance preferences, snippets,
plugins and Style Settings entries are preserved.

To restore, close Obsidian, copy the saved files back into the vault's configuration
folder and remove only the new files listed in that backup's `created_files`.
Keep any newer settings changes when restoring `appearance.json` or
`community-plugins.json`. Reopen Obsidian afterward.
