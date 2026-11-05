#!/usr/bin/env bash
# scripts/install-aur.sh
# AUR packages: paru, brave-bin and claude-code. Everything else comes from
# the repos via scripts/packages.sh. After this, `paru -Syu` keeps them updated.
#
# paru is built from source, not paru-bin: paru-bin is compiled against a fixed
# libalpm soname and breaks when pacman bumps it ("error while loading shared
# libraries: libalpm.so.15"), while its `libalpm.so>=14` dependency still looks
# satisfied. A local build has the same risk on the next bump, so the check is
# "does paru run", not "is it installed".
#
# Run after scripts/packages.sh: it provides base-devel, git and the Rust
# toolchain, and refreshes the databases that `makepkg -s` relies on.
# Never as root; makepkg and paru refuse and call sudo themselves.
#
# Usage: install-aur.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

PARU_URL="https://aur.archlinux.org/paru.git"

# Not pinned: pinning would freeze the browser out of security updates.
AUR_PKGS=(
    brave-bin      # provides `brave`, used in keybinds.lua
    claude-code    # ships /usr/bin/claude
)

if [ "$(id -u)" -eq 0 ]; then
    echo "==> install-aur.sh must not run as root: makepkg refuses to build as" >&2
    echo "    root, and it asks for sudo itself when it needs it." >&2
    exit 1
fi

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

# Run it, not just look for it (see header).
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

# Bootstrap paru.
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

    # Only proves the clone looks like a package, not that it is safe.
    [ -f "$tmp/paru/PKGBUILD" ] || {
        echo "==> paru clone contains no PKGBUILD; refusing to build" >&2
        exit 1
    }

    # No --needed: a rebuilt broken paru has the same pkgver and would be skipped.
    ( cd "$tmp/paru" && makepkg -si --noconfirm )

    paru_works || {
        echo "==> paru built and installed but still does not run:" >&2
        paru --version 2>&1 | sed 's/^/        /' >&2 || true
        exit 1
    }
    echo "    paru $(paru --version | awk '{print $2}') built and working"
fi

# --needed skips packages that are already current.
echo "==> Installing AUR packages: ${AUR_PKGS[*]}"
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

# Check the binaries the configs use exist.
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
