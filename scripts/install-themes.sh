#!/usr/bin/env bash
# scripts/install-themes.sh
# Applies the GTK/Qt appearance settings that live outside dotfiles.
#
# This deliberately downloads nothing. catppuccin/gtk was archived in June
# 2024, so pinning a release of it would build on an unmaintained dependency --
# and it would not help with the app that matters most here anyway: Nautilus
# links libadwaita, which ignores gtk-theme-name outright. The colours are
# applied by the `theme` stow package (gtk-3.0/gtk.css, gtk-4.0/gtk.css,
# qt6ct), so all that is left is the settings GTK reads from dconf.

set -euo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
    echo "==> gsettings not available, skipping GTK interface settings"
    exit 0
fi

echo "==> Applying GTK interface settings"

# These are org.gnome.desktop.interface keys, which GTK apps read via
# xdg-desktop-portal regardless of desktop environment -- unlike
# org.gnome.desktop.wm.preferences, which only Mutter reads and which does
# nothing under Hyprland.
set_key() {
    local key="$1" val="$2"
    if gsettings writable org.gnome.desktop.interface "$key" >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface "$key" "$val"
        echo "    ${key} = ${val}"
    else
        echo "    skipped ${key} (not writable)"
    fi
}

# prefer-dark is what actually puts libadwaita apps into dark mode.
set_key color-scheme "prefer-dark"
set_key gtk-theme "Adwaita-dark"
set_key icon-theme "Papirus-Dark"
set_key cursor-theme "Adwaita"
set_key font-name "FiraCode Nerd Font 11"
set_key monospace-font-name "FiraCode Nerd Font Mono 11"

# Hyprland tracks its own cursor, separate from GTK's.
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl setcursor Adwaita 24 >/dev/null 2>&1 && echo "    hyprland cursor = Adwaita 24" || true
fi

echo "==> Theme settings done"
