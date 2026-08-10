-- External 34" ultrawide (LG). Matched by DESCRIPTION, not connector name:
-- it used to be hardcoded "DP-1" but now enumerates as "HDMI-A-1", which left
-- the whole monitor line (and the workspace bindings below) pointing at a
-- monitor that doesn't exist. desc: survives DP<->HDMI / connector renames.
-- Max refresh over the current link is ~85Hz (the old @100 was unreachable).
hl.monitor({
    output   = "desc:LG Electronics LG ULTRAWIDE 508AZBZFN861",
    mode     = "3440x1440@85",
    position = "0x0",
    scale    = 1,
})

-- Laptop panel disabled while docked; scripts/monitor-listener.sh re-enables it
-- when undocked (via `hyprctl keyword monitor` at runtime).
hl.monitor({ output = "eDP-1", disabled = true })

-- NO per-workspace monitor bindings. This is a single-active-monitor setup
-- (external when docked, laptop when undocked — never both), so pinning
-- workspaces to a named monitor only made them unreachable the moment that
-- name changed. Without bindings, workspaces follow whatever monitor is live,
-- and clicking / Super+N always switches.
