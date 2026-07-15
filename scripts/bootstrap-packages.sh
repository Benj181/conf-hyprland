#!/usr/bin/env bash
# scripts/bootstrap-packages.sh
# Installs packages needed for the Hyprland setup. Run once per fresh machine.
# Usage: ./scripts/bootstrap-packages.sh [nvidia-desktop|laptop-igpu]

set -euo pipefail

PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 [nvidia-desktop|laptop-igpu]"
    exit 1
fi

echo "==> Updating package lists"
sudo apt update

echo "==> Installing core Hyprland stack"
sudo apt install -y \
    hyprland \
    waybar \
    rofi \
    kitty \
    dolphin \
    mako-notifier \
    hyprpaper \
    wl-clipboard \
    cliphist \
    brightnessctl \
    pipewire-pulse \
    wireplumber \
    stow \
    git \
    fonts-firacode \
    grim \
    slurp \
    jq \
    libnotify-bin \
    pavucontrol \
    wlogout \
    hyprland-qtutils

echo "==> Installing Hyprshot"
sudo curl -o /usr/local/bin/hyprshot \
    https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot
sudo chmod +x /usr/local/bin/hyprshot

case "$PROFILE" in
    nvidia-desktop)
        echo "==> Detecting and installing recommended NVIDIA driver"
        sudo apt install -y ubuntu-drivers-common
        ubuntu-drivers devices
        sudo ubuntu-drivers install
        sudo apt install -y libnvidia-egl-wayland1
        echo "NOTE: reboot required after NVIDIA driver install."
        echo "NOTE: also confirm nvidia-drm.modeset=1 is set (see README)."
        echo "NOTE: Blackwell-generation cards (RTX 50-series) require the -open driver"
        echo "      variant -- 'ubuntu-drivers install' already accounts for this."
        ;;
    laptop-igpu)
        echo "==> Installing Mesa / power-management packages"
        sudo apt install -y mesa-vulkan-drivers tlp tlp-rdw
        sudo systemctl enable tlp
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        exit 1
        ;;
esac

echo "==> Done. Next: run ./install.sh $PROFILE"
