# Zen browser appearance

Catppuccin Mocha with Peach accents, matching the desktop. Browser chrome uses
Noto Sans, Mantle surfaces, Mocha address fields and menus, and a Peach marker
on the selected tab. Built-in pages use the same palette. Website styles and
fonts are controlled by the websites; Zen requests a dark color scheme.

Apply to an initialized native or Flatpak profile:

```bash
python3 ~/.config/hypr/scripts/zen-style.py --dry-run
python3 ~/.config/hypr/scripts/zen-style.py
```

Restart Zen after applying. For a new installation, open Zen once to create
its profile before running the helper. The Flatpak location is
`~/.var/app/app.zen_browser.zen/.zen/`. The helper selects the installation's
default profile from `profiles.ini`/`installs.ini`, ahead of an older legacy
`Default=1` profile. Use `--profile '/path/to/profile'` to choose explicitly.

The helper copies the local assets, prepends a marked import block to
`chrome/userChrome.css` and `chrome/userContent.css`, and appends a marked
appearance block to `user.js`. Existing customizations are retained. Repeating
the command updates the same blocks without duplicating them.

Before changes, it backs up `chrome/` and `user.js` under
`~/.local/state/hypr-bootstrap/backups/*-zen-*/`. `manifest.json` records the
target profile, newly created files, and prior appearance preference values.
No browsing data is copied into this bundle, and the running browser's
`prefs.js` is not edited.

To restore, close Zen, restore the backed-up files, and remove the newly
created files listed in the manifest. Preferences already loaded from
`user.js` persist in `prefs.js`: restore `previous_preferences` from the
manifest using `about:config` (reset an entry when its recorded value is
`null`). Restart Zen again after restoring the styles.

## Source and local adjustments

The vendored CSS and logo come from
[Catppuccin for Zen](https://github.com/catppuccin/zen-browser/tree/c855685442c6040c4dda9c8d3ddc7b708de1cbaa/themes/Mocha/Peach),
commit `c855685442c6040c4dda9c8d3ddc7b708de1cbaa`, under the included
[MIT license](CATPPUCCIN-LICENSE). No assets are fetched when Zen starts.

Upstream SHA-256 values verified before adaptation:

| File | SHA-256 |
|---|---|
| `userChrome.css` | `301595fb03db906e301103c7986a0088470f6b21b400e59e1e05ac342e074545` |
| `userContent.css` | `62534e9fe3a2092367db70293f40e01e990600e510c09d8a195a97e3c44d15ec` |
| `zen-logo-mocha.svg` | `b41be8bf6c8659c532a0b1b984488696073adb31aec7a089211d4f4a7ecd9a83` |

The CSS files are renamed to allow managed imports alongside existing user
styles. The content stylesheet uses the bundled logo without an upstream
network fallback. `hypr-mocha-peach.css` adjusts the current Zen 1.21 background
elements, neutral text/icons, focus colors, 10 px corners and selected tabs.

The appearance preferences enable user styles and request dark UI/content
with a Peach accent. Browser automation and remote debugging are not enabled
in the installed profile.

References: [Zen user styles](https://docs.zen-browser.app/guides/live-editing),
[Zen appearance preferences](https://docs.zen-browser.app/guides/about-config-flags).
