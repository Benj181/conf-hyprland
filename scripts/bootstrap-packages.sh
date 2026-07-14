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
    fonts-jetbrains-mono

case "$PROFILE" in
    nvidia-desktop)
        echo "==> Detecting and installing recommended NVIDIA driver"
        sudo apt install -y ubuntu-drivers-common
        ubuntu-drivers devices          # shows what it detected/recommends, for your reference
        sudo ubuntu-drivers autoinstall
        # libnvidia-egl-wayland1 is pulled in automatically by driver 555+; only needed
        # manually on older branches. Harmless to install explicitly either way:
        sudo apt install -y libnvidia-egl-wayland1
        echo "NOTE: reboot required after NVIDIA driver install."
        echo "NOTE: also confirm nvidia-drm.modeset=1 is set (see README)."
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
