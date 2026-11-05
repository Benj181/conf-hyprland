#!/usr/bin/env bash
# scripts/bootstrap-nvim.sh
# Installs the Neovim plugin set headlessly.

set -euo pipefail

NVIM="${NVIM_BIN:-nvim}"
command -v "$NVIM" >/dev/null || { echo "nvim not found; run scripts/packages.sh first" >&2; exit 1; }

[ -f "$HOME/.config/nvim/init.lua" ] || {
    echo "~/.config/nvim/init.lua missing -- stow the nvim package first" >&2
    exit 1
}

echo "==> Syncing lazy.nvim plugins (headless, first run takes a minute)"
"$NVIM" --headless "+Lazy! sync" +qa 2>&1 | sed 's/^/    /' || {
    echo "    lazy sync reported errors; continuing (plugins often still install)" >&2
}

# No Mason step: +MasonToolsInstallSync hangs under --headless, and
# mason-tool-installer installs its list on the next interactive launch.

echo "==> Neovim bootstrap done"
