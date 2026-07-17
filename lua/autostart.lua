-- exec-once equivalents: run once when the compositor starts.
hl.on("hyprland.start", function()
    -- Polkit agent (keeping mate variant from prior config; polkit-kde would also work)
    hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")

    -- Clipboard history daemon
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Wallpaper daemon (awww — Codeberg fork-rename of swww, CLI-compatible)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 0.3 && awww img ~/Pictures/wallpapers/whales-clouds.jpg --transition-type none")

    -- Auto-enable the laptop panel (eDP-1) whenever no external monitor is present.
    -- Reconciles at startup, then live-switches on dock/undock (see scripts/).
    hl.exec_cmd("~/.config/hypr/scripts/monitor-listener.sh")

    -- Bar, notifications, idle daemon
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")

    -- Dashboard widget daemon (eww — toggle with Super+W)
    hl.exec_cmd("eww daemon")

    -- smarty-pants daemon (local AI rewrite — keeps Qwen 2.5 7B resident in VRAM,
    -- registers Super+R/A/I via xdg-desktop-portal-hyprland GlobalShortcuts;
    -- see keybinds.lua for the binds)
    hl.exec_cmd("/home/thbertoldi/.cargo/bin/smarty-pants-daemon")

    -- NetworkManager tray applet (daemon itself runs via systemd)
    hl.exec_cmd("nm-applet --indicator")

    -- KWallet daemon — kicked off early so pam_kwallet5 (set up in common-auth-pc)
    -- can hand it the login token and auto-unlock. The companion ksecretd (also
    -- shipped in kwalletd6) is D-Bus activated on demand and serves
    -- org.freedesktop.secrets, so any libsecret app ends up talking to this KWallet.
    hl.exec_cmd("/usr/bin/kwalletd6")

    -- Make systemd/dbus aware of the Wayland session for portals
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Bring up the systemd graphical session so xdg-desktop-portal can start.
    -- Without this, graphical-session.target stays inactive (nothing else
    -- activates it on bare Hyprland), the portal's Requisite= fails, and apps
    -- never receive the color-scheme=prefer-dark signal -> everything looks light.
    -- Unit: ~/.config/systemd/user/hyprland-session.target
    hl.exec_cmd("systemctl --user start hyprland-session.target")
end)
