#!/usr/bin/env bash
# scripts/install-themes.sh
# Applies the GTK/Qt appearance settings that live outside dotfiles.
# Colours come from the `theme` stow package (gtk.css, qt6ct); this only sets
# the dconf keys GTK reads.

set -euo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
    echo "==> gsettings not available, skipping GTK interface settings"
    exit 0
fi

echo "==> Applying GTK interface settings"

# Without the schema every key below would just "skip". (Without dconf, values
# silently don't persist; packages.sh installs it.)
# Here-string, not a pipe: `... | grep -q` under pipefail returns 141 on a match.
schemas="$(gsettings list-schemas 2>/dev/null || true)"
if ! grep -Fxq org.gnome.desktop.interface <<<"$schemas"; then
    echo "==> org.gnome.desktop.interface schema is missing." >&2
    echo "    Every key below would silently 'skip' and you would get a green" >&2
    echo "    install with no dark mode. Install gsettings-desktop-schemas." >&2
    exit 1
fi

# GTK apps read these via xdg-desktop-portal.
set_key() {
    local key="$1" val="$2"
    if gsettings writable org.gnome.desktop.interface "$key" >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface "$key" "$val"
        echo "    ${key} = ${val}"
    else
        echo "    skipped ${key} (not writable)"
    fi
}

# prefer-dark is what puts libadwaita apps into dark mode.
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
