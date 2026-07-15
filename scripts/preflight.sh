#!/usr/bin/env bash
# scripts/preflight.sh
# Moves anything that would collide with stow out of the way.
#
# stow refuses to overwrite existing files and reports it in a way that is hard
# to act on. The known collisions on a machine that predates this repo are
# ~/.config/nvim (conf-nvim cloned directly) and ~/.config/kitty/kitty.conf (a
# hand-made symlink into it).
#
# Deliberately not `stow --adopt`: adopt pulls stray files *into* the repo and
# overwrites the committed versions with them. That is the opposite of what is
# wanted here -- the stray kitty.conf symlink is exactly what we're removing.
#
# Usage: preflight.sh <dotfiles_dir> <dry_run:0|1> <package>...

set -euo pipefail

DOTFILES_DIR="$1"; shift
DRY_RUN="$1"; shift
PACKAGES=("$@")

BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
conflicts=()

for pkg in "${PACKAGES[@]}"; do
    [ -d "$DOTFILES_DIR/$pkg" ] || continue
    while IFS= read -r -d '' src; do
        rel="${src#"$DOTFILES_DIR/$pkg/"}"
        target="$HOME/$rel"

        # Nothing there: no conflict.
        [ -e "$target" ] || [ -L "$target" ] || continue

        # Already one of ours (possibly via a folded parent directory symlink):
        # stow will handle it.
        if [ -L "$target" ] || [ -L "$(dirname "$target")" ]; then
            resolved="$(readlink -f "$target" 2>/dev/null || true)"
            case "$resolved" in
                "$DOTFILES_DIR"/*) continue ;;
            esac
        fi

        conflicts+=("$target")
    done < <(find "$DOTFILES_DIR/$pkg" \( -type f -o -type l \) -print0)
done

if [ "${#conflicts[@]}" -eq 0 ]; then
    echo "==> Preflight: no conflicts"
    exit 0
fi

echo "==> Preflight: ${#conflicts[@]} path(s) would collide with stow:"
for c in "${conflicts[@]}"; do
    if [ -L "$c" ]; then
        echo "    $c -> $(readlink "$c")"
    else
        echo "    $c"
    fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: would move the above to $BACKUP_DIR"
    exit 0
fi

echo "==> Moving them to $BACKUP_DIR"
for c in "${conflicts[@]}"; do
    dest="$BACKUP_DIR/${c#"$HOME/"}"
    mkdir -p "$(dirname "$dest")"
    mv "$c" "$dest"
done

# ~/.config/nvim is a git clone of conf-nvim, now absorbed into this repo. Its
# whole directory is stale once the nvim package is stowed, but only move it if
# nothing of value is left behind.
if [ -d "$HOME/.config/nvim" ] && [ -z "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    rmdir "$HOME/.config/nvim"
fi

echo "==> Preflight done. Backup: $BACKUP_DIR"
