#!/usr/bin/env bash
# install.sh
# The only command needed to set this machine up. Installs packages, Neovim,
# fonts and themes, then symlinks every config into place with GNU Stow.
#
# This targets one machine (europa) on purpose -- there is no hardware
# detection and no per-host profile. See hypr/.config/hypr/hardware.conf.
#
# Usage:
#   ./install.sh                  everything
#   ./install.sh --skip-packages  configs only (no apt/font/theme/nvim steps)
#   ./install.sh --dry-run        report what would change, write nothing

set -euo pipefail
cd "$(dirname "$0")"
DOTFILES_DIR="$(pwd)"

PACKAGES=(hypr waybar rofi mako kitty nvim hyprlock hypridle wlogout theme)

SKIP_PACKAGES=0
DRY_RUN=0

usage() { sed -n '2,13p' "$0" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --dry-run)       DRY_RUN=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

command -v stow >/dev/null || { echo "GNU stow is required: sudo apt install stow" >&2; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "=== DRY RUN: nothing will be written ==="
fi

# Ask for sudo once up front rather than surprising the user mid-run.
if [[ "$SKIP_PACKAGES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    echo "==> This needs sudo for apt and /opt/nvim"
    sudo -v
fi

if [[ "$SKIP_PACKAGES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    ./scripts/packages.sh
    ./scripts/install-neovim.sh
    ./scripts/install-fonts.sh
else
    echo "==> Skipping packages, neovim and fonts"
fi

./scripts/preflight.sh "$DOTFILES_DIR" "$DRY_RUN" "${PACKAGES[@]}"

echo "==> Stowing: ${PACKAGES[*]}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    stow -n -v -t "$HOME" "${PACKAGES[@]}" 2>&1 | sed 's/^/    /'
    echo "=== DRY RUN complete: nothing was written ==="
    exit 0
fi
stow -v -t "$HOME" "${PACKAGES[@]}" 2>&1 | sed 's/^/    /'

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
    ./scripts/install-themes.sh
    ./scripts/bootstrap-nvim.sh
fi

echo
echo "==> Done."
echo "    Reload Hyprland with:  hyprctl reload"
echo "    Check for problems:    hyprctl configerrors"
echo
echo "    If the NVIDIA driver was installed or upgraded just now, reboot"
echo "    before expecting Hyprland to come up cleanly."
