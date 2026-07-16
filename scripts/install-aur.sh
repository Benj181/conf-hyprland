#!/usr/bin/env bash
# scripts/install-aur.sh
# The packages this setup needs that Arch does not carry in its own repos:
# paru, brave-bin and claude-code. Everything else -- including discord,
# nwg-hello and hyprshot -- comes from the repos via scripts/packages.sh.
#
# WHY paru IS BUILT FROM SOURCE AND paru-bin IS NOT USED
#
# This is not a preference. paru-bin BREAKS, and did so on a clean Arch install
# of 2026-07:
#
#     paru: error while loading shared libraries: libalpm.so.15
#
# paru links pacman's libalpm. paru-bin ships a binary compiled upstream against
# whatever libalpm was current at release -- .so.15 -- while pacman 7.1 installs
# .so.16. Worse, its PKGBUILD declares `libalpm.so>=14`, an unbounded lower
# bound, so pacman considers .so.16 to satisfy it, installs the package happily,
# and the breakage only appears when the binary is RUN. install.sh died here,
# before stowing anything.
#
# The AUR `paru` package builds from source, so it compiles against the libalpm
# actually installed. That costs a Rust compile and buys a helper that works.
#
# The toolchain it compiles with is not incidental. paru's makedepend is
# `cargo`, and packages.sh has already installed rustup -- which PROVIDES cargo
# -- so `makepkg -s` resolves that dependency to the rustup shims and installs
# nothing. Those shims only work because packages.sh also installed a toolchain
# behind them. If it had not, makepkg would report the dependency satisfied and
# the build would still die on "no default toolchain configured".
#
# THE SAME TRAP APPLIES TO OUR OWN BUILD, LATER
#
# A locally built paru is only correct against the libalpm it was built against.
# The day pacman ships libalpm.so.17, that unbounded `>=14` means pacman will
# NOT consider paru outdated, will not rebuild it, and it dies exactly the way
# paru-bin did. So the check below is not "is paru installed" -- pacman -Q would
# have answered yes in every case above, which is why it was such a good trap.
# It is "does paru RUN", and a paru that does not run is rebuilt.
#
# WHY THERE IS A HELPER AT ALL NOW
#
# Earlier this script built brave-bin by hand and had no helper, on the grounds
# that one package did not justify one. Two things changed: there are three AUR
# packages now, and paru is wanted in its own right. It also closes a
# shortcoming this file used to state plainly -- that with no helper, nothing
# carried brave forward, because `pacman -Syu` does not update AUR packages, and
# brave is the one thing here that talks to the whole internet. `paru -Syu` now
# does, and that is the update path. This script is the bootstrap; paru is the
# maintenance.
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
# PKGBUILD is arbitrary shell from a repository anyone can submit to. paru
# refuses too. Both call sudo themselves for the steps that need it.
#
# Usage: install-aur.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

# Built by hand, because it is the thing that builds the others.
PARU_URL="https://aur.archlinux.org/paru.git"

# Installed with paru, once paru exists.
#
# Deliberately not pinned. The AUR has no tags, and pinning would freeze a
# *browser* out of security updates -- the wrong trade for the one package here
# that talks to the whole internet.
AUR_PKGS=(
    brave-bin      # keybinds.conf names the `brave` binary
    claude-code    # ships /usr/bin/claude
)

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

# The whole point: run it, do not just look for it. See THE SAME TRAP, above.
paru_works() {
    command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1
}

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> AUR packages (dry run)"
    if paru_works; then
        echo "    paru $(paru --version | awk '{print $2}') present and runnable"
    elif command -v paru >/dev/null 2>&1; then
        echo "    paru is INSTALLED BUT DOES NOT RUN -- would rebuild from source:"
        echo "    would: git clone --depth 1 $PARU_URL && makepkg -si --noconfirm"
        paru --version 2>&1 | sed 's/^/        /' || true
    else
        echo "    paru not installed -- would build from source:"
        echo "    would: git clone --depth 1 $PARU_URL && makepkg -si --noconfirm"
    fi
    for pkg in "${AUR_PKGS[@]}"; do
        ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)"
        echo "    would: paru -S --needed $pkg   (installed: ${ver:-none})"
    done
    echo "==> Dry run: nothing was written"
    exit 0
fi

# ---------------------------------------------------------------------------
# Bootstrap paru.
# ---------------------------------------------------------------------------
if paru_works; then
    echo "==> paru $(paru --version | awk '{print $2}') already works; not rebuilding"
else
    if command -v paru >/dev/null 2>&1; then
        echo "==> paru is installed but does not run. Rebuilding against the"
        echo "    libalpm actually present:"
        paru --version 2>&1 | sed 's/^/        /' || true
    else
        echo "==> Building paru from source"
    fi

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth 1 "$PARU_URL" "$tmp/paru"

    # Verify the clone is what it claims before running it. This is the honest
    # limit of what can be verified about an AUR clone: it proves the repository
    # exists and has the shape of a package, not that its contents are safe.
    [ -f "$tmp/paru/PKGBUILD" ] || {
        echo "==> paru clone contains no PKGBUILD; refusing to build" >&2
        exit 1
    }

    # No --needed here, and that is load-bearing. --needed reaches pacman -U,
    # which compares versions and skips when they match. Rebuilding a BROKEN
    # paru produces the same pkgver as the broken one installed -- so --needed
    # would skip the install and leave the breakage in place, having just spent
    # a Rust compile to fix it.
    ( cd "$tmp/paru" && makepkg -si --noconfirm )

    paru_works || {
        echo "==> paru built and installed but still does not run:" >&2
        paru --version 2>&1 | sed 's/^/        /' >&2 || true
        exit 1
    }
    echo "    paru $(paru --version | awk '{print $2}') built and working"
fi

# ---------------------------------------------------------------------------
# Everything else, through paru.
#
# --needed is what makes this idempotent: paru compares the installed version
# against the AUR's and skips what is already current, so a re-run does not
# rebuild the browser. This replaces a hand-rolled --printsrcinfo version
# comparison that had to reconstruct brave-bin's epoch to avoid exactly that.
# ---------------------------------------------------------------------------
echo "==> Installing AUR packages: ${AUR_PKGS[*]}"
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

# Prove the binaries the configs name actually landed, rather than assuming the
# packages did what they say. The binary is `brave`, not `brave-browser`;
# hypr/.config/hypr/keybinds.conf names it, and a mismatch is a keybind that
# silently does nothing.
echo "==> Verifying AUR binaries"
missing=0
for bin in brave claude; do
    if command -v "$bin" >/dev/null 2>&1; then
        echo "    OK: $bin"
    else
        echo "    MISSING: $bin" >&2
        missing=1
    fi
done
[ "$missing" -eq 0 ] || {
    echo "An AUR package installed but did not provide the binary named above." >&2
    echo "Inspect with: pacman -Ql ${AUR_PKGS[*]} | grep bin/" >&2
    exit 1
}

echo "==> AUR packages done"
