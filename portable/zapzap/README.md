# ZapZap

`catppuccin-mocha-peach.css` customizes WhatsApp Web through ZapZap's native
global CSS support. It uses the same Catppuccin Mocha base and Peach accent as
the rest of the desktop, without JavaScript or changes to account data.

The theme is a static adaptation of
[Catppuccin Userstyles for WhatsApp Web](https://github.com/catppuccin/userstyles/tree/main/styles/whatsapp-web),
version `2026.07.03`, reviewed at commit
`5ef4cc64231826f46d12a2721fa72571f5aa8a27`. The original uses LESS; this version
expands only the variables and rules needed for direct injection into ZapZap.

The bootstrap copies the CSS to:

```text
~/.var/app/com.rtosta.zapzap/data/ZapZap/customizations/global/css/
```

It also enables global CSS, selects dark mode and uses a light symbolic tray
icon. Login, cookies, messages and received files stay exclusively in the
Flatpak profile and are not versioned.
