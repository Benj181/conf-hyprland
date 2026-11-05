-- ~/.config/hypr/hyprland.lua
-- Entry point. Machine-specific settings live in hardware.lua.
-- gnome-keyring is started by PAM (scripts/install-keyring.sh), not here.
require("hardware")
require("general")
require("keybinds")
require("windowrules")
require("autostart")
