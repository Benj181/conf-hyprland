#!/usr/bin/env bash
# scripts/install-neovim.sh
# Installs Neovim from the upstream tarball.
#
# Ubuntu 26.04 ships 0.11.6 in apt, which is older than what this config is
# developed against, so `apt install neovim` is not an option. Pinned rather
# than /latest/ so the install is reproducible.
#
# conf-nvim's README appended /opt/nvim/bin to PATH in ~/.bashrc. This
# symlinks into /usr/local/bin instead: it is already on PATH, it touches no
# shell config, and re-running cannot accumulate duplicate PATH entries.

set -euo pipefail

NVIM_VERSION="v0.12.4"
INSTALL_DIR="/opt/nvim"
URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"

current="$(/usr/local/bin/nvim --version 2>/dev/null | head -1 | awk '{print $2}' || true)"
if [ "$current" = "$NVIM_VERSION" ]; then
    echo "==> Neovim ${NVIM_VERSION} already installed, skipping"
    exit 0
fi

echo "==> Installing Neovim ${NVIM_VERSION} to ${INSTALL_DIR}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fL --retry 3 -o "$tmp/nvim.tar.gz" "$URL"
tar -tzf "$tmp/nvim.tar.gz" >/dev/null || { echo "Downloaded tarball is not readable" >&2; exit 1; }

tar -C "$tmp" -xzf "$tmp/nvim.tar.gz"
sudo rm -rf "$INSTALL_DIR"
sudo mv "$tmp/nvim-linux-x86_64" "$INSTALL_DIR"
sudo ln -sfn "${INSTALL_DIR}/bin/nvim" /usr/local/bin/nvim

# apt's neovim would shadow ours depending on PATH order; warn rather than
# silently fight over it.
if dpkg -s neovim >/dev/null 2>&1; then
    echo "    NOTE: the apt 'neovim' package is installed and may shadow"
    echo "          /usr/local/bin/nvim. Consider: sudo apt remove neovim"
fi

echo "==> $(/usr/local/bin/nvim --version | head -1)"
