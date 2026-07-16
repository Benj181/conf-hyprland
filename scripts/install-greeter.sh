#!/usr/bin/env bash
# scripts/install-greeter.sh
# Installs the greetd + nwg-hello login screen and points the display manager
# at it.
#
# WHY THIS ISN'T A STOW PACKAGE
#
# Every other directory in this repo mirrors $HOME and gets symlinked there by
# stow. The greeter cannot work that way. greetd runs the greeter as the
# `greeter` system user *before* anyone logs in, and /home/baas is mode 750 --
# `greeter` cannot even traverse it, let alone read ~/.config. So the greeter's
# config has to live in /etc and its wallpaper in /usr/share. That needs root,
# none of it is a symlink into this repo, and so this is a copy-in step rather
# than a stow package.
#
# That also means the files under greeter/ are the source of truth and the
# copies in /etc are build output: edit the former, re-run this, never edit the
# latter.
#
# (The font used to be copied out here too, for the same reason. It no longer
# is: ttf-firacode-nerd installs to /usr/share/fonts, which `greeter` can
# already read. What replaced the copy is a check that it can -- see below.)
#
# WHY SO MANY ASSERTS
#
# The Arch facts these steps depend on are checked here, at install time, rather
# than encoded as comments -- where being wrong costs a black screen and still
# reads as documentation. Each assert fails with the command that reveals the
# truth.
#
# They have been run against a real Arch VM (nwg-hello 0.4.5, greetd 0.10.3) and
# all pass, so on a healthy system they are quiet. That is the point: an assert
# that fires is telling you the machine disagrees with what this repo believes,
# and the belief is what is out of date. Read it rather than working around it.
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
# greeter/, without a full install.sh (which would re-run pacman):
#
#   ./scripts/install-greeter.sh

set -euo pipefail

DOTFILES_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${2:-0}"

SRC="$DOTFILES_DIR/greeter"
WALLPAPER="$DOTFILES_DIR/wallpapers/mocha-landscape.jpg"

# Set when the template derivation falls back, so the summary can say so. A
# warning that scrolls past mid-install is a warning nobody reads.
TEMPLATE_FELL_BACK=0

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    would: $*"
    else
        "$@"
    fi
}

# A dry run on a machine that has not been set up yet is the normal case, so
# missing prerequisites report and keep going rather than failing the run.
missing_dep() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    note: $1"
        return 0
    fi
    echo "==> $1" >&2
    exit 1
}

# "Is the package installed" is the question actually being asked -- not "is it
# on PATH". Arch is usr-merged and greetd is /usr/bin/greetd, so a PATH check
# would work, but pacman -Qq answers the real question directly.
for pkg in greetd nwg-hello; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        missing_dep "$pkg not installed; run scripts/packages.sh first"
    fi
done

echo "==> Installing greeter (greetd + nwg-hello)"

# ---------------------------------------------------------------------------
# ASSERT: the stylesheet still matches nwg-hello's widget names.
#
# nwg-hello sets GTK CSS names in ui.py with set_property("name", ...). Those
# names -- NOT the .glade ids -- are what our #id selectors match; see the
# header of nwg-hello.css. Nothing warns when a selector matches nothing: the
# greeter renders unstyled and the config still reads as configured.
#
# This repo's CSS was written against nwg-hello 0.4.2. Arch ships 0.4.5. Check,
# do not assume.
#
# These pipes are safe without a here-string. The SIGPIPE hazard this repo has
# shipped twice is specific to consumers that exit early (grep -q, head -1);
# sort and tr read to EOF, so nothing upstream ever takes SIGPIPE.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# ASSERT: config.toml's vt matches what greetd.service keeps clear.
#
# If they disagree, greetd and a getty fight over the same VT. Upstream greetd
# conflicts with getty@tty1. This cannot be verified from anywhere but this
# machine.
#
# Here-string, not a pipe: `systemctl show | grep -Fq` under pipefail returns
# 141 when it matches.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# ASSERT: pacman will not silently overwrite our greetd config on upgrade.
#
# See the comment at the top of greeter/etc/greetd/config.toml. The whole
# reason it is safe to use the documented config.toml path -- rather than
# nwg-hello's greetd.conf workaround -- is that pacman keeps modified `backup`
# files and writes .pacnew beside them. If config.toml is not in that array,
# every greetd upgrade silently restores the agreety text greeter.
# ---------------------------------------------------------------------------
backups="$(pacman -Qii greetd 2>/dev/null | grep -i '^backup' || true)"
if [ -n "$backups" ] && ! grep -Fq 'etc/greetd/config.toml' <<<"$backups"; then
    echo "    WARNING: /etc/greetd/config.toml is not in greetd's backup array." >&2
    echo "             pacman will overwrite it on every greetd upgrade, with no" >&2
    echo "             .pacnew and no prompt -- restoring the agreety text greeter." >&2
    echo "             Escape hatch: rename it to /etc/greetd/greetd.conf, which" >&2
    echo "             greetd reads first and no package owns." >&2
    echo "             Verify with: pacman -Qii greetd" >&2
fi

# ---------------------------------------------------------------------------
# Wallpaper. `greeter` cannot read the repo under /home/baas (mode 750), so the
# image is copied somewhere world-readable. nwg-hello.css references this path.
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
# greeter that crashes on startup is a greeter you cannot log in through. This
# is the layer that absorbs an nwg-hello restructure: a form that is not
# centred beats no login.
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

# ---------------------------------------------------------------------------
# The `greeter` account. greetd's sysusers file creates it at package install
# time, so if it is missing something is badly wrong -- and the consequence is
# a black screen at boot, which is not a warning-and-continue situation.
# ---------------------------------------------------------------------------
if ! getent passwd greeter >/dev/null; then
    missing_dep "no 'greeter' user; greetd's sysusers should have created it (pacman -Ql greetd | grep sysusers)"
else
    # Here-string, not a pipe. `id -nG | tr | grep -Fxq` under `set -o
    # pipefail` returns 141 *when it matches*: grep -q exits on the first hit,
    # the upstream commands die of SIGPIPE, and pipefail propagates that. The
    # test would claim greeter is not in `video` precisely when it is, and then
    # `set -e` would kill the script on the usermod that follows. This repo has
    # shipped that bug twice already.
    #
    # Correct whether or not Arch's sysusers file already adds greeter to the
    # video group: it checks membership first.
    greeter_groups="$(id -nG greeter 2>/dev/null | tr ' ' '\n')"
    if ! grep -Fxq video <<<"$greeter_groups"; then
        echo "    adding greeter to the video group"
        run sudo usermod -aG video greeter
    else
        echo "    greeter is already in the video group"
    fi
    # nwg-hello remembers the last user and session here. If the directory is
    # missing it logs an error on every start and forgets your session choice.
    #
    # Trailing colon on chown = the user's own login group, whatever sysusers
    # decided to call it.
    run sudo mkdir -p /var/cache/nwg-hello
    run sudo chown greeter: /var/cache/nwg-hello
fi

# ---------------------------------------------------------------------------
# Prove `greeter` can actually read what it needs.
#
# A font GTK cannot find does not error -- it falls back silently. So rather than
# trust that `greeter` can see the font, ask it directly: `greeter` is the user
# that has to find it, and the only one whose view of /home/baas (750) differs
# from yours. Arch's sysusers gives greeter a real /bin/bash shell, so `sudo -u`
# just works.
# ---------------------------------------------------------------------------
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
    if ! sudo -u greeter test -r /usr/share/nwg-hello/wallpaper.jpg; then
        echo "    greeter cannot read /usr/share/nwg-hello/wallpaper.jpg" >&2
        exit 1
    fi
    echo "        wallpaper OK"
fi

# ---------------------------------------------------------------------------
# Point the system at greetd.
#
# greetd.service is WantedBy=graphical.target, so the default target has to
# reach it. On stock Arch it already does, and that was worth checking rather
# than assuming in either direction:
#
#   systemd ships /usr/lib/systemd/system/default.target -> graphical.target,
#   and Arch writes no /etc/systemd/system/default.target override, so
#   `systemctl get-default` answers graphical.target on a bare install.
#
# Measured in an Arch VM: get-default is graphical.target, `enable --force`
# creates the display-manager.service alias, and greetd shows up under
# `systemctl list-dependencies graphical.target` -- i.e. it really is on the
# boot path, not merely "enabled".
#
# So this set-default is a no-op on a stock system and stays only because it is
# free and idempotent: it fixes the case where something (a previous install,
# an installer profile) explicitly wrote multi-user.target. It is NOT, as an
# earlier draft of this file claimed, a known Arch bug -- that claim was wrong
# and is retracted rather than quietly softened.
# ---------------------------------------------------------------------------
current_target="$(systemctl get-default 2>/dev/null || true)"
if [ "$current_target" != "graphical.target" ]; then
    echo "    default target is ${current_target:-unknown} -> graphical.target"
    echo "        (greetd is WantedBy=graphical.target; without this it would be"
    echo "         'enabled' and still never start)"
    run sudo systemctl set-default graphical.target
else
    echo "    default target is already graphical.target"
fi

# `--force` is defensive rather than load-bearing: on a minimal Arch install
# nothing else claims display-manager.service, so there is no other display
# manager to take the alias from. It keeps a re-run idempotent if anything ever does.
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
