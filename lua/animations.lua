hl.config({ animations = { enabled = true } })

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.0}, {0.35, 1.0} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, bezier = "easeOutQuint",   style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOutQuint",   style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "easeInOutCubic" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint",   style = "slide" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3, bezier = "easeOutQuint",   style = "fade" })
