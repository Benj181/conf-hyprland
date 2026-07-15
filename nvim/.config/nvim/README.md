# conf-nvim

AstroNvim + kitty config. Inspired by [Q3rkses/nvimconf](https://github.com/Q3rkses/nvimconf).

## Backup

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
mv ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.bak 2>/dev/null
```

## Dependencies (Ubuntu)

```shell
sudo apt remove neovim -y
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim && sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-linux-x86_64 /opt/nvim
echo 'export PATH="$PATH:/opt/nvim/bin"' >> ~/.bashrc && source ~/.bashrc
sudo apt update && sudo apt install -y git ripgrep fd-find build-essential unzip nodejs npm python3 python3-pip
```

## Nerd font

```shell
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -o FiraCode.zip "*Mono*" -d FiraCodeNerdFontMono && rm FiraCode.zip && fc-cache -f
```

## Clone and link

```shell
git clone --recurse-submodules https://github.com/Benj181/conf-nvim ~/.config/nvim
mkdir -p ~/.config/kitty
ln -s ~/.config/nvim/kitty.conf ~/.config/kitty/kitty.conf
```

## Launch

```shell
nvim
```

Let lazy.nvim install plugins on first run, ignore any errors and restart once it finishes.

## Move and resize undecorated windows

`hide_window_decorations` in `kitty.conf` removes the titlebar, so moving and resizing need a modifier key instead of dragging a border. These are GNOME settings, not part of this repo, so they only need doing once per machine.

Switch the move/resize modifier to Alt, useful if your keyboard doesn't have a usable Super key:

```shell
gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier '<Alt>'
```

By default GNOME uses modifier + right-click for the window menu rather than resize. Flip that so right-click drags to resize instead:

```shell
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
```

With both set:

- Alt + left-click drag anywhere in the window: move
- Alt + right-click drag anywhere in the window: resize
- Alt + middle-click: window menu

`hide_window_decorations titlebar-only` is a macOS-only option, it does nothing on Linux, so it's not worth setting here.

## Update Catppuccin theme

```shell
cd ~/.config/nvim && git submodule update --remote themes/catppuccin
```
