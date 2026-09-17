-- GENERATED from palettes/{{palette}}.env by scripts/theme.sh -- do not edit.
-- Edit templates/greeter-hyprland.lua and re-run the script, then re-run
-- scripts/install-greeter.sh to copy it into /etc.
--
-- Generated for one line: misc.background_color. It cannot require() the
-- palette the way general.lua does -- this runs as `greeter`, which cannot
-- read /home/baas -- and it is the second monitor's entire appearance at the
-- login screen, so leaving it hardcoded means a palette switch produces a
-- login screen with one panel in the new scheme and one in the old.
--
-- /etc/nwg-hello/hyprland.lua
-- The compositor greetd runs the greeter inside. nwg-hello is a GTK3 app and
-- needs a wlroots-style compositor for gtk-layer-shell, so Hyprland hosts it.
--
-- Lua, not hyprlang: Hyprland 0.55 deprecated the .conf format and 0.57 removes
-- it. The greeter is a Hyprland instance too, so its config had to move as well
-- or the login screen would stop loading on the 0.57 upgrade. greetd points at
-- this file via `-c /etc/nwg-hello/hyprland.lua` in /etc/greetd/config.toml.
--
-- Installed by scripts/install-greeter.sh. This is NOT the user session config
-- -- it runs as `greeter`, which cannot read /home/baas (mode 750), so it
-- cannot require() anything from ~/.config/hypr/. Monitor and NVIDIA settings
-- are therefore duplicated from hypr/.config/hypr/hardware.lua rather than
-- shared. If you re-arrange monitors there, change them here too.

-- Must match hardware.lua. If the greeter's idea of the layout disagrees with
-- the session's, the login form lands on the wrong panel or off-screen. DP-2 is
-- landscape (no transform), 2560 wide, so it sits at -2560x0 left of DP-3.
hl.monitor({ output = "DP-3", mode = "2560x1440@180.06", position = "0x0",     scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@180.06", position = "-2560x0", scale = 1 })

-- NVIDIA. Blackwell is open-kernel-module only. Without these the greeter can
-- come up on llvmpipe (software rendering) or not at all.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.config({
    -- Must match general.lua's input block. Hyprland defaults to kb_layout us,
    -- and this file cannot read ~/.config/hypr -- so leaving it out does not
    -- inherit the session's layout, it silently picks a different one.
    --
    -- This is the password field. On a `no` layout typed as `us`, -/+ swap, / and
    -- \ move, ' ; : _ @ $ " all move, and aeoua vanish -- so a correct password
    -- is rejected at the one screen you cannot get past. The failure reads as a
    -- wrong password, not as a wrong layout, which is what makes it expensive.
    --
    -- `nwg-hello -t` does NOT catch this: it runs inside your session, which
    -- already has kb_layout no, so it passes while the real greeter fails. Only
    -- `sudo systemctl start greetd` exercises this file -- type your password
    -- into it, do not just look at it.
    input = {
        kb_layout = "no",
    },

    cursor = {
        no_hardware_cursors = false,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,

        -- nwg-hello.json sets "monitor_nums": [1], so the greeter only puts a
        -- surface on DP-3 and DP-2 shows the bare compositor background. This
        -- approximates what DP-3 actually renders -- the wallpaper composited
        -- under the CSS overlay -- so the second panel reads as part of the
        -- same screen rather than as a dead output.
        --
        -- @bg_alt rather than @bg: the wallpaper is a falloff from @bg out to
        -- @surface_hi, so its mean sits just above the base, and the overlay
        -- darkens it back down by roughly that much.
        background_color = "rgb({{bg_alt_raw}})",
    },

    -- The greeter is on screen for a few seconds and is not a place to be cute.
    animations = {
        enabled = false,
    },
})

-- Start the greeter, and tear the whole compositor down the moment it exits so
-- greetd can hand the VT to the real session. The `; hyprctl dispatch ...` runs
-- only after nwg-hello returns (shell sequencing); without it Hyprland lingers
-- after login and greetd waits forever on a compositor with nothing in it.
hl.on("hyprland.start", function()
    hl.exec_cmd("nwg-hello; hyprctl dispatch 'hl.dsp.exit()'")
end)
