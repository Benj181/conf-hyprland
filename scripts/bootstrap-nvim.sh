#!/usr/bin/env bash
# scripts/bootstrap-nvim.sh
# Installs the Neovim plugin set headlessly.
#
# Replaces conf-nvim's README step of "launch nvim, let lazy install plugins,
# ignore any errors and restart once it finishes".

set -euo pipefail

NVIM="${NVIM_BIN:-nvim}"
command -v "$NVIM" >/dev/null || { echo "nvim not found; run install-neovim.sh first" >&2; exit 1; }

[ -f "$HOME/.config/nvim/init.lua" ] || {
    echo "~/.config/nvim/init.lua missing -- stow the nvim package first" >&2
    exit 1
}

echo "==> Syncing lazy.nvim plugins (headless, first run takes a minute)"
"$NVIM" --headless "+Lazy! sync" +qa 2>&1 | sed 's/^/    /' || {
    echo "    lazy sync reported errors; continuing (plugins often still install)" >&2
}

# Mason tools, only if mason-tool-installer is actually configured -- calling a
# command that does not exist would fail the whole install.
if "$NVIM" --headless -c 'lua if pcall(require, "mason-tool-installer") then vim.cmd("qa") else vim.cmd("cq") end' 2>/dev/null; then
    echo "==> Installing Mason tools"
    "$NVIM" --headless "+MasonToolsInstallSync" +qa 2>&1 | sed 's/^/    /' || true
fi

echo "==> Neovim bootstrap done"
