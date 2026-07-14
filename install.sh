#!/usr/bin/env bash
# install.sh
# Symlinks all dotfile packages into place with GNU Stow, then points
# machine.conf at the correct per-host variant.
#
# Usage: ./install.sh [nvidia-desktop|laptop-igpu]
#   If no profile is given, tries to guess from `hostname`, falling back
#   to asking interactively.

set -euo pipefail
cd "$(dirname "$0")"

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
    case "$(hostname)" in
        *nvidia*|*desktop*) PROFILE="nvidia-desktop" ;;
        *laptop*)           PROFILE="laptop-igpu" ;;
        *)
            echo "Could not guess profile from hostname '$(hostname)'."
            select p in "nvidia-desktop" "laptop-igpu"; do
                PROFILE="$p"
                break
            done
            ;;
    esac
fi

echo "==> Using profile: $PROFILE"

if [[ ! -f "hypr/.config/hypr/machine/${PROFILE}.conf" ]]; then
    echo "No machine profile found at hypr/.config/hypr/machine/${PROFILE}.conf"
    exit 1
fi

echo "==> Stowing dotfile packages (hypr, waybar, rofi, mako)"
stow -v -t "$HOME" hypr
stow -v -t "$HOME" waybar
stow -v -t "$HOME" rofi
stow -v -t "$HOME" mako

echo "==> Linking machine.conf -> machine/${PROFILE}.conf"
ln -sf "machine/${PROFILE}.conf" "$HOME/.config/hypr/machine.conf"

echo "==> Done."
echo "    If this is a fresh machine, run scripts/bootstrap-packages.sh $PROFILE first."
echo "    Log out and select Hyprland from your display manager to test."
