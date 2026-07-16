#!/usr/bin/env bash
# scripts/preflight.sh
# Moves anything that would collide with stow out of the way.
#
# stow refuses to overwrite existing files and reports it in a way that is hard
# to act on. Typical collisions are a pre-existing ~/.config/nvim directory from
# an earlier setup, or a hand-made ~/.config/kitty/kitty.conf symlink.
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

        # Already one of ours -- stow will handle it. Resolve the *whole* path
        # and compare, with no symlink precondition.
        #
        # This previously guarded the check with `[ -L "$target" ] || [ -L
        # "$(dirname "$target")" ]`, which only noticed a symlink at the
        # immediate parent. When stow folds a package into a single directory
        # symlink (~/.config/nvim -> repo), files directly inside it were
        # correctly skipped, but anything one level deeper (lua/plugins/*.lua)
        # has a real directory as its parent and slipped through -- so this
        # script moved files *through* the symlink and out of the repo.
        # readlink -f resolves every component, so an ancestor symlink at any
        # depth is caught.
        resolved="$(readlink -f "$target" 2>/dev/null || true)"
        case "$resolved" in
            "$DOTFILES_DIR"/*) continue ;;
        esac

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

# A pre-existing ~/.config/nvim directory from an earlier setup is stale once the
# nvim package is stowed, but only remove it if nothing of value is left behind.
if [ -d "$HOME/.config/nvim" ] && [ -z "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    rmdir "$HOME/.config/nvim"
fi

echo "==> Preflight done. Backup: $BACKUP_DIR"
