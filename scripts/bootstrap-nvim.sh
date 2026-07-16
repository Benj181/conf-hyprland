#!/usr/bin/env bash
# scripts/bootstrap-nvim.sh
# Installs the Neovim plugin set headlessly.
#
# Installs the plugins up front, instead of relying on an interactive first
# launch of nvim to let lazy install them.

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

# No Mason step here, deliberately.
#
# lua/plugins/mason.lua is still the AstroNvim template stub -- its first line
# is `if true then return {} end`, so it returns an empty spec and no
# ensure_installed list exists to act on. (Same for treesitter.lua and
# none-ls.lua.) There is nothing for MasonToolsInstall to install.
#
# If you do enable mason.lua, you still do not want it here:
# +MasonToolsInstallSync never returns under --headless (its async jobs wait on
# an event loop headless nvim does not pump the same way), so it hangs the
# install rather than failing. mason-tool-installer's run_on_start already
# installs the list on the next interactive launch anyway.

echo "==> Neovim bootstrap done"
