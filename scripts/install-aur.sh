#!/usr/bin/env bash
# scripts/install-aur.sh
# The one package this setup needs that Arch does not carry in its own repos:
# brave-bin. Everything else -- including nwg-hello and hyprshot, which had to
# be worked around on Ubuntu -- comes from extra.
#
# ORDER MATTERS. This must run after scripts/packages.sh:
#
#   - base-devel and git come from there. makepkg without base-devel fails as a
#     wall of compiler noise rather than a useful message.
#   - `makepkg -s` installs build dependencies with `pacman -S` and NO -y. It
#     relies on the databases packages.sh just refreshed with -Syu. Running
#     this first would either fail on a stale database or tempt you into
#     `pacman -Sy` -- the partial upgrade packages.sh goes out of its way to
#     avoid. The same rule applies to paru itself: `paru -Sy` is that same
#     footgun wearing a different hat.
#
# NEVER AS ROOT. makepkg refuses to run as root outright, and it is right to: a
# PKGBUILD is arbitrary shell from a repository anyone can submit to. It calls
# sudo itself for the one step that needs it (pacman -U on the built package).
#
# paru-bin, not paru: paru builds from source and drags in a full Rust
# toolchain for a few minutes' work. paru-bin is the upstream-published binary.
# That is the same trust decision already being made for brave-bin, which is
# the only reason this script exists at all -- so it is not a new one.
#
# Usage: install-aur.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    would: $*"
    else
        "$@"
    fi
}

if [ "$(id -u)" -eq 0 ]; then
    echo "==> install-aur.sh must not run as root: makepkg refuses to build as" >&2
    echo "    root, and it asks for sudo itself when it needs it." >&2
    exit 1
fi

if command -v paru >/dev/null 2>&1; then
    echo "==> paru already present, skipping bootstrap"
else
    # Assert rather than assume -- see ORDER MATTERS above.
    if ! pacman -Qq base-devel >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "    note: base-devel not installed yet (scripts/packages.sh adds it)"
        else
            echo "==> base-devel missing; run scripts/packages.sh first" >&2
            exit 1
        fi
    fi
    if ! command -v git >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "    note: git not installed yet (scripts/packages.sh adds it)"
        else
            echo "==> git missing; run scripts/packages.sh first" >&2
            exit 1
        fi
    fi

    echo "==> Bootstrapping paru from the AUR"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    would: git clone https://aur.archlinux.org/paru-bin.git"
        echo "    would: makepkg -si --noconfirm"
    else
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        # Verify the clone is what it claims before running it -- the same
        # reflex as the old hyprshot shebang check. This is the honest limit of
        # what can be verified about an AUR clone: it proves the repository
        # exists and has the shape of a package, not that its contents are safe.
        [ -f "$tmp/paru-bin/PKGBUILD" ] || {
            echo "==> AUR clone contains no PKGBUILD; refusing to build" >&2
            exit 1
        }
        ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    fi
fi

echo "==> Installing AUR packages"
# `paru -S`, never `paru -Sy`: the partial-upgrade rule in packages.sh applies
# to AUR helpers too. --needed makes a re-run a no-op.
#
# Deliberately not pinned to a commit. The AUR has no tags, and pinning would
# freeze a *browser* out of security updates -- the wrong trade for the one
# package here that talks to the whole internet.
run paru -S --needed --noconfirm brave-bin

# The binary is `brave`, not `brave-browser` as it was from Brave's apt repo.
# hypr/.config/hypr/keybinds.conf names it; a mismatch is a keybind that
# silently does nothing.
if [ "$DRY_RUN" -eq 0 ]; then
    command -v brave >/dev/null || {
        echo "==> brave-bin installed but no 'brave' on PATH" >&2
        echo "    Check with: pacman -Ql brave-bin | grep bin/" >&2
        exit 1
    }
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: nothing was written"
    exit 0
fi

echo "==> AUR packages done"
