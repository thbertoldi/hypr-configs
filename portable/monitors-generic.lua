-- Safe first-boot profile for a different computer.
-- Hyprland picks each output's preferred mode and places outputs automatically.
-- After the first login, use `hyprctl monitors` and replace this with a tuned
-- machine-specific profile if desired.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
