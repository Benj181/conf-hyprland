#!/usr/bin/env bash
# scripts/install-zsh.sh
# Makes zsh the login shell. Idempotent: a no-op once it already is.
#
# Usage: install-zsh.sh [dry_run:0|1]

set -euo pipefail

DRY_RUN="${1:-0}"

ZSH_PATH="$(command -v zsh || true)"
if [ -z "$ZSH_PATH" ]; then
    # In a dry run, report and continue.
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    note: zsh not installed yet (packages.sh adds it); skipping chsh check"
        exit 0
    fi
    echo "==> zsh not installed; run scripts/packages.sh first" >&2
    exit 1
fi

current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" = "$ZSH_PATH" ]; then
    echo "==> Login shell already zsh"
    exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: would set login shell to $ZSH_PATH (currently $current_shell)"
    exit 0
fi

echo "==> Setting login shell to $ZSH_PATH"
chsh -s "$ZSH_PATH"
echo "    Takes effect on next login."
