-- ~/.config/hypr/general.lua
-- Look, feel and input. Machine-specific bits live in hardware.lua.

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        layout = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding = 10,

        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
            new_optimizations = true,
        },

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 2,
            -- rgba(11111baa) in RRGGBBAA -> 0xAARRGGBB for the Lua color int.
            color        = 0xaa11111b,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    input = {
        kb_layout    = "no",
        follow_mouse = 1,

        -- No mouse acceleration. `flat` is libinput's 1:1 profile -- prefer it
        -- over force_no_accel, which bypasses libinput entirely and is
        -- discouraged upstream. sensitivity 0 is the neutral value, stated
        -- explicitly so it reads as deliberate rather than defaulted.
        accel_profile = "flat",
        sensitivity   = 0,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("snappy",       { type = "bezier", points = { { 0.1, 0.9 }, { 0.1, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "snappy" })

-- QT apps follow qt6ct, which install-themes.sh points at Catppuccin.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
