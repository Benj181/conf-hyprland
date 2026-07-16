#!/usr/bin/env bash
# scripts/install-aur.sh
# The one package this setup needs that Arch does not carry in its own repos:
# brave-bin. Everything else -- including nwg-hello and hyprshot -- comes from
# the extra repo.
#
# WHY THERE IS NO AUR HELPER
#
# This used to bootstrap paru-bin and then run `paru -S brave-bin`. A helper for
# exactly one package was already thin, but what settled it is that paru-bin
# BREAKS, and did so on a clean Arch install of 2026-07:
#
#     paru: error while loading shared libraries: libalpm.so.15
#
# paru links pacman's libalpm. paru-bin ships a binary upstream compiled against
# whatever libalpm was current at release -- .so.15 -- while pacman 7.1 installs
# .so.16. Worse, paru-bin's PKGBUILD declares `libalpm.so>=14`, an unbounded
# lower bound, so pacman considers .so.16 to satisfy it, installs the package
# happily, and the breakage only appears when the binary is RUN. install.sh then
# died here, before stowing anything.
#
# The old comment justified paru-bin as "the same trust decision already being
# made for brave-bin, so it is not a new one". The trust decision was the same.
# The ABI coupling was not: brave-bin does not link libalpm, so it cannot break
# this way, and the analogy was what made the risk invisible. (Building `paru`
# from source does fix it -- it compiles against the libalpm actually installed
# -- but that drags in a full Rust toolchain for a helper we do not need.)
#
# makepkg alone installs brave-bin in seconds, which is all the helper was ever
# doing here. The clone-verify-makepkg dance below is not new code: it is what
# this script already did to bootstrap paru, pointed at the package we actually
# want.
#
# CONSEQUENCE, STATED PLAINLY: with no helper there is no `paru -Syu` to carry
# brave forward, and pacman -Syu does not update AUR packages. Brave is the one
# thing here that talks to the whole internet, so it must not silently rot. This
# script therefore re-checks the AUR every run and rebuilds when upstream is
# newer, which makes `./scripts/install-aur.sh` the update path. Run it when you
# want a browser update; nothing else will do it for you.
#
# ORDER MATTERS. This must run after scripts/packages.sh:
#
#   - base-devel and git come from there. makepkg without base-devel fails as a
#     wall of compiler noise rather than a useful message.
#   - `makepkg -s` installs build dependencies with `pacman -S` and NO -y. It
#     relies on the databases packages.sh just refreshed with -Syu. Running this
#     first would either fail on a stale database or tempt you into `pacman -Sy`
#     -- the partial upgrade packages.sh goes out of its way to avoid.
#
# NEVER AS ROOT. makepkg refuses to run as root outright, and it is right to: a
# PKGBUILD is arbitrary shell from a repository anyone can submit to. It calls
# sudo itself for the one step that needs it (pacman -U on the built package).
#
# Usage: install-aur.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

AUR_PKG=brave-bin
AUR_URL="https://aur.archlinux.org/${AUR_PKG}.git"

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

# Assert rather than assume -- see ORDER MATTERS above.
for dep in base-devel git; do
    if ! pacman -Qq "$dep" >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "    note: $dep not installed yet (scripts/packages.sh adds it)"
        else
            echo "==> $dep missing; run scripts/packages.sh first" >&2
            exit 1
        fi
    fi
done

echo "==> Installing AUR packages ($AUR_PKG)"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "    would: git clone --depth 1 $AUR_URL"
    echo "    would: makepkg -si --noconfirm   (only if the AUR is newer)"
    echo "==> Dry run: nothing was written"
    exit 0
fi

installed_ver="$(pacman -Q "$AUR_PKG" 2>/dev/null | awk '{print $2}' || true)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 "$AUR_URL" "$tmp/$AUR_PKG"

# Verify the clone is what it claims before running it -- the same reflex as the
# old hyprshot shebang check. This is the honest limit of what can be verified
# about an AUR clone: it proves the repository exists and has the shape of a
# package, not that its contents are safe.
[ -f "$tmp/$AUR_PKG/PKGBUILD" ] || {
    echo "==> AUR clone contains no PKGBUILD; refusing to build" >&2
    exit 1
}

# --printsrcinfo rather than sourcing the PKGBUILD into this shell: it asks
# makepkg what the version is instead of executing the file to find out.
#
# The epoch is not optional here. brave-bin carries one, so `pacman -Q` says
# "1:1.92.140-1" while pkgver-pkgrel alone is "1.92.140-1" -- they never
# compare equal, and the version check silently degrades into rebuilding the
# browser on every run. Reconstruct the full epoch:pkgver-pkgrel that pacman
# reports, and compare like with like.
aur_ver="$(
    cd "$tmp/$AUR_PKG" && makepkg --printsrcinfo 2>/dev/null | awk '
        /^\tepoch =/  {e=$3}
        /^\tpkgver =/ {v=$3}
        /^\tpkgrel =/ {r=$3}
        END {if (v != "") printf "%s%s-%s\n", (e == "" ? "" : e":"), v, r}
    '
)"

if [ -n "$installed_ver" ] && [ "$installed_ver" = "$aur_ver" ]; then
    echo "    $AUR_PKG $installed_ver is current; nothing to build"
else
    if [ -n "$installed_ver" ]; then
        echo "    $AUR_PKG $installed_ver -> $aur_ver"
    else
        echo "    building $AUR_PKG $aur_ver"
    fi
    # Deliberately not pinned to a commit. The AUR has no tags, and pinning
    # would freeze a *browser* out of security updates -- the wrong trade for
    # the one package here that talks to the whole internet.
    ( cd "$tmp/$AUR_PKG" && makepkg -si --noconfirm --needed )
fi

# The binary is `brave`, not `brave-browser`. hypr/.config/hypr/keybinds.conf
# names it; a mismatch is a keybind that silently does nothing.
command -v brave >/dev/null || {
    echo "==> $AUR_PKG installed but no 'brave' on PATH" >&2
    echo "    Check with: pacman -Ql $AUR_PKG | grep bin/" >&2
    exit 1
}

echo "==> AUR packages done"
