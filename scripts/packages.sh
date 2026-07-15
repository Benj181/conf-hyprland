#!/usr/bin/env bash
# scripts/packages.sh
# apt packages for the Hyprland setup on europa (Ubuntu 26.04).
#
# No hardware detection: this targets one machine. europa is a desktop with an
# RTX 5070 Ti (Blackwell), which is open-kernel-module only -- there is no
# proprietary/open branch to pick between, so the driver is named outright
# rather than routed through `ubuntu-drivers install`.

set -euo pipefail

echo "==> Updating package lists"
sudo apt-get update

echo "==> Installing core Hyprland stack"
sudo apt-get install -y \
    hyprland \
    hyprpaper \
    hyprlock \
    hypridle \
    hyprpolkitagent \
    hyprland-qtutils \
    waybar \
    rofi \
    kitty \
    mako-notifier \
    wlogout \
    nautilus \
    wl-clipboard \
    cliphist \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    network-manager-gnome \
    grim \
    slurp \
    jq \
    libnotify-bin \
    stow \
    git \
    curl \
    unzip

echo "==> Installing theming"
# fonts-firacode is deliberately NOT installed: it provides "Fira Code" with no
# Nerd glyphs, which is not what any config here asks for. See install-fonts.sh.
sudo apt-get install -y \
    papirus-icon-theme \
    qt6ct \
    qt5ct \
    nwg-look

echo "==> Installing Neovim toolchain"
# neovim itself comes from install-neovim.sh -- apt has 0.11.6, which is older
# than this config targets.
sudo apt-get install -y \
    ripgrep \
    fd-find \
    fzf \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    luarocks

echo "==> Installing NVIDIA driver (Blackwell: open modules only)"
sudo apt-get install -y nvidia-driver-595-open libnvidia-egl-wayland1

echo "==> Installing hyprshot"
# Not packaged for Ubuntu. Pinned to a tag rather than main so the install is
# reproducible, and verified before being made executable.
HYPRSHOT_VERSION="v1.3.0"
if ! command -v hyprshot >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --retry 3 -o "$tmp/hyprshot" \
        "https://raw.githubusercontent.com/Gustash/Hyprshot/${HYPRSHOT_VERSION}/hyprshot"
    # No `head | grep -q` here: under `set -o pipefail` that returns 141 when
    # it matches (grep -q exits early, head takes SIGPIPE), so a valid download
    # would be rejected.
    read -r firstline < "$tmp/hyprshot" || true
    case "$firstline" in
        '#!'*) ;;
        *) echo "hyprshot download does not look like a script; refusing to install" >&2; exit 1 ;;
    esac
    sudo install -m 755 "$tmp/hyprshot" /usr/local/bin/hyprshot
    echo "    installed hyprshot ${HYPRSHOT_VERSION}"
else
    echo "    hyprshot already present, skipping"
fi

# Ubuntu ships fd-find's binary as `fdfind` to avoid a name clash. Telescope
# and friends look for `fd`.
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "==> Linked fdfind -> ~/.local/bin/fd"
fi

echo "==> Packages done"
