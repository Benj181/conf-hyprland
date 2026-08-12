-- ~/.config/hypr/windowrules.lua
-- In the Lua format one hl.window_rule can carry several properties at once,
-- so the paired float+size and float+pin rules from the old .conf collapse
-- into a single rule each.

hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
    size  = "800 600",
})

hl.window_rule({
    name  = "float-blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name  = "float-pip",
    match = { class = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
})

-- Nautilus is $filemanager ($mod+E); float its transient dialogs rather than
-- tiling them.
hl.window_rule({
    name  = "float-nautilus-dialogs",
    match = { class = "^(org.gnome.Nautilus)$", title = "^(Preferences|Properties)$" },
    float = true,
})
