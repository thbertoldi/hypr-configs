# Third-party notices

The repository's [MPL 2.0 license](LICENSE) covers original configuration,
automation and documentation. It does not relicense the material below.
Retain these notices and the associated license files when redistributing it.

## Catppuccin — MIT

Copyright (c) 2021 Catppuccin. The theme ports and palette adaptations retain
the MIT license. The full notice is included beside each bundled theme.

| Material | Upstream | License text |
|---|---|---|
| Starship Mocha palette | [catppuccin/starship](https://github.com/catppuccin/starship) | [Starship notice](portable/starship/CATPPUCCIN-LICENSE) |
| Yazi Mocha/Peach theme | [catppuccin/yazi](https://github.com/catppuccin/yazi) | [Yazi notice](portable/yazi/CATPPUCCIN-LICENSE) |
| Yazi syntax theme (`Catppuccin-mocha.tmTheme`) | [catppuccin/bat](https://github.com/catppuccin/bat) | [Yazi notice](portable/yazi/CATPPUCCIN-LICENSE) |
| Obsidian theme and manifest | [catppuccin/obsidian](https://github.com/catppuccin/obsidian) | [Obsidian theme notice](portable/obsidian/CATPPUCCIN-LICENSE) |
| Zen browser theme, content styles and logo | [catppuccin/zen-browser](https://github.com/catppuccin/zen-browser) | [Zen notice](portable/zen/CATPPUCCIN-LICENSE) |
| ZapZap theme | [catppuccin/userstyles — WhatsApp Web](https://github.com/catppuccin/userstyles/tree/main/styles/whatsapp-web) | [ZapZap notice](portable/zapzap/CATPPUCCIN-LICENSE) |

The remaining original desktop and terminal styles use the Catppuccin palette;
the bundled MIT notices preserve the palette's attribution as well.
Pinned revisions and SHA-256 hashes for the newer app themes are recorded in
[`portable/catppuccin-app-sources.json`](portable/catppuccin-app-sources.json).
Local styling changes are described in [the app theme guide](docs/app-themes.md)
and [Zen's guide](portable/zen/README.md).

## Obsidian Style Settings 1.0.9 — upstream GPLv3 notice

[`portable/obsidian/plugins/obsidian-style-settings/`](portable/obsidian/plugins/obsidian-style-settings/)
contains the unmodified release assets from
[community-archive/obsidian-style-settings](https://github.com/community-archive/obsidian-style-settings/tree/1.0.9),
originally authored by mgmeyers and contributors. Its
[`LICENSE.md`](portable/obsidian/plugins/obsidian-style-settings/LICENSE.md)
contains the GNU General Public License, version 3.

The upstream `package.json` at this tag says MIT, which is inconsistent with its
license file. This repository preserves the GPLv3 notice and does not assert
that the bundled plugin is permissively licensed or covered by the project MPL.
Dependency notices embedded in the release remain intact.

The full upstream source tree, build scripts and lockfile accompany the release
in [`third-party/`](third-party/README.md). Keep that source and its license when
redistributing the bundled plugin. The original asset URLs and hashes are also
in the app-source manifest linked above.

## Helix RPM-spec highlighting — MPL 2.0

[`portable/helix/runtime/queries/rpmspec/highlights.scm`](portable/helix/runtime/queries/rpmspec/highlights.scm)
is the upstream Helix query, distributed under Helix's MPL 2.0 license.
The [source record](third-party/README.md#helix-query) identifies the checked revision;
the full MPL text is available in the root [LICENSE](LICENSE).

The RPM-spec parser itself is fetched separately from the revision declared in
[`portable/helix/languages.toml`](portable/helix/languages.toml).

## Downloaded applications, tools and assets

The bootstrap also obtains software, fonts, cursors and themes from distribution
packages, Flathub and upstream releases. These downloads are not relicensed by
this repository. Their upstream licenses and notices continue to apply.
Spicetify, Marketplace, Sleek, Anki add-ons, Herdr and Marksman are examples of
separately obtained components; their sources are referenced by the installer.

User-supplied wallpapers, avatars, vaults and collections are not included in
the project license. Repository badges identify technologies; no endorsement
by the corresponding projects is implied.
