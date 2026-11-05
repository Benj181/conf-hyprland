-- ~/.config/hypr/windowrules.lua

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

-- Float Nautilus' Preferences/Properties dialogs.
hl.window_rule({
    name  = "float-nautilus-dialogs",
    match = { class = "^(org.gnome.Nautilus)$", title = "^(Preferences|Properties)$" },
    float = true,
})

-- Games: steam_app_<appid> (Steam/Proton), gamescope, and native games with
-- their own class (cs2). Fullscreen on workspace 10 on the OLED; `immediate`
-- allows tearing for lower latency (needs general.allow_tearing).
hl.window_rule({
    name       = "games",
    match      = { class = "^(steam_app_.*|gamescope|cs2)$" },
    monitor    = "DP-3",
    workspace  = "10",
    fullscreen = true,
    immediate  = true,
})

-- Stop a new tiled window from taking over a workspace's maximized state and
-- covering the other windows; it tiles normally instead. Hyprland 0.57 ignores
-- misc.on_focus_under_fullscreen and applies the maximize just after
-- window.open, so it is undone on the window's first fullscreen event.
local just_opened = {}
hl.on("window.open", function(w)
    if w and not w.floating then just_opened[w.address] = true end
end)
hl.on("window.fullscreen", function(w)
    if not w or not just_opened[w.address] then return end
    just_opened[w.address] = nil
    if w.fullscreen == 1 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = w }))
    end
end)
hl.on("window.close", function(w) if w then just_opened[w.address] = nil end end)
