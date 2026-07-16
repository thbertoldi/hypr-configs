-- Hyprland entry (Lua). Migrated from hyprlang conf.d/ on 2026-07-16.
--
-- Hyprland 0.55 deprecated hyprlang in favour of Lua; window/layer rules that
-- match by class/title can no longer be expressed in plaintext, so the whole
-- compositor config now lives here as Lua. Fragments live in lua/, required in
-- numeric-ish order below (mirrors the old conf.d/ layout).
--
-- The old hyprland.conf + conf.d/ are kept for reference/rollback: this .lua
-- file auto-takes precedence, so to revert just remove/rename it.
--
-- Companion daemons (hypridle.conf, hyprlock.conf) are separate programs and
-- stay in hyprlang syntax.

require("lua/monitors")
require("lua/env")
require("lua/input")
require("lua/general")
require("lua/decoration")
require("lua/animations")
require("lua/rules")
require("lua/autostart")
require("lua/keybinds")
