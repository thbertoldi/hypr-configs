hl.config({
    input = {
        kb_layout  = "us,br",
        kb_variant = ",abnt2",
        -- Super+Space cycles layouts (see keybinds.lua).
        numlock_by_default = true,

        repeat_delay = 250,
        repeat_rate  = 35,

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            scroll_factor        = 0.4,
        },
    },
})

-- 3-finger horizontal swipe to change workspace.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
