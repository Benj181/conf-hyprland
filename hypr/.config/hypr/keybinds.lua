-- ~/.config/hypr/keybinds.lua

local mod         = "SUPER"
local terminal    = "kitty"
local launcher    = "rofi -show drun"
-- `brave`, not `brave-browser`: the AUR's brave-bin installs /usr/bin/brave, and
-- a mismatch here is a keybind that silently does nothing.
local browser     = "brave"
local filemanager = "nautilus"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + M",      hl.dsp.exit())
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(filemanager))
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + R",      hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser))

-- power menu (rofi, see ~/.config/rofi/powermenu.sh -- replaced wlogout)
hl.bind(mod .. " + SHIFT + X", hl.dsp.exec_cmd("~/.config/rofi/powermenu.sh"))

-- clipboard history (cliphist is populated by autostart.lua)
hl.bind(mod .. " + C", hl.dsp.exec_cmd([[cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy]]))

-- focus movement
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + j", hl.dsp.focus({ direction = "down" }))

-- window movement
hl.bind(mod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))

-- workspaces 1-10 (key 0 maps to workspace 10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- media / volume (locked = works on lock screen, repeating = key-repeat held)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })

-- No XF86MonBrightness binds: /sys/class/backlight is empty on this desktop, so
-- brightnessctl has nothing to act on. External monitors need DDC/CI instead --
-- add ddcutil and bind `ddcutil setvcp 10 + 5` if you want it.

-- notifications (mako)
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("makoctl restore"))

-- Screenshots (Hyprshot)
hl.bind("Print",           hl.dsp.exec_cmd("hyprshot -m output")) -- full screen
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m region")) -- click-drag region
