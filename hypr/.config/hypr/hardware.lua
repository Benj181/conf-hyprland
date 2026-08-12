-- ~/.config/hypr/hardware.lua
-- Everything specific to this machine (europa) lives here. If a second
-- machine ever shows up, this is the only file that needs to differ.
--
-- europa: RTX 5070 Ti (Blackwell GB203), nvidia-open (open kernel modules),
--         DP-3 Microstep MPG271QX OLED (main, centre) + DP-2 ASUS VG27AQM1A
--         (left). Both 2560x1440, both landscape. DP-3 runs 360Hz, DP-2 240Hz.

-- NVIDIA. Blackwell is open-kernel-module only, so there is no proprietary
-- variant to account for here.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.config({
    cursor = {
        no_hardware_cursors = false,
    },
})

-- Confirmed against `hyprctl monitors` availableModes: DP-3 tops out at 360Hz,
-- DP-2 at 240Hz, both at native 2560x1440. Both landscape. DP-3 is the main
-- panel at the origin; DP-2 sits to its left, so it occupies the full 2560px
-- of width starting at -2560.
hl.monitor({ output = "DP-3", mode = "2560x1440@360", position = "0x0",     scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@240", position = "-2560x0", scale = 1 })

hl.workspace_rule({ workspace = "2", monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })
