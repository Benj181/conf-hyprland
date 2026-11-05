#!/usr/bin/env bash
# scripts/install-greeter.sh
# Installs the greetd + nwg-hello login screen and points the display manager
# at it.
#
# Not a stow package: greetd runs the greeter as the `greeter` user, which
# cannot read /home/baas (mode 750). So config is copied into /etc and the
# wallpaper into /usr/share. greeter/ is the source of truth; never edit the
# copies in /etc.
#
# The asserts below check the Arch/nwg-hello facts these steps rely on. If one
# fires, the machine disagrees with what this repo assumes.
#
# nwg-hello.json sets "monitor_nums": [1] so the greeter only appears on DP-3.
# nwg-hello gives every monitor's window an exclusive keyboard grab and the
# last one created wins, so with two windows typing went to the wrong screen.
# "form_on_monitors" does not help (its empty windows grab the keyboard too).
# To re-derive GDK monitor indices after a layout change:
#   python3 -c 'import gi; gi.require_version("Gdk","3.0"); from gi.repository import Gdk
#   d=Gdk.Display.get_default()
#   [print(i, d.get_monitor(i).get_geometry().width, d.get_monitor(i).get_geometry().height) for i in range(d.get_n_monitors())]'
#
# Usage: install-greeter.sh [dotfiles_dir] [dry_run:0|1]
# Both optional, so it can be re-run on its own after editing greeter/.

set -euo pipefail

DOTFILES_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${2:-0}"

SRC="$DOTFILES_DIR/greeter"

# The wallpaper follows the active palette (written by scripts/theme.sh).
ACTIVE_PALETTE="mono-neutral"
if [ -f "$DOTFILES_DIR/palettes/.active" ]; then
    ACTIVE_PALETTE="$(cat "$DOTFILES_DIR/palettes/.active")"
fi
WALLPAPER="$DOTFILES_DIR/wallpapers/${ACTIVE_PALETTE}-landscape.png"

if [ ! -f "$WALLPAPER" ]; then
    echo "Missing $WALLPAPER" >&2
    echo "Run ./scripts/theme.sh first -- it generates the wallpaper." >&2
    exit 1
fi

# Set when the template derivation falls back, so the summary can say so.
TEMPLATE_FELL_BACK=0

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    would: $*"
    else
        "$@"
    fi
}

# In a dry run, missing prerequisites are reported instead of failing.
missing_dep() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    note: $1"
        return 0
    fi
    echo "==> $1" >&2
    exit 1
}

for pkg in greetd nwg-hello; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        missing_dep "$pkg not installed; run scripts/packages.sh first"
    fi
done

echo "==> Installing greeter (greetd + nwg-hello)"

# ASSERT: the stylesheet's #id selectors match the CSS names nwg-hello sets in
# ui.py (set_property("name", ...), not the .glade ids). A selector that
# matches nothing fails silently and the greeter renders unstyled.
UI_PY="$(python3 -c 'import os.path, nwg_hello; print(os.path.join(os.path.dirname(nwg_hello.__file__), "ui.py"))' 2>/dev/null || true)"

if [ -n "$UI_PY" ] && [ -f "$UI_PY" ]; then
    ui_names="$(grep -oP 'set_property\("name", "\K[^"]+' "$UI_PY" | sort -u)"
    css_ids="$(grep -oP '^#\K[a-z-]+' "$SRC/etc/nwg-hello/nwg-hello.css" | sort -u)"
    dead="$(comm -23 <(printf '%s\n' "$css_ids") <(printf '%s\n' "$ui_names") || true)"
    if [ -n "$dead" ]; then
        echo "    These CSS selectors match no widget in the installed nwg-hello:" >&2
        printf '        #%s\n' $dead >&2
        echo "    nwg-hello's names come from: $UI_PY" >&2
        echo "    Fix greeter/etc/nwg-hello/nwg-hello.css to match, then re-run." >&2
        exit 1
    fi
    echo "    CSS selectors match nwg-hello's widget names"
else
    missing_dep "cannot import nwg_hello to verify CSS selectors"
fi

# ASSERT: config.toml's vt matches the getty greetd.service conflicts with,
# or greetd and a getty fight over the same VT.
# Here-strings, not pipes, into grep -q throughout: under pipefail a match
# returns 141 (SIGPIPE).
vt="$(grep -oP '^vt\s*=\s*\K\d+' "$SRC/etc/greetd/config.toml" || true)"
conflicts="$(systemctl show -p Conflicts --value greetd.service 2>/dev/null || true)"
if [ -z "$conflicts" ]; then
    missing_dep "cannot read greetd.service; is greetd installed?"
elif ! grep -Fq "getty@tty${vt}.service" <<<"$conflicts"; then
    echo "    greetd.service does not conflict with getty@tty${vt}.service." >&2
    echo "    Its Conflicts= is: ${conflicts:-<none>}" >&2
    echo "    A getty and greetd would fight over VT ${vt}." >&2
    echo "    Inspect with: systemctl cat greetd.service" >&2
    echo "    Then set vt in greeter/etc/greetd/config.toml to match, and re-run." >&2
    exit 1
else
    echo "    vt ${vt} matches greetd.service's Conflicts="
fi

# ASSERT: config.toml is in greetd's pacman backup array, so upgrades write a
# .pacnew instead of restoring the stock agreety config.
backups="$(pacman -Qii greetd 2>/dev/null | grep -i '^backup' || true)"
if [ -n "$backups" ] && ! grep -Fq 'etc/greetd/config.toml' <<<"$backups"; then
    echo "    WARNING: /etc/greetd/config.toml is not in greetd's backup array." >&2
    echo "             pacman will overwrite it on every greetd upgrade, with no" >&2
    echo "             .pacnew and no prompt -- restoring the agreety text greeter." >&2
    echo "             Escape hatch: rename it to /etc/greetd/greetd.conf, which" >&2
    echo "             greetd reads first and no package owns." >&2
    echo "             Verify with: pacman -Qii greetd" >&2
fi

# nwg-hello.css references this path.
echo "    wallpaper -> /usr/share/nwg-hello/wallpaper.png"
run sudo mkdir -p /usr/share/nwg-hello
run sudo install -m 644 "$WALLPAPER" /usr/share/nwg-hello/wallpaper.png

# Back up an existing file only if it differs from what is being installed.
BACKUP_DIR="/etc/greetd/backup-$(date +%Y%m%d-%H%M%S)"

install_config() {
    local src="$1" dest="$2"
    if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
        echo "    backing up $dest -> $BACKUP_DIR"
        run sudo mkdir -p "$BACKUP_DIR"
        run sudo cp -a "$dest" "$BACKUP_DIR/"
    fi
    run sudo install -m 644 "$src" "$dest"
}

echo "    config -> /etc/nwg-hello/, /etc/greetd/"
run sudo mkdir -p /etc/nwg-hello
install_config "$SRC/etc/nwg-hello/nwg-hello.json" /etc/nwg-hello/nwg-hello.json
install_config "$SRC/etc/nwg-hello/nwg-hello.css"  /etc/nwg-hello/nwg-hello.css
install_config "$SRC/etc/nwg-hello/hyprland.lua"   /etc/nwg-hello/hyprland.lua
install_config "$SRC/etc/greetd/config.toml"       /etc/greetd/config.toml

# Centred form template, derived from the installed nwg-hello (see
# scripts/greeter-template.py). If that fails, fall back to the stock layout:
# a template missing a widget ui.py expects would crash the greeter.
TEMPLATE_SRC="$(python3 -c 'import os.path, nwg_hello; print(os.path.join(os.path.dirname(nwg_hello.__file__), "template.glade"))' 2>/dev/null || true)"

if [ -n "$TEMPLATE_SRC" ] && [ -f "$TEMPLATE_SRC" ]; then
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    if python3 "$DOTFILES_DIR/scripts/greeter-template.py" "$TEMPLATE_SRC" "$tmp"; then
        echo "    template -> /etc/nwg-hello/hyprlock.glade (form centred)"
        run sudo install -m 644 "$tmp" /etc/nwg-hello/hyprlock.glade
    else
        echo "    WARNING: could not centre the form template; using stock layout" >&2
        TEMPLATE_FELL_BACK=1
        run sudo sed -i 's/"template-name": "hyprlock.glade"/"template-name": ""/' \
            /etc/nwg-hello/nwg-hello.json
    fi
else
    echo "    WARNING: nwg-hello's template.glade not found; using stock layout" >&2
    TEMPLATE_FELL_BACK=1
    run sudo sed -i 's/"template-name": "hyprlock.glade"/"template-name": ""/' \
        /etc/nwg-hello/nwg-hello.json
fi

# greetd's sysusers file creates `greeter`; without it the boot screen is black.
if ! getent passwd greeter >/dev/null; then
    missing_dep "no 'greeter' user; greetd's sysusers should have created it (pacman -Ql greetd | grep sysusers)"
else
    greeter_groups="$(id -nG greeter 2>/dev/null | tr ' ' '\n')"
    if ! grep -Fxq video <<<"$greeter_groups"; then
        echo "    adding greeter to the video group"
        run sudo usermod -aG video greeter
    else
        echo "    greeter is already in the video group"
    fi
    # nwg-hello remembers the last user and session here.
    # `greeter:` = the user's own login group.
    run sudo mkdir -p /var/cache/nwg-hello
    run sudo chown greeter: /var/cache/nwg-hello
fi

# Check as `greeter` that it can see the font and wallpaper; GTK falls back
# silently on a missing font.
if [ "$DRY_RUN" -eq 0 ] && getent passwd greeter >/dev/null; then
    echo "    checking what greeter can read"
    greeter_families="$(sudo -u greeter fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*//' || true)"
    for fam in "FiraCode Nerd Font" "FiraCode Nerd Font Mono"; do
        if ! grep -Fxq "$fam" <<<"$greeter_families"; then
            echo "    greeter cannot see the font family: $fam" >&2
            echo "    The greeter CSS asks for it and GTK will fall back silently." >&2
            echo "    Check with: sudo -u greeter fc-list : family | grep -i fira" >&2
            exit 1
        fi
    done
    echo "        fonts OK"
    if ! sudo -u greeter test -r /usr/share/nwg-hello/wallpaper.png; then
        echo "    greeter cannot read /usr/share/nwg-hello/wallpaper.png" >&2
        exit 1
    fi
    echo "        wallpaper OK"
fi

# greetd.service is WantedBy=graphical.target. Stock Arch already defaults to
# it; this covers a system where something set multi-user.target.
current_target="$(systemctl get-default 2>/dev/null || true)"
if [ "$current_target" != "graphical.target" ]; then
    echo "    default target is ${current_target:-unknown} -> graphical.target"
    echo "        (greetd is WantedBy=graphical.target; without this it would be"
    echo "         'enabled' and still never start)"
    run sudo systemctl set-default graphical.target
else
    echo "    default target is already graphical.target"
fi

# --force takes the display-manager.service alias from any other DM.
echo "    enabling greetd"
run sudo systemctl enable --force greetd.service

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: nothing was written"
    exit 0
fi

if [ "$TEMPLATE_FELL_BACK" -eq 1 ]; then
    cat <<'EOF'

    NOTE: the form template fell back to nwg-hello's stock layout, so the
    login form will be left-aligned rather than centred. The greeter works;
    it just will not match hyprlock. This usually means nwg-hello changed
    its template -- see scripts/greeter-template.py.
EOF
fi

cat <<'EOF'

    Greeter installed. It takes effect at the next reboot.

    This is the one step in this repo that can leave you without a graphical
    login. The plumbing is tested -- greetd starts, runs Hyprland as `greeter`
    and launches nwg-hello -- but that was a VM with no GPU, and the NVIDIA
    path is exactly what a VM cannot check. Confirm before rebooting; greetd
    can be started live, from a TTY, without committing to anything:

        systemctl get-default                       # must be graphical.target
        systemctl list-dependencies graphical.target | grep greetd
        sudo systemctl start greetd                 # draws the greeter on vt1
        sudo systemctl stop greetd                  # ...and backs out again
        sudo journalctl -u greetd -b

    ROLLBACK IS THE BOOTLOADER, NOT ANOTHER GREETER. There is no second
    display manager installed to fall back to, so:

        At the boot menu press `e` and append to the kernel line:
            systemd.unit=multi-user.target
        That boots to a TTY with greetd never started. Then:
            sudo systemctl disable greetd
            sudo systemctl set-default multi-user.target

    Rehearse reaching that menu BEFORE you reboot -- systemd-boot often hides
    it (timeout 0) and you may need to hold Space during POST. Ctrl+Alt+F2
    also still works: VT switching is kernel-level and survives a compositor
    holding the keyboard.
EOF
