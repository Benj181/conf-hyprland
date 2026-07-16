<h3 align="center">
	Hyprland — Catppuccin Mocha
</h3>

<p align="center">
	A complete, reproducible Hyprland rice for Arch Linux.<br/>
	One clone, one command.
</p>

<p align="center">
	<img src="https://img.shields.io/badge/Hyprland-0.53-cba6f7?style=for-the-badge&labelColor=1e1e2e&logo=hyprland&logoColor=cba6f7"/>
	<img src="https://img.shields.io/badge/Arch-Linux-89b4fa?style=for-the-badge&labelColor=1e1e2e&logo=archlinux&logoColor=89b4fa"/>
	<img src="https://img.shields.io/badge/Catppuccin-Mocha-f5c2e7?style=for-the-badge&labelColor=1e1e2e"/>
	<img src="https://img.shields.io/badge/GNU-Stow-a6e3a1?style=for-the-badge&labelColor=1e1e2e&logo=gnu&logoColor=a6e3a1"/>
</p>

<p align="center">
	<img src="assets/02-tiling.png" width="100%"/>
</p>

## Previews

<details>
<summary>🖥️ &nbsp;Desktop</summary>
<img src="assets/01-desktop.png" width="100%"/>
</details>

<details>
<summary>📊 &nbsp;Bar</summary>
<img src="assets/06-bar.png" width="100%"/>
</details>

<details>
<summary>🚀 &nbsp;Launcher</summary>
<img src="assets/03-rofi.png" width="100%"/>
</details>

<details>
<summary>⏻ &nbsp;Power menu</summary>
<img src="assets/04-powermenu.png" width="100%"/>
</details>

<details>
<summary>🔔 &nbsp;Notifications</summary>
<img src="assets/05-notify.png"/>
</details>

## Contents

| | |
|---|---|
| **Compositor** | Hyprland |
| **Bar** | Waybar |
| **Launcher / power menu** | Rofi |
| **Notifications** | mako |
| **Terminal** | kitty |
| **System monitor** | btop |
| **Editor** | Neovim (AstroNvim) |
| **Lock / idle** | hyprlock, hypridle |
| **Wallpaper** | hyprpaper |
| **File manager** | Nautilus |
| **Browser** | Brave |
| **Chat** | Discord |
| **Agentic coding** | Claude Code |
| **AUR helper** | paru (built from source) |
| **Rust** | rustup — stable, `complete` profile |
| **Login** | greetd + nwg-hello |
| **Secrets** | gnome-keyring, unlocked by PAM at login |
| **Theme** | Catppuccin Mocha, everywhere |

## Install

No Arch yet? Start with **[docs/arch-install.md](docs/arch-install.md)** — it
installs alongside an existing OS and hands off here at the first TTY login.

```bash
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
./install.sh --dry-run        # writes nothing, runs every check
./install.sh                  # everything
```

Keep the directory name — a few configs hard-code the path. Anything already in
the way is moved to `~/.dotfiles-backup-<timestamp>/`, never overwritten.

| Flag | |
|---|---|
| `--dry-run` | report what would change, write nothing |
| `--skip-packages` | configs only — no pacman, AUR, themes or nvim |
| `--skip-greeter` | everything except the login screen |

> [!WARNING]
> The greeter is the one step that can leave you without a graphical login.
> First time on real hardware, stage it: `./install.sh --skip-greeter`, reboot,
> confirm the desktop comes up, then `./scripts/install-greeter.sh`. It prints a
> live check (`systemctl start greetd`) and a rollback before you commit.

## Keybinds

`$mod` is SUPER.

| Bind | Action |
|---|---|
| `$mod` + Return | kitty |
| `$mod` + R | rofi |
| `$mod` + E | nautilus |
| `$mod` + B | brave |
| `$mod` + Q | close window |
| `$mod` + F | fullscreen |
| `$mod` + V | toggle floating |
| `$mod` + C | clipboard history |
| `$mod` + N / `$mod`+Shift+N | dismiss / restore notification |
| `$mod` + Shift + X | power menu |
| `$mod` + M | exit Hyprland |
| `$mod` + h/j/k/l | move focus |
| `$mod` + Shift + h/j/k/l | move window |
| `$mod` + 1-0 | workspace |
| `$mod` + Shift + 1-0 | move window to workspace |
| `$mod` + drag / right-drag | move / resize window |
| Volume up / down / mute | audio (`wpctl`) |
| Print / `$mod` + Print | screenshot output / region |

## Scripts

`install.sh` runs these in order. Each is idempotent and re-runnable on its own.

| Script | |
|---|---|
| `scripts/packages.sh` | pacman packages, NVIDIA driver, Rust toolchain |
| `scripts/install-aur.sh` | builds paru from source, then brave-bin + claude-code |
| `scripts/preflight.sh` | moves anything that would collide with stow |
| `scripts/install-themes.sh` | GTK/Qt dark mode and cursor, outside dotfiles |
| `scripts/install-keyring.sh` | PAM auto-unlock for gnome-keyring |
| `scripts/install-greeter.sh` | greetd + nwg-hello, copied to `/etc` |
| `scripts/greeter-template.py` | centres the greeter form, derived not vendored |
| `scripts/bootstrap-nvim.sh` | headless Neovim plugin sync |

Every top-level directory is a stow package mirroring `$HOME` —
`hypr/.config/hypr/general.conf` → `~/.config/hypr/general.conf`. `greeter/` and
`wallpapers/` are the exceptions: copied to `/etc` and `/usr/share`, not stowed.

## Notes

- **This targets one machine** (`europa`) — no hardware detection. Everything
  machine-specific is in `hypr/.config/hypr/hardware.conf`.
- **Never `pacman -Sy <pkg>`** — it's a partial upgrade and it breaks Arch. Same
  for `paru -Sy`. `paru -Syu` is the update path, including AUR.
- **Reboot after any `-Syu` that lands a kernel**, or the NVIDIA modules won't load.
- **Rust is `rustup`, not `rust`** — they conflict; `packages.sh` refuses up front
  and tells you what to remove.
- **The keyring needs two logins on a fresh install.** The first creates it, the
  second is when apps can see it. `./scripts/install-keyring.sh 0` tells you which
  state you're in.

The *why* behind all of the above lives in comments next to the code it applies
to — the install scripts and the config files themselves — rather than here,
where it would go stale out of sight.

## Uninstall

```bash
cd ~/hyprland-dotfiles
stow -D -t "$HOME" hypr waybar rofi mako kitty btop nvim hyprlock hypridle theme
```

The greeter isn't a stow package, so undo it separately — **before** you reboot,
or you'll log into a session whose config just vanished:

```bash
sudo systemctl disable greetd
sudo systemctl set-default multi-user.target
```

<p align="center">
	<img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg?sanitize=true"/>
</p>

<p align="center">
	Palette by <a href="https://github.com/catppuccin/catppuccin">Catppuccin</a> ·
	Inspired by <a href="https://github.com/rizukirr/hyprsimple">hyprsimple</a>
</p>
