#!/usr/bin/env bash
# scripts/install-keyring.sh
# Wires gnome-keyring into PAM so the login keyring unlocks with your login
# password instead of prompting.
#
# WHY THIS IS A SCRIPT AND NOT A CONFIG FILE IN THIS REPO
#
# /etc/pam.d/greetd and /etc/pam.d/login belong to the greetd and util-linux
# packages. Both are in pacman's `backup` array (verified below), so pacman
# keeps local modifications and drops a .pacnew beside them rather than
# overwriting. That is exactly what makes editing them safe -- and also why this
# repo must NOT ship whole replacement copies of them, the way it does for
# greeter/etc/nwg-hello/. A vendored copy would freeze whatever upstream shipped
# on the day it was copied, and silently keep re-installing that stale version
# over every future util-linux update. So: surgical, idempotent edits.
#
# WHY THE ORDER OF THE auth LINE IS THE WHOLE BALLGAME
#
# pam_gnome_keyring's auth module does not prompt for anything. It reads the
# password out of PAM_AUTHTOK, which is set by the module that DID prompt --
# pam_unix, inside `auth include system-local-login`. Put the keyring line
# ABOVE that include and PAM_AUTHTOK is still empty when it runs.
#
# It does not fail. gkr-pam logs "no password is available for user" and returns
# PAM_SUCCESS, because it is `optional`. Login succeeds, the daemon starts, and
# the keyring is simply never unlocked -- so every app that wants a secret
# prompts you, and nothing anywhere says why. That was the state of this machine
# before this script existed; the journal said:
#
#     greetd[1104]: gkr-pam: no password is available for user
#     greetd[1104]: gkr-pam: couldn't unlock the login keyring.
#
# The line therefore goes AFTER the include, and this script places it rather
# than trusting that a hand edit put it in the right place.
#
# WHY THE GREETER IS EXCLUDED
#
# greetd uses the PAM service `greetd` for BOTH the greeter and the session it
# launches, so `auto_start` fires for the `greeter` system user too. greeter's
# home is `/` (see `getent passwd greeter`), so it spawns a keyring daemon that
# cannot write anything and logs, four times, every boot:
#
#     gnome-keyring-daemon[815]: unable to create keyring dir: /.local/share/keyrings
#
# pam_succeed_if skips the keyring line for that one user. Harmless either way,
# but a log that is noisy by design is a log nobody reads when it matters.
#
# WHAT THIS DOES NOT DO
#
# It does not touch /etc/pam.d/passwd. That means `passwd` changes your login
# password WITHOUT re-keying the keyring, and auto-unlock then silently stops
# working until you fix it in seahorse. The fix is one line -- see README,
# Keyring -- and it is left out only because it is a third PAM file nobody asked
# for.
#
# NEVER EDIT /etc/pam.d BY HAND WHILE LOGGED OUT. A broken PAM stack is a
# machine you cannot log into. Every original is backed up (path printed below)
# and every line added here is `optional`, which cannot deny an auth it does not
# understand -- but keep a root shell open the first time anyway.
#
# Usage: install-keyring.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

BACKUP_DIR="/etc/pam.d/backup-$(date +%Y%m%d-%H%M%S)"

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

echo "==> Installing keyring (gnome-keyring + PAM)"

for pkg in gnome-keyring; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        missing_dep "$pkg not installed; run scripts/packages.sh first"
    fi
done

# ---------------------------------------------------------------------------
# ASSERT: the PAM modules these files are about to reference exist.
#
# PAM resolves modules at auth time, not at edit time. A line naming a module
# that is not there costs a log message per login and nothing else -- which is
# to say it looks exactly like everything working.
# ---------------------------------------------------------------------------
for mod in pam_gnome_keyring.so pam_succeed_if.so; do
    if [ ! -f "/usr/lib/security/$mod" ]; then
        missing_dep "/usr/lib/security/$mod missing; the PAM edits would silently do nothing"
    fi
done
echo "    PAM modules present"

# ---------------------------------------------------------------------------
# ASSERT: pacman will not silently revert these edits on upgrade.
#
# Same reasoning as the greetd config.toml check in install-greeter.sh. If a
# file is not in its package's `backup` array, pacman overwrites it on every
# upgrade with no .pacnew and no prompt -- so auto-unlock would break on a
# random future -Syu, months from now, with nothing connecting cause to effect.
# ---------------------------------------------------------------------------
check_backup_array() {
    local pkg="$1" path="$2" backups
    backups="$(pacman -Qii "$pkg" 2>/dev/null | grep -i '^backup' -A20 || true)"
    if [ -n "$backups" ] && ! grep -Fq "${path#/}" <<<"$backups"; then
        echo "    WARNING: $path is not in $pkg's backup array." >&2
        echo "             pacman will overwrite it on every $pkg upgrade, with no" >&2
        echo "             .pacnew and no prompt, silently undoing these edits." >&2
        echo "             Verify with: pacman -Qii $pkg" >&2
    fi
}
check_backup_array greetd     /etc/pam.d/greetd
check_backup_array util-linux /etc/pam.d/login
echo "    pacman keeps local edits to both files (backup array)"

# ---------------------------------------------------------------------------
# Render a corrected PAM file to stdout.
#
# Every pam_gnome_keyring line is DROPPED first and then re-inserted at the
# anchor. That is what makes this both idempotent and self-healing: a re-run
# rewrites rather than appends, and a hand-placed line in the wrong position --
# the exact bug this script exists to fix -- is removed rather than left sitting
# above the correct one, where it would keep logging "no password is available".
#
# Anchoring on `include system-local-login` rather than "the last auth line" is
# deliberate: it is the line that runs pam_unix, and pam_unix is what sets the
# PAM_AUTHTOK the keyring module reads. If Arch ever restructures these files
# the anchor vanishes, and awk exits 3 rather than writing a file whose
# behaviour nobody has thought about.
# ---------------------------------------------------------------------------
render_pam() {
    local file="$1" is_greetd="$2"
    awk -v greetd="$is_greetd" '
        /pam_gnome_keyring\.so/                 { next }
        /pam_succeed_if\.so user = greeter/     { next }
        { print }
        /^auth[[:space:]]+include[[:space:]]+system-local-login/ {
            print "auth       optional     pam_gnome_keyring.so"
            seen_auth = 1
        }
        /^session[[:space:]]+include[[:space:]]+system-local-login/ {
            if (greetd == 1)
                print "session    [success=1 default=ignore] pam_succeed_if.so user = greeter quiet"
            print "session    optional     pam_gnome_keyring.so auto_start"
            seen_session = 1
        }
        END { if (!seen_auth || !seen_session) exit 3 }
    ' "$file"
}

install_pam() {
    local path="$1" is_greetd="$2" new tmp

    if [ ! -f "$path" ]; then
        missing_dep "$path does not exist"
        return 0
    fi

    if ! new="$(render_pam "$path" "$is_greetd")"; then
        echo "    $path has no 'include system-local-login' anchor." >&2
        echo "    This script does not know where pam_unix runs in it, and will not" >&2
        echo "    guess -- a misplaced keyring line fails silently forever." >&2
        echo "    Inspect it and place the lines by hand; see this script's header." >&2
        exit 1
    fi

    tmp="$(mktemp)"
    printf '%s\n' "$new" >"$tmp"

    if cmp -s "$tmp" "$path"; then
        echo "    $path already correct"
        rm -f "$tmp"
        return 0
    fi

    # Show the change rather than announcing one. These are the files that
    # decide whether you can log in; "modified /etc/pam.d/login" is not enough
    # to review, and this is the last moment anyone can catch a bad edit.
    echo "    $path:"
    diff -u "$path" "$tmp" | sed -n '3,$p' | sed 's/^/        /' || true

    echo "        backing up -> $BACKUP_DIR/$(basename "$path")"
    run sudo mkdir -p "$BACKUP_DIR"
    run sudo cp -a "$path" "$BACKUP_DIR/"
    run sudo install -m 644 -o root -g root "$tmp" "$path"
    rm -f "$tmp"
}

install_pam /etc/pam.d/greetd 1
install_pam /etc/pam.d/login  0

# ---------------------------------------------------------------------------
# The keyring directory must EXIST, or PAM reports a wrong password.
#
# gnome-keyring creates ~/.local/share/keyrings when the daemon starts, and
# never again. The daemon then outlives your session -- logind's
# KillUserProcesses defaults to no on Arch, and the socket-activated
# gnome-keyring-daemon.service lives under user@1000.service, which survives a
# logout. So a daemon started hours ago is the one that handles your next
# login, and if the directory went away in the meantime it will not be
# recreated.
#
# What that costs is not obvious, so here it is verbatim from this machine.
# gkr-pam had the correct password and asked the daemon to make a login keyring:
#
#   gnome-keyring-daemon[1149]: couldn't write to file:
#       /home/baas/.local/share/keyrings/login.keyring: No such file or directory
#   gnome-keyring-daemon[1149]: couldn't create login keyring: An error occurred
#       on the device
#   greetd[26351]: gkr-pam: the password for the login keyring was invalid.
#
# The password was fine. gkr-pam collapses every failure of the unlock control
# op into "the password ... was invalid", which is the single most misleading
# message in this whole stack -- it sends you back to re-check the PAM config
# that was already correct. Creating the directory is free, so do it rather
# than leave that trap armed.
# ---------------------------------------------------------------------------
KEYRING_DIR="$HOME/.local/share/keyrings"
if [ ! -d "$KEYRING_DIR" ]; then
    echo "    creating $KEYRING_DIR (0700)"
    run mkdir -p -m 700 "$KEYRING_DIR"
else
    echo "    $KEYRING_DIR exists"
fi

# ---------------------------------------------------------------------------
# Report -- do not touch -- a keyring that PAM will never unlock.
#
# gkr-pam only ever unlocks the keyring literally named `login`. If the default
# keyring is called something else, every app stores its secrets in the one
# keyring auto-unlock does not apply to, and you get prompted forever while the
# PAM config above is completely correct. gnome-keyring creates a
# "Default_Keyring" like that on its own the first time an app asks for a secret
# and no login keyring exists -- which is precisely what a broken auth line
# leads to. So the mess this fixes tends to leave that behind as a souvenir.
#
# This only reports. Those files are your passwords: a script that quietly
# deletes or moves them because it inferred they are stale is not a trade this
# repo makes.
# ---------------------------------------------------------------------------
if [ ! -f "$KEYRING_DIR/login.keyring" ] && compgen -G "$KEYRING_DIR/*.keyring" >/dev/null; then
    default_name="$(cat "$KEYRING_DIR/default" 2>/dev/null || echo "<unset>")"
    cat >&2 <<EOF

    NOTE: $KEYRING_DIR has keyrings but no login.keyring,
    and the default keyring is "$default_name".

    PAM only unlocks the keyring named 'login'. Until one exists, the config
    just written is correct and you will still be prompted, because your
    secrets live in a keyring it does not apply to.

    A login keyring is created at your next login, but only if nothing else is
    claiming the default. To hand it over -- this is your stored passwords, so
    read it before running it:

        ls $KEYRING_DIR                      # what you would be setting aside
        mkdir -p ~/keyrings-backup
        mv $KEYRING_DIR/* ~/keyrings-backup/

    Move the CONTENTS, and leave the directory itself in place. Moving the
    directory is what an earlier version of this note told you to do, and it is
    a trap: the running daemon only creates that directory at startup, so the
    next login cannot write login.keyring into a directory that is gone, and
    gkr-pam reports the failure as an invalid password. See above.

    Then REBOOT rather than logging out. A logout leaves the old daemon running
    (KillUserProcesses=no), and it is the one that would handle the next login.
EOF
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: nothing was written"
    exit 0
fi

cat <<EOF

    Keyring wired into PAM. REBOOT to apply it -- not a logout.

    A logout does not end the keyring daemon: logind's KillUserProcesses is no
    on Arch, and the daemon lives under user@1000.service, which outlives the
    session. So logging back in hands your password to the same daemon that was
    already running, in whatever state it was already in. That is not a
    theoretical concern -- it is why the first attempt at this on europa failed.

    Verify after the reboot. Both should be silent:

        journalctl -b | grep gkr-pam
        ls ~/.local/share/keyrings/login.keyring

    THE FIRST LOGIN IS THE ODD ONE OUT. If there was no login keyring before,
    PAM creates it during that login -- and the daemon only exposes collections
    it found when it STARTED, which was moments earlier, when there was nothing
    to find. So in that one session the keyring exists on disk and is unlocked,
    the alias resolves, and apps still cannot see it:

        No such secret collection at path: /org/freedesktop/secrets/collection/login

    An app that asks for a secret then offers to create a keyring, which looks
    exactly like none of this worked. It is not broken and nothing needs fixing:
    the next daemon start picks the keyring up. Log in once more, or:

        systemctl --user restart gnome-keyring-daemon.service   # then log in again

    Check which state you are in -- Login should be present and locked=False:

        python3 -c 'import gi; gi.require_version("Secret","1")
        from gi.repository import Secret
        s = Secret.Service.get_sync(Secret.ServiceFlags.LOAD_COLLECTIONS)
        [print(c.get_label(), "locked=%s" % c.get_locked()) for c in s.get_collections()]'

    If gkr-pam says something, read these two before believing it:

      "no password is available for user"
          The auth line is not seeing PAM_AUTHTOK -- it is above
          'auth include system-local-login' rather than below it. This script
          places it; a warning here means something else moved it back.

      "the password for the login keyring was invalid"
          Probably NOT the password. gkr-pam reports every unlock failure this
          way, including "I could not write the file". Ask the daemon instead,
          which says what actually happened:
              journalctl -b -t gnome-keyring-daemon

    Originals are in $BACKUP_DIR if you need to back out.
EOF
