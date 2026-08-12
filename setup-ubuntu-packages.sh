#!/usr/bin/env bash
# setup-ubuntu-packages.sh
# The ONLY root step for reproducing conf-hyprland on Ubuntu 26.04.
# Everything else (fonts, hyprshot, rustup, config edits, stow, theme, nvim,
# Claude Code) is user-level and Claude has already done it or will after this.
#
# Run:  sudo bash ~/setup-ubuntu-packages.sh
set -euo pipefail

PKGS=(
  # --- core Hyprland desktop ---
  hyprland hyprpaper hyprlock hypridle hyprpolkitagent
  hyprland-qtutils              # Qt/QML helpers (hyprland-dialog, the config-error
                                # popup, the update screen). A RUNTIME dependency of
                                # hyprland: without it those features silently no-op
                                # and Hyprland nags at every login with an orange
                                # "hyprland-qtutils is not installed" overlay. In
                                # resolute/universe as 0.1.5-1build1 -- note it is
                                # qtutils, not "guiutils", which apt won't find.
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  waybar rofi kitty mako-notifier nautilus
  wl-clipboard cliphist grim slurp jq libnotify-bin stow git btop
  # --- laptop / session extras ---
  pavucontrol blueman network-manager-gnome brightnessctl
  # --- theming ---
  papirus-icon-theme gnome-themes-extra adwaita-icon-theme
  qt6ct qt5ct nwg-look gsettings-desktop-schemas dconf-cli
  fonts-noto-color-emoji seahorse gnome-keyring
  # --- neovim toolchain ---
  neovim ripgrep fd-find fzf luarocks build-essential
  python3 python3-pip python3-venv nodejs npm
  # --- browser (brave repo already configured on this machine) ---
  brave-browser
)

echo "==> apt update"
apt-get update

echo "==> Installing ${#PKGS[@]} packages"
apt-get install -y "${PKGS[@]}"

# Discord: not in apt. Official .deb already downloaded by Claude. It is the
# current updater-bootstrap package (~2 MB) that fetches the client on first run.
DISCORD_DEB="/tmp/claude-1000/-home-baas/a45a90a8-195f-4945-b8f0-093668033248/scratchpad/discord.deb"
if [ -f "$DISCORD_DEB" ]; then
  echo "==> Installing Discord from $DISCORD_DEB"
  apt-get install -y "$DISCORD_DEB"
else
  echo "==> Discord .deb not found at $DISCORD_DEB (skipping); re-download if wanted."
fi

echo
echo "==> Package install done."
echo "    Tell Claude it's finished, or re-run is safe (idempotent)."
