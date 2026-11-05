#!/usr/bin/env bash
# scripts/theme.sh
# Renders palettes/<name>.env through templates/ into the per-app colour files
# that each stow package ships, then reloads whatever is running.
#
# Usage:
#   ./scripts/theme.sh                 re-render the active palette
#   ./scripts/theme.sh mono-neutral    switch to a palette and render it
#   ./scripts/theme.sh --list          show available palettes
#   ./scripts/theme.sh --check         verify generated files are up to date
#   ./scripts/theme.sh --no-reload     render only, do not touch running apps
#
# Generated files are committed, so a fresh install never needs to run this.

set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"

PALETTE_DIR="$REPO/palettes"
TEMPLATE_DIR="$REPO/templates"
ACTIVE_FILE="$PALETTE_DIR/.active"

RELOAD=1
CHECK=0
PALETTE=""

usage() {
    cat <<'EOF'
Usage:
  ./scripts/theme.sh                 re-render the active palette
  ./scripts/theme.sh mono-neutral    switch to a palette and render it
  ./scripts/theme.sh --list          show available palettes
  ./scripts/theme.sh --check         verify generated files are up to date
  ./scripts/theme.sh --no-reload     render only, do not touch running apps
EOF
}

list_palettes() {
    echo "Available palettes:"
    local active=""
    [[ -f "$ACTIVE_FILE" ]] && active="$(<"$ACTIVE_FILE")"
    local f n
    for f in "$PALETTE_DIR"/*.env; do
        [[ -e "$f" ]] || continue
        n="$(basename "$f" .env)"
        if [[ "$n" == "$active" ]]; then
            echo "  * $n (active)"
        else
            echo "    $n"
        fi
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-reload) RELOAD=0 ;;
        --check)     CHECK=1; RELOAD=0 ;;
        --list)      list_palettes; exit 0 ;;
        -h|--help)   usage; exit 0 ;;
        -*)          echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)           PALETTE="$1" ;;
    esac
    shift
done

# No palette named: reuse the active one.
if [[ -z "$PALETTE" ]]; then
    if [[ -f "$ACTIVE_FILE" ]]; then
        PALETTE="$(<"$ACTIVE_FILE")"
    else
        PALETTE="mono-neutral"
    fi
fi

PALETTE_FILE="$PALETTE_DIR/$PALETTE.env"
if [[ ! -f "$PALETTE_FILE" ]]; then
    echo "No such palette: $PALETTE" >&2
    echo >&2
    list_palettes >&2
    exit 1
fi

# Parse the palette with a regex rather than sourcing it, so keys can be
# enumerated and the file is never executed. Values must be quoted so a
# trailing `# comment` is not mistaken for part of a #rrggbb value.
declare -A COLORS=()
KEYS=()
lineno=0
while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ ! "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=\"([^\"]*)\" ]]; then
        echo "$PALETTE_FILE:$lineno: expected key=\"value\", got: $line" >&2
        exit 1
    fi
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    if [[ "$key" != "name" && ! "$val" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        echo "$PALETTE_FILE:$lineno: $key must be #rrggbb, got: $val" >&2
        exit 1
    fi
    COLORS["$key"]="$val"
    KEYS+=("$key")
done < "$PALETTE_FILE"

# Keys every template may use.
REQUIRED=(
    bg bg_alt surface surface_hi border muted dim text accent
    urgent warn good
    red green yellow blue magenta cyan
    red_br green_br yellow_br blue_br magenta_br cyan_br
)
missing=()
for key in "${REQUIRED[@]}"; do
    [[ -v COLORS["$key"] ]] || missing+=("$key")
done
if (( ${#missing[@]} )); then
    echo "$PALETTE_FILE is missing required keys: ${missing[*]}" >&2
    echo "Copy palettes/mono-neutral.env and edit it rather than starting fresh." >&2
    exit 1
fi

# Three forms per key: {{key}} = #rrggbb, {{key_raw}} = rrggbb (hyprlang
# rgba()), {{key_rgb}} = "r, g, b" (GTK rgba()).
SED_SCRIPT="$(mktemp)"
trap 'rm -f "$SED_SCRIPT"' EXIT

for key in "${KEYS[@]}"; do
    val="${COLORS[$key]}"
    printf 's|{{%s}}|%s|g\n' "$key" "$val" >> "$SED_SCRIPT"
    if [[ "$val" =~ ^#([0-9a-fA-F]{6})$ ]]; then
        raw="${BASH_REMATCH[1]}"
        printf 's|{{%s_raw}}|%s|g\n' "$key" "$raw" >> "$SED_SCRIPT"
        printf 's|{{%s_rgb}}|%d, %d, %d|g\n' "$key" \
            "$((16#${raw:0:2}))" "$((16#${raw:2:2}))" "$((16#${raw:4:2}))" >> "$SED_SCRIPT"
    fi
done
printf 's|{{palette}}|%s|g\n' "$PALETTE" >> "$SED_SCRIPT"

# Longest pattern first, so {{bg}} cannot match inside {{bg_alt}}. Sort on the
# pattern field's length, not the whole line.
sort_tmp="$(mktemp)"
awk -F'|' '{ print length($2) "\t" $0 }' "$SED_SCRIPT" \
    | sort -rn -k1,1 | cut -f2- > "$sort_tmp"
mv "$sort_tmp" "$SED_SCRIPT"

# Manifest: template -> destination, relative to the repo root.
# GTK3 and GTK4 use different @define-color names, hence two templates.
MANIFEST=(
    "waybar-colors.css|waybar/.config/waybar/colors.css"
    "rofi-colors.rasi|rofi/.config/rofi/colors.rasi"
    "kitty-colors.conf|kitty/.config/kitty/colors.conf"
    "btop.theme|btop/.config/btop/themes/generated.theme"
    "mako-config|mako/.config/mako/config"
    "hyprlock.conf|hyprlock/.config/hypr/hyprlock.conf"
    "hypr-colors.lua|hypr/.config/hypr/colors.lua"
    "hyprpaper.conf|hypr/.config/hypr/hyprpaper.conf"
    "nvim-colors.lua|nvim/.config/nvim/lua/palette.lua"
    "gtk3-colors.css|theme/.config/gtk-3.0/colors.css"
    "gtk4-colors.css|theme/.config/gtk-4.0/colors.css"
    "qt6ct-colors.conf|theme/.config/qt6ct/colors/generated.conf"
    "greeter.css|greeter/etc/nwg-hello/nwg-hello.css"
    "greeter-hyprland.lua|greeter/etc/nwg-hello/hyprland.lua"
)

echo "==> Rendering palette: $PALETTE"

changed=0
stale=()
for entry in "${MANIFEST[@]}"; do
    src="$TEMPLATE_DIR/${entry%%|*}"
    dst="$REPO/${entry##*|}"

    if [[ ! -f "$src" ]]; then
        echo "Missing template: $src" >&2
        exit 1
    fi

    out="$(mktemp)"
    sed -f "$SED_SCRIPT" "$src" > "$out"

    # A leftover {{placeholder}} means the palette lacks a key the template uses.
    if grep -q '{{' "$out"; then
        echo "Unsubstituted placeholders in ${entry%%|*}:" >&2
        grep -o '{{[a-zA-Z0-9_]*}}' "$out" | sort -u | sed 's/^/    /' >&2
        rm -f "$out"
        exit 1
    fi

    if [[ -f "$dst" ]] && cmp -s "$out" "$dst"; then
        rm -f "$out"
        continue
    fi

    if (( CHECK )); then
        stale+=("${entry##*|}")
        rm -f "$out"
        continue
    fi

    mkdir -p "$(dirname "$dst")"
    # mv for an atomic replace; chmod because mktemp files are 0600 and the
    # greeter files must be readable by the `greeter` user.
    mv "$out" "$dst"
    chmod 644 "$dst"
    echo "    ${entry##*|}"
    changed=$((changed + 1))
done

if (( CHECK )); then
    if (( ${#stale[@]} )); then
        echo "Out of date with palettes/$PALETTE.env:" >&2
        printf '    %s\n' "${stale[@]}" >&2
        echo "Run ./scripts/theme.sh to regenerate." >&2
        exit 1
    fi
    echo "    all generated files are up to date"
    exit 0
fi

# The wallpaper is generated from the palette too.
if command -v python3 >/dev/null 2>&1 && [[ -f "$REPO/scripts/make-wallpaper.py" ]]; then
    python3 "$REPO/scripts/make-wallpaper.py" "$PALETTE_FILE" "$REPO/wallpapers"
fi

(( changed == 0 )) && echo "    no changes"
printf '%s\n' "$PALETTE" > "$ACTIVE_FILE"

# Reload running apps. Best-effort: there may be no compositor (SSH, TTY, install).
if (( RELOAD == 0 )); then
    echo "==> Skipping reload (--no-reload)"
    exit 0
fi

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "==> Not inside a Hyprland session, skipping reload"
    exit 0
fi

echo "==> Reloading"

if hyprctl reload >/dev/null 2>&1; then
    echo "    hyprland"
fi

# SIGUSR2 reloads waybar's config and style (SIGUSR1 only toggles visibility).
if pkill -SIGUSR2 waybar 2>/dev/null; then
    echo "    waybar"
fi

if command -v makoctl >/dev/null 2>&1 && makoctl reload >/dev/null 2>&1; then
    echo "    mako"
fi

# Recolour open kitty windows over remote control. kitty appends its pid to
# the socket name, so `listen_on unix:@kitty` means @kitty-<pid>.
if command -v kitten >/dev/null 2>&1; then
    kitty_done=0
    for pid in $(pgrep -x kitty 2>/dev/null || true); do
        if kitten @ --to "unix:@kitty-$pid" set-colors -a -c \
            "$REPO/kitty/.config/kitty/colors.conf" >/dev/null 2>&1; then
            kitty_done=$((kitty_done + 1))
        fi
    done
    (( kitty_done )) && echo "    kitty ($kitty_done instance(s))"
fi

# hyprpaper has no reload request, so restart it to re-read hyprpaper.conf.
if pgrep -x hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper || true
    # Launched through the compositor so it gets the session's environment.
    # With the Lua config, dispatch arguments are Lua: `dispatch exec ...` fails.
    hyprctl dispatch 'hl.dsp.exec_cmd("hyprpaper")' >/dev/null 2>&1 || true
    echo "    hyprpaper"
fi

echo
echo "==> Done. nvim and GTK/Qt apps pick the new palette up on next launch."
