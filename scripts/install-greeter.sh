#!/usr/bin/env bash
# scripts/install-greeter.sh
# Installs the greetd + nwg-hello login screen and points the display manager
# at it.
#
# WHY THIS ISN'T A STOW PACKAGE
#
# Every other directory in this repo mirrors $HOME and gets symlinked there by
# stow. The greeter cannot work that way. greetd runs the greeter as the
# `_greetd` system user *before* anyone logs in, and /home/baas is mode 750 --
# _greetd cannot even traverse it, let alone read ~/.config. So the greeter's
# config has to live in /etc, its wallpaper in /usr/share, and its fonts in
# /usr/local/share/fonts. All of that needs root, none of it is a symlink into
# this repo, and so this is a copy-in step rather than a stow package.
#
# That also means the files under greeter/ are the source of truth and the
# copies in /etc are build output: edit the former, re-run this, never edit the
# latter.
#
# THE FORM IS ON ONE MONITOR ON PURPOSE
#
# nwg-hello.json sets "monitor_nums": [1] -- the greeter appears on DP-3 only.
# That is not cosmetic, it is what makes the password field typable.
#
# main.py builds one window per monitor, and *every* window asks gtk-layer-shell
# for keyboard-mode "exclusive". Two exclusive surfaces cannot both hold the
# keyboard, and the loop is `for i in reversed(range(n_monitors))`, so DP-2
# (GDK index 0) is created last and wins. Typing at DP-3 silently fed the
# portrait screen's password field instead.
#
# Measured, not guessed -- each window's has_toplevel_focus() with the real
# config:
#
#   default  ("monitor_nums": [])      DP-3 focus=False   DP-2 focus=True   broken
#   "form_on_monitors": [1]            DP-3 focus=False   DP-2 focus=True   WORSE:
#                                      the focused DP-2 window is an EmptyWindow
#                                      with no password field at all
#   "monitor_nums": [1]                DP-3 focus=True    (DP-2 has no surface)
#
# So form_on_monitors, which reads like the setting for exactly this, cannot
# fix it: EmptyWindow sets the same exclusive keyboard mode as GreeterWindow.
# Only having a single surface works.
#
# GDK monitor indices, from Gdk.Display.get_monitor(i) -- both panels report
# the model "LG ULTRAGEAR", so geometry is the only way to tell them apart:
#
#   index 0 = 1440x2560+-1440+0  DP-2, portrait
#   index 1 = 2560x1440+0+0      DP-3, landscape
#
# If the monitor layout changes, re-derive with:
#   python3 -c 'import gi; gi.require_version("Gdk","3.0"); from gi.repository import Gdk
#   d=Gdk.Display.get_default()
#   [print(i, d.get_monitor(i).get_geometry().width, d.get_monitor(i).get_geometry().height) for i in range(d.get_n_monitors())]'
#
# Usage: install-greeter.sh [dotfiles_dir] [dry_run:0|1]
#
# Both arguments are optional so this can be re-run on its own after editing
# greeter/, without a full install.sh (which would re-run apt):
#
#   ./scripts/install-greeter.sh

set -euo pipefail

DOTFILES_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${2:-0}"

SRC="$DOTFILES_DIR/greeter"
USER_FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
SYS_FONT_DIR="/usr/local/share/fonts/NerdFonts"
WALLPAPER="$DOTFILES_DIR/wallpapers/mocha-landscape.jpg"

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    would: $*"
    else
        "$@"
    fi
}

for cmd in greetd nwg-hello; do
    if ! command -v "$cmd" >/dev/null 2>&1 && ! [ -x "/usr/sbin/$cmd" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            # A dry run on a machine that has not been set up yet is the normal
            # case -- report and keep going rather than failing the whole run.
            echo "    note: $cmd not installed yet (scripts/packages.sh adds it)"
        else
            echo "==> $cmd not installed; run scripts/packages.sh first" >&2
            exit 1
        fi
    fi
done

echo "==> Installing greeter (greetd + nwg-hello)"

# ---------------------------------------------------------------------------
# Fonts. The greeter CSS asks for "FiraCode Nerd Font" to match hyprlock. The
# session's copy in ~/.local/share/fonts is invisible to _greetd (see above),
# and a font GTK cannot find does not error -- it silently falls back, which is
# exactly the class of bug the rest of this repo keeps tripping over. So the
# greeter gets its own system-wide copy.
#
# This is a copy of what install-fonts.sh already installed rather than a
# second download: install.sh runs that first, so the two cannot drift within
# a run.
# ---------------------------------------------------------------------------
if [ -d "$USER_FONT_DIR" ]; then
    echo "    fonts -> $SYS_FONT_DIR"
    run sudo mkdir -p "$SYS_FONT_DIR"
    run sudo cp -a "$USER_FONT_DIR/." "$SYS_FONT_DIR/"
    run sudo fc-cache -f "$SYS_FONT_DIR"
else
    echo "    WARNING: $USER_FONT_DIR missing; run scripts/install-fonts.sh." >&2
    echo "             The greeter will fall back to a default sans font." >&2
fi

# ---------------------------------------------------------------------------
# Wallpaper. Same reasoning: _greetd cannot read the repo, so the image is
# copied somewhere world-readable. nwg-hello.css references this path.
# ---------------------------------------------------------------------------
echo "    wallpaper -> /usr/share/nwg-hello/wallpaper.jpg"
run sudo mkdir -p /usr/share/nwg-hello
run sudo install -m 644 "$WALLPAPER" /usr/share/nwg-hello/wallpaper.jpg

# ---------------------------------------------------------------------------
# Config. Back up whatever is already there before replacing it.
#
# The test is "differs from what we are about to write", not a marker string:
# nwg-hello.json is JSON and cannot carry a comment to mark, so any marker
# scheme would re-back-up that file on every single run. Comparing content
# makes this idempotent -- a second run with nothing changed backs up nothing
# -- while still catching both the stock config and any hand edit.
# ---------------------------------------------------------------------------
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
install_config "$SRC/etc/nwg-hello/hyprland.conf"  /etc/nwg-hello/hyprland.conf
install_config "$SRC/etc/greetd/config.toml"       /etc/greetd/config.toml

# ---------------------------------------------------------------------------
# Centred form template, derived from the installed nwg-hello rather than
# vendored -- see scripts/greeter-template.py for why.
#
# If the derivation fails, fall back to the stock left-aligned layout instead
# of shipping a template that might be missing a widget ui.py will ask for. A
# greeter that crashes on startup is a greeter you cannot log in through.
# ---------------------------------------------------------------------------
TEMPLATE_SRC="$(python3 -c 'import os.path, nwg_hello; print(os.path.join(os.path.dirname(nwg_hello.__file__), "template.glade"))' 2>/dev/null || true)"

if [ -n "$TEMPLATE_SRC" ] && [ -f "$TEMPLATE_SRC" ]; then
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    if python3 "$DOTFILES_DIR/scripts/greeter-template.py" "$TEMPLATE_SRC" "$tmp"; then
        echo "    template -> /etc/nwg-hello/hyprlock.glade (form centred)"
        run sudo install -m 644 "$tmp" /etc/nwg-hello/hyprlock.glade
    else
        echo "    WARNING: could not centre the form template; using stock layout" >&2
        run sudo sed -i 's/"template-name": "hyprlock.glade"/"template-name": ""/' \
            /etc/nwg-hello/nwg-hello.json
    fi
else
    echo "    WARNING: nwg-hello's template.glade not found; using stock layout" >&2
    run sudo sed -i 's/"template-name": "hyprlock.glade"/"template-name": ""/' \
        /etc/nwg-hello/nwg-hello.json
fi

# ---------------------------------------------------------------------------
# _greetd needs to be in `video` to drive the GPU. Debian's greetd postinst
# creates the account but does not do this, and nwg-hello's own README calls
# the Debian packaging out for it. Without it the greeter cannot open a DRM
# device and you get a black screen at boot.
# ---------------------------------------------------------------------------
if getent passwd _greetd >/dev/null; then
    # Here-string, not a pipe. `id -nG | tr | grep -Fxq` under `set -o
    # pipefail` returns 141 *when it matches*: grep -q exits on the first hit,
    # the upstream commands die of SIGPIPE, and pipefail propagates that. The
    # test would claim _greetd is not in `video` precisely when it is, and
    # then `set -e` would kill the script on the usermod that follows. This
    # repo has shipped that bug twice already (install-fonts.sh, packages.sh).
    greetd_groups="$(id -nG _greetd 2>/dev/null | tr ' ' '\n')"
    if ! grep -Fxq video <<<"$greetd_groups"; then
        echo "    adding _greetd to the video group"
        run sudo usermod -aG video _greetd
    fi
    # nwg-hello remembers the last user and session here. If the directory is
    # missing it logs an error on every start and forgets your session choice.
    run sudo mkdir -p /var/cache/nwg-hello
    run sudo chown _greetd:_greetd /var/cache/nwg-hello
else
    echo "    WARNING: no _greetd user; is greetd installed?" >&2
fi

# ---------------------------------------------------------------------------
# Point the display manager at greetd.
#
# greetd.service declares `Alias=display-manager.service`, so enabling it
# claims /etc/systemd/system/display-manager.service -- but only once gdm has
# let go of it, hence the disable first and --force second. gdm3 is left
# installed on purpose: it makes the rollback one command instead of an apt
# transaction from a TTY.
# ---------------------------------------------------------------------------
echo "    switching display manager: gdm3 -> greetd"
run sudo systemctl disable gdm.service 2>/dev/null || true
run sudo systemctl disable gdm3.service 2>/dev/null || true
run sudo systemctl enable --force greetd.service

# Debian's own display-manager selection. greetd does not register here, but
# gdm3 does, and a gdm3 reconfigure would otherwise quietly take the seat back.
if [ -f /etc/X11/default-display-manager ]; then
    run sudo sh -c 'echo /usr/sbin/greetd > /etc/X11/default-display-manager'
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: nothing was written"
    exit 0
fi

cat <<'EOF'

    Greeter installed. It takes effect at the next reboot.

    This is the one step in this repo that can leave you without a graphical
    login, and it could not be tested non-interactively. Before rebooting,
    check it came up clean:

        systemctl status greetd
        sudo journalctl -u greetd -b

    Keep a TTY reachable (Ctrl+Alt+F3) the first time. If the login screen
    does not appear, roll back with:

        sudo systemctl disable greetd
        sudo systemctl enable --force gdm3
        sudo reboot
EOF
