# hyprland-dotfiles

Hyprland setup for **europa**, reproducible with one command. Catppuccin Mocha
across Hyprland, Waybar, Rofi, mako, kitty, Neovim, GTK and Qt.

## Install

```bash
git clone git@github.com:Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
./install.sh
```

That's the whole thing — apt packages, NVIDIA driver, Neovim, Nerd Fonts,
theming, and every config symlinked into place with GNU Stow. Then log out and
pick Hyprland at the display manager. Reboot first if the NVIDIA driver was
installed or upgraded.

```bash
./install.sh --dry-run        # report what would change, write nothing
./install.sh --skip-packages  # configs only, skips apt/fonts/nvim/themes
```

Anything already in the way (say, a config from a previous setup) is moved to
`~/.dotfiles-backup-<timestamp>/` rather than overwritten.

## Structure

Each top-level directory is a stow package: its contents mirror `$HOME`, so
`hypr/.config/hypr/general.conf` is symlinked to `~/.config/hypr/general.conf`.

```
.
├── install.sh          # the only command you need
├── scripts/            # install steps, each idempotent and re-runnable
├── hypr/               # compositor: entry point + modules
├── waybar/             # status bar
├── rofi/               # launcher, power menu (+ vendored Catppuccin palette)
├── mako/               # notifications
├── kitty/              # terminal (+ vendored Catppuccin theme)
├── nvim/               # AstroNvim config
├── hyprlock/           # lock screen
├── hypridle/           # idle handling
├── theme/              # GTK3/GTK4/Qt colours
└── wallpapers/         # referenced by absolute path, not stowed
```

`hypr/.config/hypr/hyprland.conf` is an entry point that only `source`s the
modules beside it. **`hardware.conf` holds everything specific to this
machine** — monitors and NVIDIA env. If a second machine ever appears, that's
the one file that needs to differ.

`hyprlock` and `hypridle` are separate packages that both install into
`~/.config/hypr/`, which the `hypr` package also owns. Stow handles this by
unfolding the directory into per-file symlinks. It's expected; just don't be
surprised that `~/.config/hypr` is a real directory rather than a single link.

## Keybinds

`$mod` is SUPER.

| Bind | Action |
|---|---|
| `$mod` + Return | kitty |
| `$mod` + R | rofi |
| `$mod` + E | nautilus |
| `$mod` + Q | close window |
| `$mod` + F | fullscreen |
| `$mod` + V | toggle floating |
| `$mod` + C | clipboard history |
| `$mod` + N / `$mod`+Shift+N | dismiss / restore notification |
| `$mod` + Shift + X | power menu |
| `$mod` + h/j/k/l | move focus |
| `$mod` + Shift + h/j/k/l | move window |
| `$mod` + 1-0 | workspace |
| `$mod` + Shift + 1-0 | move window to workspace |
| Print / `$mod` + Print | screenshot output / region |

## Theming

Everything is Catppuccin **Mocha**, and themes are vendored rather than pulled
from distro paths or third-party repos at install time:

- **Rofi** — the palette lives in `rofi/.config/rofi/catppuccin-mocha.rasi`
  and the layouts (`config.rasi` for the launcher, `powermenu.rasi` for the
  power menu) are ours. Do *not* point `@theme` at `/usr/share/rofi/themes/`;
  Ubuntu's rofi ships no Catppuccin, so that silently falls back to the stock
  theme. Note both layouts style **every** element state explicitly — rofi
  loads its built-in default theme first, which sets a Solarized-light
  background on `element normal.normal`, so any state left unstyled renders
  cream on the dark theme.
- **Power menu** — `rofi/.config/rofi/powermenu.sh`, not wlogout. This is what
  hyprsimple actually does (its `custom/power` calls a rofi script; the wlogout
  config in that repo is vestigial), and it's why the menu is a small centred
  panel rather than a fullscreen overlay. It reuses the same palette as the
  launcher, so the two match by construction.
- **kitty** — `kitty/.config/kitty/mocha.conf`, included relatively.
- **GTK4/libadwaita** — apps like Nautilus ignore `gtk-theme-name` entirely, so
  `theme/.config/gtk-4.0/gtk.css` overrides libadwaita's named colours instead.
  This is also why nothing is downloaded: `catppuccin/gtk` was archived in June
  2024 and wouldn't have helped here anyway.
- **Qt** — qt6ct with a Fusion palette; `QT_QPA_PLATFORMTHEME` is set in
  `general.conf`.
- **Wallpaper** — `hyprpaper.conf` uses **hyprpaper ≥ 0.8 block syntax**
  (`wallpaper { monitor = ... path = ... }`). The older flat form
  (`preload = ...` / `wallpaper = DP-3,...`) that most guides still show is
  *silently ignored* by 0.8 — no error, just no wallpaper. Paths must be
  absolute; `~` and `$HOME` are not expanded. If the wallpaper ever vanishes,
  run `hyprpaper --verbose` (it logs nothing without it) and look for
  "has no target".

### Fonts

Configs ask for **`FiraCode Nerd Font`** (UI) and **`FiraCode Nerd Font Mono`**
(terminal/editor). Both names must match `fc-list : family` exactly or the app
silently falls back and icons render as tofu boxes.

- `fonts-firacode` from apt provides **"Fira Code"** — no Nerd glyphs. It is
  not a substitute and is deliberately not installed.

## Neovim

`install.sh` installs Neovim and syncs plugins headlessly.

Neovim comes from the **upstream tarball**, pinned, into `/opt/nvim` and
symlinked to `/usr/local/bin/nvim` — apt only has 0.11.6, which is older than
this config targets. If `nvim --version` disagrees with
`scripts/install-neovim.sh`, an apt-installed `neovim` is probably shadowing it.

## Hardware notes (europa)

RTX 5070 Ti (Blackwell), driver 595 open modules, two LG UltraGears at
2560x1440@180 with DP-2 rotated to portrait.

- **Blackwell is open-kernel-module only.** `nvidia-driver-595-open` is named
  outright in `scripts/packages.sh`; there is no proprietary variant to choose.
- **`nvidia-drm.modeset=1` is not needed.** It's default-on for this driver —
  there is no such kernel parameter set here and no
  `/sys/module/nvidia_drm/parameters/modeset` knob, and Hyprland runs fine.
  Ignore older guides insisting on it.
- **VRR is off on purpose.** Setting `__GL_VRR_ALLOWED` alone does nothing
  (`hyprctl monitors` will still say `vrr: false`); it needs Hyprland's own
  `vrr` setting, and VRR across multiple NVIDIA displays is flicker-prone.
- **No battery and no backlight**, so there are no battery/brightness modules
  or binds. External monitor brightness needs DDC/CI (`ddcutil`) if you want it.
- **Mouse acceleration is off** via `accel_profile = flat` in `general.conf`.

## Uninstall

```bash
cd ~/hyprland-dotfiles
stow -D -t "$HOME" hypr waybar rofi mako kitty nvim hyprlock hypridle theme
```
