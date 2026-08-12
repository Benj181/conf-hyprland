-- ~/.config/hypr/autostart.lua

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")

    -- Polkit authentication agent. Started through its systemd user unit rather
    -- than an absolute path: the previous hardcoded
    -- /usr/lib/polkit-kde-authentication-agent-1 did not exist on this system
    -- and failed silently, so auth prompts never appeared. (The real binary
    -- ships at /usr/libexec/hyprpolkitagent, but let systemd resolve that.)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    hl.exec_cmd("wl-paste --watch cliphist store")
end)
