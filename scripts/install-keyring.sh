#!/usr/bin/env bash
# scripts/install-keyring.sh
# Wires gnome-keyring into PAM so the login keyring unlocks with your login
# password instead of prompting.
#
# Edits /etc/pam.d/greetd and /etc/pam.d/login in place rather than shipping
# copies: both are in pacman's backup array, so local edits survive upgrades,
# while a vendored copy would go stale.
#
# The keyring auth line must come AFTER `auth include system-local-login`:
# it reads the password pam_unix stored there. Above it, gkr-pam logs
# "no password is available for user" and the keyring silently stays locked.
#
# The `greeter` user is skipped (pam_succeed_if): greetd's PAM service covers
# the greeter too, whose home is `/`, so it would spawn a useless daemon.
#
# /etc/pam.d/passwd is not touched, so `passwd` does not re-key the keyring;
# see README, Keyring.
#
# Keep a root shell open the first time: a broken PAM stack locks you out.
# Every original is backed up and every added line is `optional`.
#
# Usage: install-keyring.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

BACKUP_DIR="/etc/pam.d/backup-$(date +%Y%m%d-%H%M%S)"

# Set when a PAM file is actually rewritten.
CHANGED=0

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

echo "==> Installing keyring (gnome-keyring + PAM)"

for pkg in gnome-keyring; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        missing_dep "$pkg not installed; run scripts/packages.sh first"
    fi
done

# ASSERT: the referenced PAM modules exist (a missing one fails silently).
for mod in pam_gnome_keyring.so pam_succeed_if.so; do
    if [ ! -f "/usr/lib/security/$mod" ]; then
        missing_dep "/usr/lib/security/$mod missing; the PAM edits would silently do nothing"
    fi
done
echo "    PAM modules present"

# ASSERT: both files are in their package's backup array, or an upgrade
# silently reverts these edits.
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

# Render a corrected PAM file to stdout. Existing keyring lines are dropped and
# re-inserted after `include system-local-login` (where pam_unix runs), so
# re-runs are idempotent and misplaced lines get fixed. awk exits 3 if the
# anchor is missing.
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

    # Show the diff so a bad edit can be caught.
    echo "    $path:"
    diff -u "$path" "$tmp" | sed -n '3,$p' | sed 's/^/        /' || true

    echo "        backing up -> $BACKUP_DIR/$(basename "$path")"
    run sudo mkdir -p "$BACKUP_DIR"
    run sudo cp -a "$path" "$BACKUP_DIR/"
    run sudo install -m 644 -o root -g root "$tmp" "$path"
    rm -f "$tmp"
    CHANGED=1
}

install_pam /etc/pam.d/greetd 1
install_pam /etc/pam.d/login  0

# The keyring directory must exist. The daemon only creates it at startup and
# survives logouts (KillUserProcesses=no), and if it is missing gkr-pam
# misreports the failure as "the password for the login keyring was invalid".
KEYRING_DIR="$HOME/.local/share/keyrings"
if [ ! -d "$KEYRING_DIR" ]; then
    echo "    creating $KEYRING_DIR (0700)"
    run mkdir -p -m 700 "$KEYRING_DIR"
else
    echo "    $KEYRING_DIR exists"
fi

# gkr-pam only unlocks the keyring named `login`. If secrets live in another
# default keyring (e.g. an auto-created Default_Keyring), report it. Never
# move or delete keyrings automatically: they hold your passwords.
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

    Move the CONTENTS and leave the directory itself in place: the running
    daemon only creates it at startup, and without it the next login fails
    with a misleading "invalid password".

    Then REBOOT rather than logging out. A logout leaves the old daemon running
    (KillUserProcesses=no), and it is the one that would handle the next login.
EOF
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: nothing was written"
    exit 0
fi

# Ask the Secret Service for the keyring's actual state and print only the
# next step.
keyring_state() {
    [ -f "$KEYRING_DIR/login.keyring" ] || { echo missing; return 0; }
    python3 - <<'PY' 2>/dev/null || echo unknown
import sys
import gi
gi.require_version("Secret", "1")
from gi.repository import Secret, GLib

try:
    svc = Secret.Service.get_sync(Secret.ServiceFlags.LOAD_COLLECTIONS)
except GLib.Error as err:
    # The keyring was created after this daemon scanned for keyrings; only a
    # fresh daemon exposes it.
    print("unexposed" if "No such secret collection" in err.message else "unknown")
    sys.exit(0)

for c in svc.get_collections():
    if c.get_object_path().endswith("/collection/login"):
        print("locked" if c.get_locked() else "ok")
        sys.exit(0)
print("unexposed")
PY
}

echo
case "$(keyring_state)" in
    ok)
        if [ "$CHANGED" -eq 1 ]; then
            echo "==> PAM updated. Log out and back in to apply it."
        else
            echo "==> Nothing to do: the login keyring is unlocked and working."
        fi
        ;;
    missing)
        echo "==> Log in twice. The first login creates the login keyring; the"
        echo "    second is when apps can see it. See README, Keyring."
        ;;
    unexposed)
        echo "==> Log in once more. The login keyring is fine, but this session's"
        echo "    daemon started before it existed, so apps cannot see it yet."
        ;;
    locked)
        echo "==> Log out and back in: the login keyring is locked."
        ;;
    *)
        echo "==> Log out and back in, then re-run this to confirm."
        ;;
esac

if [ "$CHANGED" -eq 1 ]; then
    echo "    Previous /etc/pam.d files: $BACKUP_DIR"
fi
