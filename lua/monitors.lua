-- 34" 2K ultrawide as primary, internal panel disabled.
-- If your monitor names differ, change DP-1 / eDP-1 to match `hyprctl monitors`.
-- The laptop panel is auto-enabled when undocked by scripts/monitor-listener.sh
-- (via `hyprctl keyword monitor` at runtime).
hl.monitor({ output = "DP-1", mode = "3440x1440@100", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", disabled = true })

-- Workspaces 1-10 bound to the ultrawide.
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
for i = 2, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" })
end
