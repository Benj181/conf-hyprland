#!/usr/bin/env bash
# install.sh
# The only command needed to set this machine up. Installs packages, themes
# and the login screen, then symlinks every config into place with GNU Stow.
#
# Targets one machine (europa, Arch Linux); no hardware detection.
# Machine-specific settings: hypr/.config/hypr/hardware.lua.
#
# Usage:
#   ./install.sh                  everything
#   ./install.sh --skip-packages  configs only (no pacman/AUR/theme/nvim steps)
#   ./install.sh --skip-greeter   everything except the display manager switch
#   ./install.sh --dry-run        report what would change, write nothing

set -euo pipefail
cd "$(dirname "$0")"
DOTFILES_DIR="$(pwd)"

PACKAGES=(hypr waybar rofi mako kitty btop nvim hyprlock hypridle theme zsh xkb)

SKIP_PACKAGES=0
SKIP_GREETER=0
DRY_RUN=0

usage() { sed -n '2,13p' "$0" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-greeter)  SKIP_GREETER=1 ;;
        --dry-run)       DRY_RUN=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "=== DRY RUN: nothing will be written ==="
fi

# A dry run skips packages.sh, so stow may not be installed yet.
if ! command -v stow >/dev/null; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "    note: stow not installed yet (scripts/packages.sh adds it);"
        echo "          skipping the stow rehearsal, running the other checks"
    else
        echo "GNU stow is required: sudo pacman -S stow" >&2
        exit 1
    fi
fi

# Ask for sudo once up front rather than surprising the user mid-run.
if [[ "$SKIP_PACKAGES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    echo "==> This needs sudo for pacman and /etc"
    sudo -v
fi

if [[ "$SKIP_PACKAGES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    ./scripts/packages.sh
    # Needs base-devel and the databases packages.sh just refreshed.
    ./scripts/install-aur.sh 0
else
    echo "==> Skipping packages"
fi

# Usually a no-op (generated files are committed); catches a palette edited
# without re-running theme.sh.
if [[ "$DRY_RUN" -eq 1 ]]; then
    ./scripts/theme.sh --check
else
    ./scripts/theme.sh --no-reload
fi

./scripts/preflight.sh "$DOTFILES_DIR" "$DRY_RUN" "${PACKAGES[@]}"

echo "==> Stowing: ${PACKAGES[*]}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    if command -v stow >/dev/null; then
        stow -n -v -t "$HOME" "${PACKAGES[@]}" 2>&1 | sed 's/^/    /'
    fi
    # These scripts' checks are read-only, so a dry run still runs them.
    ./scripts/install-aur.sh 1
    ./scripts/install-keyring.sh 1
    ./scripts/install-zsh.sh 1
    if [[ "$SKIP_GREETER" -eq 0 ]]; then
        ./scripts/install-greeter.sh "$DOTFILES_DIR" 1
    fi
    echo "=== DRY RUN complete: nothing was written ==="
    exit 0
fi
stow -v -t "$HOME" "${PACKAGES[@]}" 2>&1 | sed 's/^/    /'

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
    ./scripts/install-themes.sh
    ./scripts/install-keyring.sh 0
    if [[ "$SKIP_GREETER" -eq 0 ]]; then
        ./scripts/install-greeter.sh "$DOTFILES_DIR" 0
    else
        echo "==> Skipping greeter (--skip-greeter)"
    fi
    ./scripts/bootstrap-nvim.sh
    ./scripts/install-zsh.sh 0
fi

echo
echo "==> Done."
echo "    Reload Hyprland with:  hyprctl reload"
echo "    Check for problems:    hyprctl configerrors"
echo
echo "    If the NVIDIA driver or the kernel was installed or upgraded just"
echo "    now, reboot before expecting Hyprland to come up cleanly. pacman -Syu"
echo "    can land a kernel, and the running one's modules go away with it."

if [[ "$SKIP_PACKAGES" -eq 0 && "$SKIP_GREETER" -eq 0 ]]; then
    echo
    echo "    The login screen is now greetd + nwg-hello, which only takes"
    echo "    effect on reboot. Check 'systemctl status greetd' and keep a TTY"
    echo "    reachable the first time -- see README, Login screen."
fi
