# Optional SilverBullet theme

Helix/Yazi is the default writing workflow; SilverBullet is not installed by
the bootstrap. If you keep using it, install/connect the `sb` CLI following
[SilverBullet's documentation](https://silverbullet.md/CLI), and create your
own space separately. Neither spaces nor CLI credentials are versioned here.

With the installed **sb 2.10.0** CLI and a space registered as `Dissertation`,
run this once (CLI command names can differ across releases; check `sb --help`):

```bash
sb script --space Dissertation --file ~/.config/hypr/portable/silverbullet/catppuccin-mocha.lua
```

The script creates `Library/Custom/Catppuccin Mocha` inside that space and
refuses to overwrite it if it already exists. Inspect the Lua file first;
this command writes a theme page to the selected space. The desktop's
SilverBullet floating-window rule is also retained.
