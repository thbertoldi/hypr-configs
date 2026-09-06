-- Window & layer rules. These MUST be Lua in 0.55 — the hyprlang plaintext
-- rule parser can't express class/title matchers anymore.

-- Float utility / dialog windows
hl.window_rule({ match = { class = "^(pavucontrol)$" },              float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" },     float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" },          float = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(qt6ct|qt5ct|kvantummanager)$" }, float = true })
hl.window_rule({ match = { class = "^(file_progress)$" },            float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" },   float = true })

-- Xwayland Video Bridge exposes its capture surface as an X11 window. KWin
-- hides it natively; Hyprland needs an explicit rule to keep it out of view.
hl.window_rule({
    name = "xwayland-video-bridge-fixes",
    match = { class = "^xwaylandvideobridge$" },
    no_initial_focus = true,
    no_focus = true,
    no_anim = true,
    no_blur = true,
    max_size = { 1, 1 },
    opacity = "0.0",
})

-- Keep the calendar spacious on both the ultrawide and a smaller laptop.
hl.window_rule({
    match = { class = "^com\\.danklinux\\.dankcalendar$" },
    float = true,
    center = true,
    size = { "monitor_w*0.76", "monitor_h*0.82" },
    persistent_size = true,
})

-- Keep Spotify spacious without taking over the whole ultrawide. The official
-- client has a clean borderless Wayland surface; Spicetify styles its content.
hl.window_rule({
    match = { class = "^spotify$" },
    float = true,
    center = true,
    size = { "monitor_w*0.80", "monitor_h*0.84" },
})

-- A focused study surface that still leaves the workspace visible.
hl.window_rule({
    match = { class = "^net\\.ankiweb\\.Anki$" },
    float = true,
    center = true,
    size = { "monitor_w*0.76", "monitor_h*0.84" },
    persistent_size = true,
})

-- Read notes without rearranging the tiled workspace.
hl.window_rule({
    match = { class = "^silverbullet-app\\.bin$" },
    float = true,
    center = true,
    size = { "monitor_w*0.76", "monitor_h*0.84" },
    persistent_size = true,
})

-- Dedicated terminal and notes scratchpads
hl.window_rule({
    match = { class = "^com\\.thbertoldi\\.(QuickTerminal|QuickNotes)$" },
    float = true,
    center = true,
    size = { "monitor_w*0.66", "monitor_h*0.70" },
    persistent_size = true,
})

-- Picture-in-Picture (float, pinned, fixed size, bottom-right corner)
hl.window_rule({
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    size  = { 480, 270 },
    move  = "100%-490 100%-280",
})

-- Inhibit idle while watching video / fullscreen
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { class = "^(mpv|com\\.github\\.rafostar\\.Clapper)$" }, idle_inhibit = "focus" })

-- Full opacity for fullscreen windows
hl.window_rule({ match = { fullscreen = true }, opacity = "1.0 1.0" })

-- Layer rules (ignorezero -> ignore_alpha in the Lua API)
hl.layer_rule({ match = { namespace = "^waybar$" },        ignore_alpha = true })
hl.layer_rule({ match = { namespace = "^notifications$" }, blur = true })
