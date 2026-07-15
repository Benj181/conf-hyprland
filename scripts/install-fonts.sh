#!/usr/bin/env bash
# scripts/install-fonts.sh
# Installs the Nerd Font the configs actually ask for.
#
# The old bootstrap installed `fonts-firacode`, which provides "Fira Code" --
# no Nerd glyphs at all, so bar icons rendered as tofu on a fresh machine.
# conf-nvim's README extracted only "*Mono*" from FiraCode.zip, which is why
# "FiraCode Nerd Font Mono" existed but the proportional "FiraCode Nerd Font"
# (used by waybar/rofi/mako) never did. Extract the whole archive.

set -euo pipefail

NERD_FONTS_VERSION="v3.4.0"
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/FiraCode.zip"

# Exact family match: "FiraCode Nerd Font" is a substring of "FiraCode Nerd
# Font Mono", so a plain grep would report success while the proportional
# family is still missing -- which is the exact bug this script exists to fix.
have_family() {
    fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -Fxq "$1"
}

if have_family "FiraCode Nerd Font" && have_family "FiraCode Nerd Font Mono"; then
    echo "==> Nerd fonts already present, skipping"
    exit 0
fi

echo "==> Installing FiraCode Nerd Font ${NERD_FONTS_VERSION}"
command -v unzip >/dev/null || { echo "unzip not found; run scripts/packages.sh first" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fL --retry 3 -o "$tmp/FiraCode.zip" "$URL"

mkdir -p "$FONT_DIR"
unzip -oq "$tmp/FiraCode.zip" -d "$FONT_DIR" -x "README.md" "LICENSE" "*.txt"

echo "==> Rebuilding font cache"
fc-cache -f "$FONT_DIR" >/dev/null

# Verify rather than assume: a silent font failure is what caused the tofu in
# the first place.
missing=0
for fam in "FiraCode Nerd Font" "FiraCode Nerd Font Mono"; do
    if have_family "$fam"; then
        echo "    OK: $fam"
    else
        echo "    MISSING: $fam" >&2
        missing=1
    fi
done
[ "$missing" -eq 0 ] || { echo "Font install did not produce the expected families" >&2; exit 1; }
