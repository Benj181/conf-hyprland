-- ~/.config/hypr/hardware.lua
-- Everything specific to this machine (europa).
--
-- europa: RTX 5070 Ti (nvidia-open), DP-3 MSI MPG271QX OLED (main, 360Hz)
--         + DP-2 ASUS VG27AQM1A (left, 240Hz). Both 2560x1440.

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Legacy (non-atomic) KMS: with atomic commits the DP-3 OLED often stays on
-- "no signal" after waking from DPMS (aquamarine #240). Read only at startup.
hl.env("AQ_NO_ATOMIC", "1")

hl.config({
    cursor = {
        no_hardware_cursors = true,   -- required with AQ_NO_ATOMIC
    },
    render = {
        cm_auto_hdr = 0,
    },
})

hl.monitor({ output = "DP-3", mode = "2560x1440@360", position = "0x0",     scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@240", position = "-2560x0", scale = 1 })

hl.workspace_rule({ workspace = "2",  monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "1",  monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-3" })   -- games, see windowrules.lua
