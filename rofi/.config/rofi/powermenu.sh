#!/usr/bin/env bash
# ~/.config/rofi/powermenu.sh
# Rofi power menu, bound to $mod+SHIFT+X and the waybar power button.

set -euo pipefail

THEME="$HOME/.config/rofi/powermenu.rasi"

# Nerd Font icons as printf escapes: literal Private Use Area glyphs get
# stripped by some editors and tools.
lock="$(printf '\uf023')"      # padlock
suspend="$(printf '\uf186')"   # moon
logout="$(printf '\uf2f5')"    # sign-out arrow
reboot="$(printf '\uf021')"    # refresh arrows
shutdown="$(printf '\uf011')"  # power symbol
yes="$(printf '\uf00c')"       # check
no="$(printf '\uf00d')"        # times

uptime_str="$(uptime -p 2>/dev/null | sed 's/^up //')"

# ${HOSTNAME}, not $(hostname): `hostname` (inetutils) isn't in Arch's base.
chosen="$(printf '%s  Lock\n%s  Suspend\n%s  Logout\n%s  Reboot\n%s  Shutdown\n' \
    "$lock" "$suspend" "$logout" "$reboot" "$shutdown" \
    | rofi -dmenu \
        -p "$(whoami)@${HOSTNAME}" \
        -mesg "Uptime: ${uptime_str:-unknown}" \
        -theme "$THEME" \
    || true)"

[ -n "$chosen" ] || exit 0

# Confirm only the destructive actions.
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
    *Logout)   confirm "Log out of Hyprland?" && hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reboot)   confirm "Reboot now?"          && systemctl reboot ;;
    *Shutdown) confirm "Shut down now?"       && systemctl poweroff ;;
esac
