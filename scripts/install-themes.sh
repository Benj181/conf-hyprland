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

# ---------------------------------------------------------------------------
# The schema has to exist before any of this means anything.
#
# set_key below reports "skipped (not writable)" and carries on, which is the
# right response to one unwritable key and the wrong response to the schema not
# being installed at all: every key would skip and the install would finish
# green with no dark mode anywhere. gsettings-desktop-schemas is only
# likely-transitive on Arch, so scripts/packages.sh names it outright and this
# refuses to pretend otherwise.
#
# dconf matters just as much and fails worse: without it gsettings writes to
# the memory backend, every key reports success, and the values evaporate at
# logout. `gsettings writable` returns true either way, so it cannot catch that
# -- naming dconf in packages.sh is the actual fix.
#
# Here-string, not a pipe: `gsettings list-schemas | grep -q` under pipefail
# returns 141 when it matches.
# ---------------------------------------------------------------------------
schemas="$(gsettings list-schemas 2>/dev/null || true)"
if ! grep -Fxq org.gnome.desktop.interface <<<"$schemas"; then
    echo "==> org.gnome.desktop.interface schema is missing." >&2
    echo "    Every key below would silently 'skip' and you would get a green" >&2
    echo "    install with no dark mode. Install gsettings-desktop-schemas." >&2
    exit 1
fi

# These are org.gnome.desktop.interface keys, which GTK apps read via
# xdg-desktop-portal regardless of desktop environment -- unlike
# org.gnome.desktop.wm.preferences, which only Mutter reads and which does
# nothing under Hyprland. The portal is why xdg-desktop-portal-hyprland and
# xdg-desktop-portal-gtk are in packages.sh: on Arch they are optdepends, so
# unnamed they are absent and this mechanism does not exist.
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
