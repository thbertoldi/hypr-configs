-- Create the theme page in a SilverBullet space using its supported API.
-- Run: sb script --space Writing --file ~/.config/hypr/portable/silverbullet/catppuccin-mocha.lua
-- CSS variables checked against the installed SilverBullet 2.10.0 bundle.

local page = "Library/Custom/Catppuccin Mocha"
if space.pageExists(page) then
  error("Theme page already exists: " .. page .. ". Open it to edit the theme.")
end

local content = [==[
# Catppuccin Mocha

Colors from the Hyprland desktop, with Peach accents.
Enable dark mode, then run `System: Reload` (Ctrl+Alt+R) to apply this theme.
To disable it, change the opening code fence from `space-style` to `css`
and run `System: Reload` again.

```space-style
html[data-theme="dark"] {
  color-scheme: dark;
  --ctp-crust: #11111b;
  --ctp-mantle: #181825;
  --ctp-base: #1e1e2e;
  --ctp-surface0: #313244;
  --ctp-surface1: #45475a;
  --ctp-overlay0: #6c7086;
  --ctp-subtext0: #a6adc8;
  --ctp-subtext1: #bac2de;
  --ctp-text: #cdd6f4;
  --ctp-rosewater: #f5e0dc;
  --ctp-peach: #fab387;
  --ctp-maroon: #eba0ac;
  --ctp-red: #f38ba8;
  --ctp-yellow: #f9e2af;
  --ctp-green: #a6e3a1;
  --ctp-teal: #94e2d5;
  --ctp-sky: #89dceb;
  --ctp-blue: #89b4fa;
  --ctp-mauve: #cba6f7;
  --ctp-lavender: #b4befe;

  /* Main surfaces and interface accents. */
  --root-background-color: var(--ctp-base);
  --root-color: var(--ctp-text);
  --ui-accent-color: var(--ctp-peach);
  --ui-accent-text-color: var(--ctp-peach);
  --ui-accent-contrast-color: var(--ctp-crust);
  --ui-surface-background-color: var(--ctp-base);
  --ui-surface-color: var(--ctp-text);
  --ui-surface-subtle-color: var(--ctp-subtext0);
  --ui-surface-border-color: var(--ctp-surface1);
  --ui-surface-section-background-color: var(--ctp-mantle);
  --ui-surface-hover-background-color: var(--ctp-surface0);
  --subtle-color: var(--ctp-subtext0);
  --subtle-background-color: var(--ctp-surface0);
  --meta-color: var(--ctp-mauve);
  --meta-subtle-color: var(--ctp-subtext0);
  --highlight-color: #f9e2af33;
  --link-color: var(--ctp-blue);
  --link-missing-color: var(--ctp-yellow);
  --link-invalid-color: var(--ctp-red);

  /* Top bar and side panels. */
  --top-background-color: var(--ctp-mantle);
  --top-color: var(--ctp-text);
  --top-border-color: var(--ctp-surface0);
  --top-saved-color: var(--ctp-green);
  --top-unsaved-color: var(--ctp-yellow);
  --top-loading-color: var(--ctp-peach);
  --top-sync-error-color: var(--ctp-red);
  --top-sync-error-background-color: var(--ctp-mantle);
  --panel-background-color: var(--ctp-base);
  --panel-border-color: var(--ctp-surface0);
  --bhs-background-color: var(--ctp-mantle);
  --bhs-border-color: var(--ctp-surface0);
  --action-button-color: var(--ctp-subtext0);
  --action-button-hover-color: var(--ctp-peach);
  --action-button-active-color: var(--ctp-peach);
  --progress-background-color: var(--ctp-surface0);
  --progress-sync-color: var(--ctp-green);
  --progress-index-color: var(--ctp-blue);

  /* Pickers, dialogs, buttons and text inputs. */
  --modal-color: var(--ctp-text);
  --modal-background-color: var(--ctp-mantle);
  --modal-border-color: var(--ctp-surface1);
  --modal-backdrop-color: #11111b99;
  --modal-header-label-color: var(--ctp-peach);
  --modal-help-background-color: var(--ctp-surface0);
  --modal-help-color: var(--ctp-subtext1);
  --modal-selected-option-background-color: var(--ctp-peach);
  --modal-selected-option-color: var(--ctp-crust);
  --modal-selected-option-description-color: var(--ctp-crust);
  --modal-description-color: var(--ctp-subtext0);
  --modal-hint-background-color: var(--ctp-surface0);
  --modal-hint-color: var(--ctp-text);
  --modal-hint-inactive-background-color: var(--ctp-surface0);
  --modal-hint-inactive-color: var(--ctp-subtext0);
  --button-background-color: var(--ctp-surface0);
  --button-hover-background-color: var(--ctp-surface1);
  --button-color: var(--ctp-text);
  --button-border-color: var(--ctp-surface1);
  --primary-button-background-color: var(--ctp-peach);
  --primary-button-hover-background-color: var(--ctp-rosewater);
  --primary-button-color: var(--ctp-crust);
  --text-field-background-color: var(--ctp-surface0);

  /* Markdown and syntax highlighting. */
  --editor-caret-color: var(--ctp-peach);
  --editor-selection-background-color: #fab38747;
  --editor-heading-color: var(--ctp-rosewater);
  --editor-heading-meta-color: var(--ctp-subtext0);
  --editor-list-bullet-color: var(--ctp-peach);
  --editor-ruler-color: var(--ctp-surface1);
  --editor-code-background-color: var(--ctp-mantle);
  --editor-code-color: var(--ctp-text);
  --editor-code-comment-color: var(--ctp-subtext0);
  --editor-code-variable-color: var(--ctp-blue);
  --editor-code-typename-color: var(--ctp-yellow);
  --editor-code-string-color: var(--ctp-green);
  --editor-code-number-color: var(--ctp-peach);
  --editor-code-operator-color: var(--ctp-sky);
  --editor-code-atom-color: var(--ctp-mauve);
  --editor-code-info-color: var(--ctp-subtext0);
  --editor-code-deleted-color: var(--ctp-red);
  --editor-code-deleted-bg: #f38ba819;
  --editor-code-inserted-color: var(--ctp-green);
  --editor-code-inserted-bg: #a6e3a119;
  --editor-error-color: var(--ctp-red);
  --editor-struct-color: var(--ctp-mauve);
  --editor-wiki-link-color: var(--ctp-lavender);
  --editor-wiki-link-page-background-color: #89b4fa12;
  --editor-hashtag-background-color: #cba6f726;
  --editor-hashtag-color: var(--ctp-mauve);
  --editor-hashtag-border-color: var(--ctp-mauve);
  --editor-table-head-background-color: var(--ctp-surface0);
  --editor-table-head-color: var(--ctp-text);
  --editor-table-even-background-color: var(--ctp-mantle);
  --editor-blockquote-background-color: var(--ctp-mantle);
  --editor-blockquote-color: var(--ctp-subtext1);
  --editor-blockquote-border-color: var(--ctp-blue);
  --editor-widget-background-color: var(--ctp-surface0);
  --editor-frontmatter-background-color: var(--ctp-mantle);
  --editor-frontmatter-color: var(--ctp-subtext1);
  --editor-frontmatter-marker-color: var(--ctp-mauve);
  --editor-task-marker-color: var(--ctp-peach);
  --editor-task-state-color: var(--ctp-green);
  --editor-directive-mark-color: var(--ctp-mauve);
  --editor-directive-color: var(--ctp-subtext1);
  --editor-directive-background-color: var(--ctp-mantle);
  --editor-command-button-color: var(--ctp-text);
  --editor-command-button-background-color: var(--ctp-surface0);
  --editor-command-button-hover-background-color: var(--ctp-surface1);
  --editor-command-button-border-color: var(--ctp-surface1);
  --editor-completion-detail-color: var(--ctp-subtext0);
  --editor-completion-detail-selected-color: var(--ctp-crust);

  /* Editor search bar. */
  --editor-panels-bottom-color: var(--ctp-text);
  --editor-panels-bottom-background-color: var(--ctp-mantle);
  --editor-panels-bottom-border-color: var(--ctp-surface0);
  --editor-panels-bottom-input-background-color: var(--ctp-surface0);
  --editor-panels-bottom-button-background-image: none;
  --editor-panels-bottom-button-active-background-image: none;

  /* Notifications and shared panel components. */
  --notifications-background-color: var(--ctp-surface0);
  --notifications-border-color: var(--ctp-surface1);
  --notification-info-background-color: var(--ctp-surface0);
  --notification-error-background-color: #402d3e;
  --notification-warning-background-color: #3f3b38;
  --danger-color: var(--ctp-red);
  --danger-contrast-color: var(--ctp-crust);
  --success-color: var(--ctp-green);
  --alert-error-color: var(--ctp-red);
  --alert-error-background-color: #f38ba819;
  --alert-error-border-color: #f38ba84d;
  --alert-warning-color: var(--ctp-yellow);
  --alert-warning-background-color: #f9e2af19;
  --alert-warning-border-color: #f9e2af4d;
  --alert-info-color: var(--ctp-blue);
  --alert-info-background-color: #89b4fa19;
  --alert-info-border-color: #89b4fa4d;
  --badge-background-color: #cba6f726;
  --badge-color: var(--ctp-mauve);
}

/* These colors are hardcoded in the default stylesheet. */
html[data-theme="dark"] #sb-editor .cm-editor .cm-tooltip-autocomplete ul li:hover,
html[data-theme="dark"] #sb-editor .cm-editor .cm-tooltip-autocomplete ul li[aria-selected="true"] {
  background-color: var(--ctp-peach);
  color: var(--ctp-crust);
}

html[data-theme="dark"] .sb-footnote-ref {
  background-color: var(--ctp-mantle);
}

html[data-theme="dark"] .sb-admonition[admonition="note" i] {
  --admonition-color: var(--ctp-blue);
}
html[data-theme="dark"] .sb-admonition[admonition="warning" i] {
  --admonition-color: var(--ctp-yellow);
}
html[data-theme="dark"] .sb-admonition[admonition="danger" i] {
  --admonition-color: var(--ctp-red);
}
html[data-theme="dark"] .sb-admonition[admonition="success" i] {
  --admonition-color: var(--ctp-green);
}
```
]==]

space.writePage(page, content)
assert(space.readPage(page) == content, "Theme page verification failed: " .. page)
return "Created " .. page .. ". Enable dark mode and run System: Reload (Ctrl+Alt+R) in the selected space."
