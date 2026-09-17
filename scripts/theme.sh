#!/usr/bin/env bash
# scripts/theme.sh
# Renders palettes/<name>.env through templates/ into the per-app colour files
# that each stow package ships, then reloads whatever is running.
#
# The point of this script is that swapping a colour scheme is one edit and one
# command rather than a pass over eight configs. Before it existed the same
# hex value appeared in waybar/style.css, rofi, kitty, mako, hyprlock, both
# gtk.css files, qt6ct and the greeter -- nine places to keep in sync by hand,
# which in practice means they drift and the rice ends up half-retheme.
#
# Usage:
#   ./scripts/theme.sh                 re-render the active palette
#   ./scripts/theme.sh mono-neutral    switch to a palette and render it
#   ./scripts/theme.sh --list          show available palettes
#   ./scripts/theme.sh --check         verify generated files are up to date
#   ./scripts/theme.sh --no-reload     render only, do not touch running apps
#
# Generated files are committed to the repo on purpose. install.sh stows them
# like any other config, so a fresh machine never has to run this first -- and
# a palette change shows up in `git diff` as the rendered result, which is the
# thing you actually review.

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

# No palette named: reuse the last one. A bare `theme.sh` after editing a
# palette file should re-render it, not silently jump back to a default.
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

# ---------------------------------------------------------------------------
# Parse the palette.
#
# Parsed with a regex rather than sourced. Sourcing would be shorter, but it
# gives no way to enumerate the keys that were defined (which is what drives
# substitution below), it would happily accept a typo'd key as a new variable,
# and it turns a colour file into executable code. Quotes are mandatory so the
# trailing `# comment` on each line stays outside the captured value -- a
# value starting with '#' means the usual "strip everything after #" trick
# would eat the colour itself.
# ---------------------------------------------------------------------------
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

# Every template is written against this contract, so a palette missing a key
# must fail here with the key's name rather than 40 lines later with an
# unhelpful "unsubstituted placeholder" on whichever file happened to use it.
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

# ---------------------------------------------------------------------------
# Build the substitution program.
#
# Three forms per key, because the file formats disagree about how a colour is
# spelled: CSS and kitty want #rrggbb, hyprlang wants bare rrggbb inside
# rgba(), and GTK's rgba() wants decimal components.
#
# '|' as the sed delimiter: colour values contain '#' and ',' but never '|'.
# ---------------------------------------------------------------------------
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

# Longest pattern first, or the rule for `{{bg}}` fires against `{{bg_alt}}`
# and leaves a stray `_alt}}` in the output -- and the placeholder check below
# would not catch it, because the `{{` is gone. Sorting on the length of the
# pattern field specifically, not the whole line: a line's total length also
# depends on its value, which has nothing to do with which rule must win.
sort_tmp="$(mktemp)"
awk -F'|' '{ print length($2) "\t" $0 }' "$SED_SCRIPT" \
    | sort -rn -k1,1 | cut -f2- > "$sort_tmp"
mv "$sort_tmp" "$SED_SCRIPT"

# ---------------------------------------------------------------------------
# Manifest: template -> destination, relative to the repo root.
#
# GTK3 and GTK4 get separate templates rather than one shared file: they use
# different @define-color names entirely (theme_bg_color vs window_bg_color),
# and libadwaita ignores the GTK3 names.
# ---------------------------------------------------------------------------
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

    # An unsubstituted placeholder means a template asked for a key the
    # palette does not define. Writing the file anyway would ship a literal
    # "{{foo}}" into a config -- which waybar and rofi parse as a syntax
    # error, and which mako and hyprlock silently ignore, giving you a lock
    # screen with one invisible element and no clue why.
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
    # mv, not cp: these destinations are stow targets, and a partial write to
    # hyprlock.conf is a lock screen that will not come up.
    mv "$out" "$dst"
    # mktemp creates at 0600, which survives the mv and leaves generated
    # configs unreadable by anyone but the owner -- fine for waybar, wrong for
    # greeter/nwg-hello.css, which install-greeter.sh copies out for the
    # `greeter` system user to read.
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

# The wallpaper is palette-driven too, so switching schemes does not leave a
# Catppuccin-purple gradient behind the new grey bar. Separate script because
# it writes a PNG rather than text; see scripts/make-wallpaper.py.
if command -v python3 >/dev/null 2>&1 && [[ -f "$REPO/scripts/make-wallpaper.py" ]]; then
    python3 "$REPO/scripts/make-wallpaper.py" "$PALETTE_FILE" "$REPO/wallpapers"
fi

(( changed == 0 )) && echo "    no changes"
printf '%s\n' "$PALETTE" > "$ACTIVE_FILE"

# ---------------------------------------------------------------------------
# Reload. Every step is best-effort: this script has to work over SSH, from a
# TTY, and mid-install, none of which have a compositor running.
# ---------------------------------------------------------------------------
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

# SIGUSR2 is waybar's reload signal. It re-reads both config and style.css,
# which SIGUSR1 (toggle visibility) does not.
if pkill -SIGUSR2 waybar 2>/dev/null; then
    echo "    waybar"
fi

if command -v makoctl >/dev/null 2>&1 && makoctl reload >/dev/null 2>&1; then
    echo "    mako"
fi

# kitty.conf sets allow_remote_control + listen_on unix:@kitty, so already-open
# terminals can be recoloured without restarting them.
#
# One socket per instance, and the name is NOT the one in kitty.conf: kitty
# appends its pid, so `listen_on unix:@kitty` listens on @kitty-<pid>. Targeting
# the configured name verbatim gets "connection refused" every time -- and
# since this whole block is best-effort, that failure is silent and you are left
# wondering why only the terminal did not follow the palette. Hence the loop.
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

# Restarted rather than signalled. hyprpaper 0.8.4 has no bare `reload`
# request -- `hyprctl hyprpaper reload` answers "invalid hyprpaper request" --
# and the per-monitor `wallpaper MONITOR,path` form would mean this script
# enumerating monitors and duplicating what hyprpaper.conf already says. A
# restart re-reads the config, which is the file that just changed.
if pgrep -x hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper || true
    # Launched through the compositor so it inherits the session's Wayland
    # environment rather than this script's.
    #
    # The Lua-quoted form is required, not stylistic. With hyprland.lua in
    # place hyprctl feeds the dispatch argument straight into Lua, so the
    # familiar `hyprctl dispatch exec hyprpaper` is evaluated as
    # `hl.dispatch(exec hyprpaper)` and dies on a syntax error -- which, being
    # sent to /dev/null here, would show up only as a missing wallpaper.
    hyprctl dispatch 'hl.dsp.exec_cmd("hyprpaper")' >/dev/null 2>&1 || true
    echo "    hyprpaper"
fi

echo
echo "==> Done. nvim and GTK/Qt apps pick the new palette up on next launch."
