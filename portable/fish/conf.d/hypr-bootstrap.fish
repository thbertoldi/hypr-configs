# Managed by the Hyprland bootstrap; keep personal settings in config.fish.
# Herdr and Marksman are installed here, including on a fresh Fish login.
fish_add_path --global --path "$HOME/.local/bin"

if status is-interactive
    if command -sq zoxide
        zoxide init fish | source
    end

    if command -sq starship
        # Starship otherwise looks in ~/.config even with a custom XDG path.
        if not set -q STARSHIP_CONFIG; and test -n "$XDG_CONFIG_HOME"
            set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship.toml"
        end
        starship init fish | source
    end
end
