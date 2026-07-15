#!/usr/bin/env bash
# ~/.config/rofi/powermenu.sh
# Rofi power menu, bound to $mod+SHIFT+X and the waybar power button.
#
# This replaces wlogout. hyprsimple -- the look this setup is modelled on --
# uses a rofi menu for this too; the wlogout config in its repo is vestigial
# and unused. Rofi is what gives the small centred menu instead of a
# fullscreen overlay, and it reuses the Catppuccin theme the launcher already
# uses, so the two match by construction.

set -euo pipefail

THEME="$HOME/.config/rofi/powermenu.rasi"

# Icons are built from codepoints with printf rather than written as literal
# glyphs. Pasted Private Use Area characters get silently stripped to empty
# strings by editors and tooling that do not handle them -- that is exactly
# how this file first shipped with five blank menu entries, and how waybar's
# volume icons were empty in this repo for months. Pure ASCII source cannot
# rot that way.
#
# Codepoints verified by rendering them in FiraCode Nerd Font. Note that a
# codepoint merely *existing* in the font is not enough: U+F035B and U+F075B
# both exist, but only one is a chip.
lock="$(printf '\uf023')"      # padlock
suspend="$(printf '\uf186')"   # moon
logout="$(printf '\uf2f5')"    # sign-out arrow
reboot="$(printf '\uf021')"    # refresh arrows
shutdown="$(printf '\uf011')"  # power symbol
yes="$(printf '\uf00c')"       # check
no="$(printf '\uf00d')"        # times

uptime_str="$(uptime -p 2>/dev/null | sed 's/^up //')"

chosen="$(printf '%s  Lock\n%s  Suspend\n%s  Logout\n%s  Reboot\n%s  Shutdown\n' \
    "$lock" "$suspend" "$logout" "$reboot" "$shutdown" \
    | rofi -dmenu \
        -p "$(whoami)@$(hostname)" \
        -mesg "Uptime: ${uptime_str:-unknown}" \
        -theme "$THEME" \
    || true)"

[ -n "$chosen" ] || exit 0

# Confirm only the destructive actions. Lock and suspend are trivially
# reversible, so a prompt there is just friction.
confirm() {
    local answer
    answer="$(printf '%s  Yes\n%s  No\n' "$yes" "$no" \
        | rofi -dmenu \
            -p "Confirm" \
            -mesg "$1" \
            -theme "$THEME" \
            -theme-str 'listview { lines: 2; }' \
        || true)"
    case "$answer" in
        *Yes) return 0 ;;
        *)    return 1 ;;
    esac
}

case "$chosen" in
    *Lock)     loginctl lock-session ;;
    *Suspend)  systemctl suspend ;;
    *Logout)   confirm "Log out of Hyprland?" && hyprctl dispatch exit ;;
    *Reboot)   confirm "Reboot now?"          && systemctl reboot ;;
    *Shutdown) confirm "Shut down now?"       && systemctl poweroff ;;
esac
