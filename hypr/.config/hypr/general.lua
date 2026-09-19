-- ~/.config/hypr/general.lua
-- Look, feel and input. Machine-specific bits live in hardware.lua.
--
-- Colours come from colors.lua, which scripts/theme.sh generates from
-- palettes/<name>.env. Nothing in this file should contain a hex value.
local C = require("colors")

hl.config({
    general = {
        -- Tight gaps and a 1px border. The old 4/8 + 2px reads as a frame
        -- around each window; at 2/4 + 1px the border is a seam between
        -- windows instead, which is the whole difference between "tiled
        -- windows in boxes" and "one surface divided up".
        gaps_in  = 2,
        gaps_out = 4,
        border_size = 1,
        col = {
            -- Flat, not a gradient. Two-stop gradients are the single most
            -- recognisable "riced" cue, and the focused window is already
            -- unambiguous from a white border against a grey one.
            active_border   = C.rgba(C.accent),
            inactive_border = C.rgba(C.border),
        },
        layout = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        -- 2, not 10 and not 0. Flat 0 looks right in a screenshot and wrong on
        -- a real display: without any radius the corner pixel aliases against
        -- the border and every window gets a visibly ragged corner. 2 is the
        -- smallest value that antialiases cleanly -- the same number the
        -- reference rice uses. Set it to 0 if you want the harder edge.
        rounding = 2,

        blur = {
            enabled = true,
            -- The bar is the only thing being blurred now (see the layerrule
            -- below), so this does not need the passes the old full-strength
            -- setup used. Fewer passes, less GPU time per frame.
            size    = 8,
            passes  = 2,
            new_optimizations = true,
        },

        -- Off. A drop shadow exists to separate a window from what is behind
        -- it; with a visible 1px border and 4px gaps that job is already done,
        -- and the shadow only adds a soft halo that undercuts the flat look.
        shadow = {
            enabled = false,
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

-- waybar's background is alpha(@bg, 0.85); without this the translucency just
-- shows the wallpaper through it and text sitting on a busy area gets hard to
-- read. Blur is what makes a translucent bar legible rather than decorative.
hl.layer_rule({ name = "blur-waybar", match = { namespace = "^waybar$" }, blur = true })

hl.curve("snappy", { type = "bezier", points = { { 0.1, 0.9 }, { 0.1, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "snappy" })

-- QT apps follow qt6ct, which install-themes.sh points at the generated palette.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/screenshots")
