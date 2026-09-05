# Writing in the terminal

The default is **Ghostty → optional Herdr → Yazi + Helix**. Use a normal
terminal when you do not need persistent panes. No editor plugin manager or
Neovim integration is required; existing Neovim/nnn installations are not removed.

## What Helix supplies

Helix 25.07.1 includes Markdown syntax highlighting, multiple selections,
soft wrapping, fuzzy file/buffer pickers, project search, splits, Git change
indicators, system clipboard integration and an LSP client. It edits Markdown
source, not a rendered/WYSIWYG page. Start with `hx --tutor`—Helix selects text
**before** acting on it, unlike many Vim motions.

This bundle preserves the existing Catppuccin Mocha theme, relative line numbers,
status line, Lua/Hyprland stubs, TOML/Bash formatting, LaTeX wrapping and custom
RPM-spec highlighting. Markdown wraps visually without rewriting paragraphs
on save. Standard Helix key bindings are unchanged.

External tools supplied by the bootstrap:

| Tool | Purpose |
|---|---|
| Marksman | Markdown heading/link completion, navigation and link diagnostics |
| Glow | Read rendered Markdown in the terminal |
| Pandoc + `cite-pick.sh` | Find real bibliography keys and copy Pandoc citations |
| Lua language server, Taplo, Texlab, shfmt, ShellCheck | Existing coding/LaTeX tooling |
| Yazi + Poppler, ImageMagick, resvg, FFmpeg, 7zip | File browsing and PDF/image/SVG/video/archive previews |
| Herdr | Optional persistent terminal workspace; Mocha/Peach and Kitty graphics enabled |

Language servers are separate executables, not bundled in Helix. Other languages
keep Helix's defaults; install their servers/toolchains when needed and check
`hx --health LANGUAGE`. Spell-checking, citation completion and rendered previews
are **not** native features of this stable Helix setup. Marksman does not resolve
Pandoc bibliography keys; the picker below does. Texlab is not a TeX distribution.

## Daily routine

```bash
cd ~/Documents/Dissertation
herdr                     # optional: reattaches to the existing workspace
```

Inside the chosen terminal/Herdr tab, use these as needed:

```bash
yazi                      # browse; Enter opens text in Helix
hx path/to/draft.md        # or open directly (helix is the same editor)
glow -p path/to/draft.md   # rendered reading; q exits
```

Use the project root, containing `.git` or an empty `.marksman.toml`, for
cross-file Marksman navigation. Save before reading with Glow; it reads the
file on disk and does not live-refresh. In Yazi, `o`/Enter opens the selection;
`O` offers **Read Markdown** for `.md` files. `q` returns to the terminal.
`~` opens Yazi's help. `Super+E` launches Yazi in Ghostty.

In Herdr, press `Ctrl+b`, then the next key: `c` creates a tab (name it if
prompted), `q` detaches.
Run `herdr` again to reattach. This avoids opening a separate GUI window for
each tool. Use `Super+Shift+Space` to float the Ghostty window when desired.

### Helix quick reference

Keys separated by spaces are pressed in sequence, in normal mode (`Esc`).

| Task | Keys / command |
|---|---|
| Learn the selection-first model | `hx --tutor` |
| Insert / return to normal mode | `i` / `Esc` |
| Save / quit | `:w` / `:q` (`:wq` does both) |
| Find a file / switch buffer | `Space f` / `Space b` |
| Search this file / project | `/` / `Space /` |
| Heading outline (Marksman) | `Space s` |
| Follow Markdown link / return | `g d` / `Ctrl+o` |
| Select a line; extend down | `x`; repeat `x` |
| Undo / redo | `u` / `U` |
| Copy / paste system clipboard | `Space y` / `Space p` |
| Reflow selected prose, only when wanted | `:reflow` |
| Split right / switch split | `Ctrl+w v` / `Ctrl+w w` |

## Citations and quotations

Keep your Zotero-exported bibliography with the project (for the dissertation,
`bibliography/library.bib`). In another terminal/Herdr tab:

```bash
~/.config/hypr/scripts/cite-pick.sh bibliography/library.bib
```

Search by author, title, year or key, press Enter, then paste in Helix with
`Space p`. The helper copies `[@actualKey]`; cancelling changes nothing. It
reads only the file you provide, so use a paper's own `.bib` when appropriate.
It does not query Zotero, change the bibliography, or generate source text.

Pandoc forms: `[@actualKey]` (parenthetical), `@actualKey` (narrative),
`[@actualKey, p. 42]` (locator), `[@firstKey; @secondKey]` (multiple sources).
Replace these example keys with real keys. A quotation is ordinary Markdown:

```markdown
> Exact words checked against the source. [@actualKey, p. 42]
```

Check wording and page numbers against the actual source. Glow is a Markdown
reader, not a bibliography processor. For formatted references, use the project's
existing build or Pandoc, for example (choose a new output filename):

```bash
pandoc draft.md --citeproc --bibliography=bibliography/library.bib -o review.html
```

Add `--csl=path/to/style.csl` for your required citation style. PDFs additionally
need a suitable PDF engine/fonts; this bundle does not install a full TeX stack.

## Reproduce / check

Supported target: **openSUSE Tumbleweed, amd64/x86_64**. Follow the
[desktop installation instructions](README.md#installation), beginning with
`./bootstrap-opensuse-tumbleweed.sh --dry-run`. This is a similar configured
experience, not a frozen OS image: distro packages follow Tumbleweed; existing
Herdr/Marksman binaries are retained. New installs use verified upstream Herdr
0.8.2 and Marksman 2026-02-08 binaries. The RPM parser source is commit-pinned.

The installer backs up the **whole Helix directory**, Yazi, Herdr's config and
the desktop settings under `~/.local/state/hypr-bootstrap/backups/` before
deployment. Keep that backup until satisfied. To inspect an older Helix setup
without replacing the new one, run
`XDG_CONFIG_HOME=/path/to/backup/.config hx --health markdown` using the parent
directory of the backed-up `helix/`. Do not copy back only `config.toml` if you
also want to restore language settings and the custom grammar.

```bash
hx --health markdown
hx --health rpmspec
herdr config check
yazi --debug
pdftoppm -v
```

After changing Herdr's config, run `herdr server reload-config`. When enabling
Kitty graphics for the first time, also detach/reattach and open a **new tab**:
existing pane terminals retain the setting from their creation. Use Ghostty
outside Herdr; PDFs need `pdftoppm` (the `poppler-tools` package). These are
built-in Yazi previewers—no extra plugin or global TERM override is required.

Project files, bibliography exports, Zotero databases, Herdr sessions and all
account credentials must be transferred separately. SilverBullet remains
optional; its [theme recipe](portable/silverbullet/README.md) is retained, but
the bootstrap does not install its server/CLI or create a space. No Herdr
plugins are needed for this workflow.

References: [Helix key map](https://docs.helix-editor.com/keymap.html),
[Helix language configuration](https://docs.helix-editor.com/languages.html),
[Marksman](https://github.com/artempyanykh/marksman),
[Yazi configuration](https://yazi-rs.github.io/docs/configuration/yazi/),
[Herdr configuration](https://herdr.dev/docs/configuration/),
[Pandoc citations](https://pandoc.org/MANUAL.html#citations).
