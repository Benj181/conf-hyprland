<h3 align="center">
	Hyprland — Catppuccin Mocha (Ubuntu branch)
</h3>

<p align="center">
	A complete Hyprland rice, reproduced on Ubuntu with <code>apt</code> + GNU Stow.<br/>
	The <a href="https://github.com/Benj181/conf-hyprland/tree/main">main branch</a> is the original Arch build.
</p>

<p align="center">
	<img src="https://img.shields.io/badge/Hyprland-0.53-cba6f7?style=for-the-badge&labelColor=1e1e2e&logo=hyprland&logoColor=cba6f7"/>
	<img src="https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&labelColor=1e1e2e&logo=ubuntu&logoColor=E95420"/>
	<img src="https://img.shields.io/badge/Catppuccin-Mocha-f5c2e7?style=for-the-badge&labelColor=1e1e2e"/>
	<img src="https://img.shields.io/badge/GNU-Stow-a6e3a1?style=for-the-badge&labelColor=1e1e2e&logo=gnu&logoColor=a6e3a1"/>
</p>

<p align="center">
	<img src="assets/02-tiling.png" width="100%"/>
</p>

> [!NOTE]
> **This is the Ubuntu branch.** The rice was written for Arch — `install.sh`
> drives `pacman` + `paru` and does **not** run on Ubuntu. Here you install the
> same stack with `apt` and reuse the identical stow configs. The full,
> step-by-step walkthrough (packages, fonts, greeter, keyring, and every gotcha)
> lives in **[docs/ubuntu-install.md](docs/ubuntu-install.md)** — this README is
> the short version. Worked example: a Lenovo Yoga Slim 7 (Snapdragon, **arm64**)
> on **Ubuntu 26.04 "Resolute Raccoon"**; package names are the same on amd64.

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
| **Notifications** | mako (`mako-notifier` on Ubuntu) |
| **Terminal** | kitty |
| **System monitor** | btop |
| **Editor** | Neovim (AstroNvim) |
| **Lock / idle** | hyprlock, hypridle |
| **Wallpaper** | hyprpaper |
| **File manager** | Nautilus |
| **Browser** | Brave (Brave's own apt repo) |
| **Chat** | Discord (official `.deb`) |
| **Agentic coding** | Claude Code (npm) |
| **Packages** | `apt` — most of the stack is in `universe` |
| **Login** | greetd + nwg-hello (Ubuntu ships GDM by default) |
| **Secrets** | gnome-keyring, unlocked by PAM at login |
| **Theme** | Catppuccin Mocha, everywhere |

## Install

Most of the Hyprland stack is in Ubuntu's `universe` component, so the whole
thing is `apt` + `stow`. The one root step is `setup-ubuntu-packages.sh`.

```bash
git clone -b ubuntu-install https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles

sudo add-apt-repository universe            # if it isn't enabled already
sudo bash setup-ubuntu-packages.sh          # the only root step — idempotent
stow hypr hypridle hyprlock waybar rofi kitty mako nvim btop
```

Keep the directory name — a few configs hard-code `~/hyprland-dotfiles`.

> [!WARNING]
> **stow refuses to overlay a real file.** If GNOME or a first Hyprland launch
> already wrote e.g. `~/.config/hypr/hyprland.conf`, move it aside first — or run
> `scripts/preflight.sh`, which is shell (not pacman) and works on Ubuntu too.
> Anything it moves goes to `~/.dotfiles-backup-<timestamp>/`, never overwritten.

The login screen is the one step that can lock you out of a machine whose only
working session was GNOME. Stage it — preview with `nwg-hello -t`, start greetd
live before enabling it, and keep a TTY (`Ctrl+Alt+F3`) reachable. Full sequence
in **[docs/ubuntu-install.md §4](docs/ubuntu-install.md)**.

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
| Brightness up / down | backlight (`brightnessctl`) |
| Print / `$mod` + Print | screenshot output / region |

## Scripts

On Ubuntu the package step is **`setup-ubuntu-packages.sh`** (root, idempotent) —
it replaces the Arch `install.sh` / `scripts/packages.sh` / `scripts/install-aur.sh`
chain, which is `pacman` + `paru` and Arch-only. The rest of the helpers are plain
shell and run fine on Ubuntu:

| Script | | Ubuntu? |
|---|---|---|
| `setup-ubuntu-packages.sh` | the full apt package list + Brave + Discord | **Ubuntu** |
| `scripts/preflight.sh` | moves anything that would collide with stow | ✅ |
| `scripts/install-themes.sh` | GTK/Qt dark mode and cursor, outside dotfiles | ✅ |
| `scripts/install-keyring.sh` | PAM auto-unlock for gnome-keyring | ✅ |
| `scripts/install-greeter.sh` | greetd + nwg-hello, copied to `/etc` | ✅ |
| `scripts/bootstrap-nvim.sh` | headless Neovim plugin sync | ✅ |
| `install.sh`, `scripts/packages.sh`, `scripts/install-aur.sh` | pacman/paru orchestration | ❌ Arch |

Every top-level directory is a stow package mirroring `$HOME` —
`hypr/.config/hypr/general.conf` → `~/.config/hypr/general.conf`. `greeter/` and
`wallpapers/` are the exceptions: copied to `/etc` and `/usr/share`, not stowed.

## Notes

- **This branch targets one machine** — a single-panel Snapdragon laptop. Everything
  machine-specific is in `hypr/.config/hypr/hardware.conf` (single `eDP-1` at scale 2,
  no NVIDIA env, session PATH, GTK renderer). Point it at your own output with
  `hyprctl monitors`.
- **The package is `hyprland-qtutils`, not `hyprland-guiutils`.** It's a *runtime*
  dependency; miss it and Hyprland throws an orange "hyprland-qtutils is not
  installed" overlay at every login, with no config toggle to silence it. `apt`
  fails closed on the wrong name, so it's easy to think you handled it.
- **`mako` is packaged as `mako-notifier`**, and `nm-applet` comes from
  `network-manager-gnome` — both already in `setup-ubuntu-packages.sh`.
- **The keyring needs two logins on a fresh install.** The first creates it, the
  second is when apps can see it. Under Hyprland, `nm-applet` (in autostart) is the
  secret agent that feeds saved Wi-Fi/eduroam passwords to NetworkManager — the role
  gnome-shell filled under GNOME.
- **Adreno GPU text corruption.** On this laptop's Adreno GPU (Mesa Turnip/Vulkan),
  Chromium and GTK4 corrupt their glyph atlas — garbled text. Fixed with
  `GSK_RENDERER=ngl` for GTK4 (in `hardware.conf`) and `--disable-gpu-rasterization`
  for Brave (in the `$browser` keybind). Harmless on non-Adreno hardware.
- **Several packages landed in the repos only recently** — if `apt` can't find a
  `hypr*` package, confirm `universe` is enabled and you're on 26.04.

The *why* behind all of the above lives in comments next to the code it applies to —
the config files and `setup-ubuntu-packages.sh` — rather than here, where it would go
stale out of sight. See [docs/ubuntu-install.md](docs/ubuntu-install.md) for the long form.

## Uninstall

```bash
cd ~/hyprland-dotfiles
stow -D -t "$HOME" hypr waybar rofi mako kitty btop nvim hyprlock hypridle theme
```

If you switched the login manager to greetd, undo it **before** you reboot, or
you'll log into a session whose config just vanished:

```bash
sudo systemctl disable greetd
sudo systemctl enable gdm            # back to Ubuntu's default
```

<p align="center">
	<img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg?sanitize=true"/>
</p>

<p align="center">
	Palette by <a href="https://github.com/catppuccin/catppuccin">Catppuccin</a> ·
	Inspired by <a href="https://github.com/rizukirr/hyprsimple">hyprsimple</a>
</p>
