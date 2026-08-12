-- ~/.config/hypr/hyprland.lua
-- Entry point only. Keep this file thin -- everything lives in its own module.
-- hardware.lua holds everything specific to this machine (europa).
--
-- This is the Lua config format Hyprland 0.55+ uses; hyprlang (.conf) is
-- deprecated and will be dropped in a future release. The old .conf files are
-- kept alongside these as a fallback: Hyprland loads hyprland.lua when it
-- exists and ignores hyprland.conf, so deleting hyprland.lua reverts instantly.
--
-- Modules are pulled in with require(), which resolves against the hypr config
-- dir -- so require("general") loads general.lua next to this file.
require("hardware")
require("general")
require("keybinds")
require("windowrules")
require("autostart")

-- There is deliberately no gnome-keyring-daemon autostart here.
--
-- PAM starts the daemon itself (`session optional pam_gnome_keyring.so
-- auto_start`, see scripts/install-keyring.sh) and, unlike an autostart, it
-- starts it with your login password in hand -- which is the only moment the
-- login keyring can be unlocked without prompting. Starting a second one here
-- raced with it: the journal showed "The Secret Service was already
-- initialized" and "discover_other_daemon: 1".
--
-- The line here also asked for `--components=secrets,ssh`. gnome-keyring 50 has
-- no ssh component -- upstream removed the SSH agent, and
-- `gnome-keyring-daemon --help` lists only pkcs11 and secrets. So it never
-- managed an SSH key either. If you want an agent, that is openssh's
-- ssh-agent.service now, not this.
