# conf-nvim

Personal AstroNvim configuration, bundled with a matching kitty terminal setup. 
This is for AstroNvim v6+. See [AstroNvim](https://github.com/AstroNvim/AstroNvim) for the base distribution.

## Requirements

- [Neovim 0.10+](https://github.com/neovim/neovim/releases) (not nightly)
- [Nerd Font](https://www.nerdfonts.com/font-downloads) for icons
- [git](https://git-scm.com/)
- [ripgrep](https://github.com/BurntSushi/ripgrep), used for live grep in Telescope (`<leader>fw`)
- A C compiler (`build-essential` on Ubuntu), required by Treesitter
- [Tree-sitter CLI](https://github.com/tree-sitter/tree-sitter), only needed for the `auto_install` Treesitter feature
- A clipboard tool for system clipboard integration, see `:help clipboard-tool` (for example `wl-clipboard` on Wayland, `xclip` or `xsel` on X11)
- A terminal with true color support
- [kitty](https://sw.kovidgoyal.net/kitty/), optional, only needed to use the bundled terminal config

Optional extras used by some AstroCommunity or Mason tools:

- [lazygit](https://github.com/jesseduffield/lazygit), git TUI (`<leader>tl` or `<leader>gg`)
- [Node.js](https://nodejs.org/) and [Python](https://www.python.org/), used for REPL toggle terminals and LSP servers installed via Mason

## Installation

### 1. Back up your current Neovim config

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

### 2. Install dependencies (Ubuntu)

Ubuntu's repositories usually ship an old Neovim version, so install it from the official release tarball instead of `apt`:

```shell
sudo apt remove neovim -y  # if previously installed via apt
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-linux-x86_64 /opt/nvim
echo 'export PATH="$PATH:/opt/nvim/bin"' >> ~/.bashrc
source ~/.bashrc
nvim --version
```

The rest of the dependencies are fine from `apt`:

```shell
sudo apt update
sudo apt install -y git ripgrep fd-find build-essential unzip nodejs npm python3 python3-pip
```

Note: Ubuntu packages the `fd` binary as `fdfind`. To use the `fd` command as-is, symlink it:

```shell
mkdir -p ~/.local/bin && ln -s $(which fdfind) ~/.local/bin/fd
```

Tree-sitter CLI (only if you want `auto_install` for Treesitter parsers):

```shell
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
cargo install tree-sitter-cli
```

### 3. Install a Nerd Font

Example using JetBrainsMono. Pick any font you like from [nerdfonts.com](https://www.nerdfonts.com/font-downloads):

```shell
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip -d JetBrainsMono && rm JetBrainsMono.zip && fc-cache -f
```

### 4. Clone this repository into your Neovim config directory

```shell
git clone https://github.com/Benj181/conf-nvim ~/.config/nvim
```

### 5. Start Neovim

```shell
nvim
```

On first launch, `init.lua` bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim), which then installs AstroNvim and all configured plugins. Ignore any errors on this first run and restart Neovim once it finishes.

### 6. Install language servers, formatters, and linters via Mason

Inside Neovim:

```vim
:Mason
```

Or install specific tools directly:

```vim
:MasonInstall lua-language-server stylua
```

Note: the files `lua/plugins/mason.lua`, `lua/community.lua`, and `lua/plugins/user.lua` currently start with `if true then return {} end`, which keeps their example content disabled. Remove that line and trim the parts you do not need once you are ready to customize the `ensure_installed` tools, AstroCommunity packs, or extra plugins.

## Kitty terminal setup (optional)

This repository includes a `conf-kitty/` folder with `kitty.conf` and `theme.conf`.

Back up your existing kitty config:

```shell
mv ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.bak 2>/dev/null
mv ~/.config/kitty/theme.conf ~/.config/kitty/theme.conf.bak 2>/dev/null
```

Symlink the bundled config in:

```shell
mkdir -p ~/.config/kitty
ln -s ~/.config/nvim/conf-kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -s ~/.config/nvim/conf-kitty/theme.conf ~/.config/kitty/theme.conf
```

Restart kitty, or reload with `ctrl+shift+F5`, to apply the changes.

## Structure

```
.
├── init.lua                # Bootstraps lazy.nvim, loads lazy_setup and polish
├── lua/
│   ├── lazy_setup.lua       # Registers AstroNvim core, community packs, and user plugins
│   ├── community.lua        # AstroCommunity plugin packs (disabled by default)
│   ├── polish.lua           # Final tweaks applied after all plugins load
│   └── plugins/
│       ├── astrocore.lua    # Core options, mappings, autocommands
│       ├── astrolsp.lua     # LSP configuration
│       ├── astroui.lua      # UI/theme configuration
│       ├── mason.lua        # Mason tool auto-install list (disabled by default)
│       ├── none-ls.lua      # Formatters/linters via null-ls/none-ls
│       ├── treesitter.lua   # Treesitter parser configuration
│       └── user.lua         # Personal plugin additions/overrides (disabled by default)
└── conf-kitty/
    ├── kitty.conf
    └── theme.conf
```
