local m = "SUPER"

-- === Apps ===
hl.bind(m .. " + Return",    hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh ghostty"))
hl.bind(m .. " + D",         hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh fuzzel"))
hl.bind(m .. " + SHIFT + D", hl.dsp.exec_cmd("fuzzel --dmenu"))
hl.bind(m .. " + B",         hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh firefox"))
hl.bind(m .. " + E",         hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh ghostty -e yazi"))
hl.bind(m .. " + V",         hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/clipboard_picker.py"))
hl.bind(m .. " + W",         hl.dsp.exec_cmd("sh -c 'eww open --toggle dashboard'"))
hl.bind(m .. " + T",         hl.dsp.exec_cmd("~/.config/hypr/scripts/vpn-toggle.sh"))
hl.bind(m .. " + G",         hl.dsp.exec_cmd("~/.config/hypr/scripts/agent-menu.sh"))
hl.bind(m .. " + O",         hl.dsp.exec_cmd("~/.config/hypr/scripts/calendar-open.sh agenda"))
hl.bind(m .. " + M",         hl.dsp.exec_cmd("~/.config/hypr/scripts/music-open.sh"))
hl.bind(m .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/study-open.sh all"))
hl.bind(m .. " + CTRL + M",  hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh nwg-displays"))
hl.bind(m .. " + CTRL + B",  hl.dsp.exec_cmd("~/.config/hypr/scripts/app-launch.sh ghostty -e btop"))

-- === Window ===
-- Keep Spotify playing on its own hidden workspace. The tray's Quit action
-- still exits the client, and Super+M brings the window back.
-- Lua uses follow=false; a silent=true field is ignored by the dispatcher.
hl.bind(m .. " + Q", function()
    local window = hl.get_active_window()
    if window and window.class:lower() == "spotify" then
        hl.dispatch(hl.dsp.window.move({ window = window, workspace = "special:spotify", follow = false }))
    else
        hl.dispatch(hl.dsp.window.close())
    end
end)
hl.bind(m .. " + F",             hl.dsp.window.fullscreen({ mode = "maximized" }))  -- was fullscreen,1
hl.bind(m .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- was fullscreen,0
hl.bind(m .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(m .. " + P",             hl.dsp.window.pseudo())
hl.bind(m .. " + SHIFT + R",     hl.dsp.layout("togglesplit"))

-- === Focus (vim hjkl) ===
hl.bind(m .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(m .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(m .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(m .. " + L", hl.dsp.focus({ direction = "right" }))

-- === Move window ===
hl.bind(m .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(m .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(m .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(m .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- === Focus monitor ===
hl.bind(m .. " + CTRL + H", hl.dsp.focus({ monitor = "left" }))
hl.bind(m .. " + CTRL + J", hl.dsp.focus({ monitor = "down" }))
hl.bind(m .. " + CTRL + K", hl.dsp.focus({ monitor = "up" }))
hl.bind(m .. " + CTRL + L", hl.dsp.focus({ monitor = "right" }))

-- === Resize active ===
hl.bind(m .. " + ALT + H", hl.dsp.window.resize({ x = -60, y = 0,   relative = true }), { repeating = true })
hl.bind(m .. " + ALT + L", hl.dsp.window.resize({ x = 60,  y = 0,   relative = true }), { repeating = true })
hl.bind(m .. " + ALT + K", hl.dsp.window.resize({ x = 0,   y = -60, relative = true }), { repeating = true })
hl.bind(m .. " + ALT + J", hl.dsp.window.resize({ x = 0,   y = 60,  relative = true }), { repeating = true })

-- === Workspaces (1-10; key 0 -> workspace 10) ===
for i = 1, 10 do
    local key = i % 10
    hl.bind(m .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(m .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

hl.bind(m .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(m .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))

-- === Special / scratchpad ===
hl.bind(m .. " + S",         hl.dsp.workspace.toggle_special())
hl.bind(m .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(m .. " + ALT + Return", hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/scratchpad.py terminal"))
hl.bind(m .. " + ALT + N",      hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/scratchpad.py notes"))
hl.bind(m .. " + ALT + F",      hl.dsp.exec_cmd("~/.config/hypr/scripts/desktop-control.sh focus"))

-- === Mouse wheel switches workspace ===
hl.bind(m .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(m .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- === Drag move/resize with mouse ===
hl.bind(m .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(m .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- === System ===
hl.bind(m .. " + Escape",         hl.dsp.exec_cmd("wlogout --protocol layer-shell"))
hl.bind(m .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock"))
hl.bind(m .. " + SHIFT + E",      hl.dsp.exec_cmd("~/.config/hypr/scripts/session-exit.sh"))
hl.bind(m .. " + CTRL + R",       hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(m .. " + N",              hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/notification_control.py dismiss"))
hl.bind(m .. " + SHIFT + N",      hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/notification_control.py clear"))
hl.bind(m .. " + CTRL + N",       hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/notification_control.py toggle"))
hl.bind(m .. " + CTRL + space",   hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/notification_control.py history"))
hl.bind(m .. " + space",          hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- === Voice (Handy) ===
-- Wayland blocks apps from grabbing global hotkeys; the compositor owns the
-- bind and pokes the running Handy instance via its CLI (D-Bus single-instance).
hl.bind("CTRL + space",  hl.dsp.exec_cmd([[sh -c 'test -x "$HOME/Applications/Handy.AppImage" && "$HOME/Applications/Handy.AppImage" --toggle-transcription']]))
hl.bind("CTRL + Escape", hl.dsp.exec_cmd([[sh -c 'test -x "$HOME/Applications/Handy.AppImage" && "$HOME/Applications/Handy.AppImage" --cancel']]))

-- === smarty-pants AI rewrite (xdg-desktop-portal-hyprland GlobalShortcuts) ===
hl.bind(m .. " + R", hl.dsp.global("surface-transient:rewrite"))
hl.bind(m .. " + A", hl.dsp.global("surface-transient:academic"))
hl.bind(m .. " + I", hl.dsp.global("surface-transient:linkedin"))
hl.bind(m .. " + C", hl.dsp.global("surface-transient:condense"))

-- === Screenshots (grimblast -> clipboard + file) ===
hl.bind("Print",         hl.dsp.exec_cmd("grimblast --notify copysave area   ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast --notify copysave screen ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"))
hl.bind("CTRL + Print",  hl.dsp.exec_cmd("grimblast --notify copysave active ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"))
hl.bind(m .. " + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-edit.sh"))

-- === Recording and color picker ===
hl.bind(m .. " + ALT + R",   hl.dsp.exec_cmd("~/.config/hypr/scripts/screen-record-toggle.sh"))
hl.bind(m .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker --autocopy --format=hex --notify"))

-- === Audio (PipeWire via wpctl) ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-control.sh up"),         { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-control.sh down"),       { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-control.sh toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-control.sh mic-toggle"), { locked = true })

-- === Brightness ===
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness-control.sh up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness-control.sh down"), { locked = true, repeating = true })

-- === Media keys ===
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --player=playerctld play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl --player=playerctld next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl --player=playerctld previous"),   { locked = true })

-- === Lid switch (disable the internal panel whether the lid opens or closes;
-- the undock listener re-enables it when no external monitor is present) ===
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
