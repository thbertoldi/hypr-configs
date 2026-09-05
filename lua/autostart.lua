-- systemd supervises the graphical session. Finalize the compositor environment
-- in UWSM sessions; keep the minimal target as a fallback in classic sessions.
-- Daemon units live in ~/.config/systemd/user/.
hl.on("hyprland.start", function()
    hl.exec_cmd([[
        sh -c '
            if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
                exec uwsm finalize
            fi
            systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
            dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
            systemctl --user start hyprland-session.target
        '
    ]])
end)

hl.on("hyprland.shutdown", function()
    os.execute([[
        if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
            exit 0
        fi
        systemctl --user stop hyprland-session.target
        sleep 0.1
    ]])
end)
