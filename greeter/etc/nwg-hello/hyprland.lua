-- GENERATED from palettes/mono-warm.env by scripts/theme.sh -- do not edit.
-- Edit templates/greeter-hyprland.lua, re-run the script, then re-run
-- scripts/install-greeter.sh to copy it into /etc.
--
-- /etc/nwg-hello/hyprland.lua: the Hyprland instance greetd runs nwg-hello in
-- (via -c in /etc/greetd/config.toml). It runs as `greeter`, which cannot read
-- /home/baas, so monitor, NVIDIA and keyboard settings are duplicated from
-- ~/.config/hypr. Keep them in sync.

hl.monitor({ output = "DP-3", mode = "2560x1440@180.06", position = "0x0",     scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@180.06", position = "-2560x0", scale = 1 })

-- Without these the greeter can fall back to software rendering or fail.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.config({
    -- Must match general.lua, or the password is typed in the wrong layout and
    -- rejected. `nwg-hello -t` can't catch this (it uses your session's layout);
    -- test with `sudo systemctl start greetd`.
    input = {
        kb_layout = "no",
    },

    cursor = {
        no_hardware_cursors = false,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,

        -- DP-2 has no greeter surface ("monitor_nums": [1]); @bg_alt roughly
        -- matches DP-3's darkened wallpaper.
        background_color = "rgb(191614)",
    },

    animations = {
        enabled = false,
    },
})

-- Exit the compositor when nwg-hello exits, or greetd waits on it forever.
hl.on("hyprland.start", function()
    hl.exec_cmd("nwg-hello; hyprctl dispatch 'hl.dsp.exit()'")
end)
