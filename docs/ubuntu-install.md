# Reproducing the rice on Ubuntu

This repo is built for Arch (`install.sh` calls `pacman` and `paru`). Ubuntu
ships almost the whole Hyprland stack in its own repos now, so you don't need
any of that — you install the packages with `apt`, then use the same stow
configs.

Worked example is `baas-Yoga-Slim-7-14Q8X9` — a Lenovo Yoga Slim 7 (Snapdragon,
**arm64**) running **Ubuntu 26.04 LTS "Resolute Raccoon"**. Substitute your own
hostname and user throughout. Nothing here is arm-specific except where noted;
the package names are the same on amd64.

Ubuntu came pre-installed on the machine, so unlike [arch-install.md](arch-install.md)
there's no partitioning step — this starts from a working desktop login.

## What's different from Arch

| Arch (`scripts/packages.sh`) | Ubuntu | Why |
|---|---|---|
| `pacman -Syu` one transaction | `apt-get install` | apt has no partial-upgrade footgun to design around |
| `mako` | `mako-notifier` | Debian renamed the binary package; the daemon is still `mako` |
| `network-manager-applet` | `network-manager-gnome` | provides `nm-applet` |
| AUR via `paru` (brave, claude-code) | apt repo for Brave; npm for Claude Code | no AUR on Ubuntu |
| `ttf-firacode-nerd` | Nerd Font unzipped by hand into `~/.fonts` | Ubuntu doesn't package the Nerd-patched variant |
| driver named outright (`nvidia-open`) | nothing | this laptop is integrated-only |

Everything else — `hyprland`, `hyprpaper`, `hyprlock`, `hypridle`,
`hyprpolkitagent`, `waybar`, `rofi`, `kitty`, `nautilus`, `wl-clipboard`,
`cliphist`, `grim`, `slurp`, `greetd`, `nwg-hello` — is in **`resolute/universe`**
under the same name. Enable `universe` if it isn't already:

```bash
sudo add-apt-repository universe
```

## 1. Packages

The one root step. `setup-ubuntu-packages.sh` in the repo root is the full list;
it's idempotent, so re-running is safe.

```bash
sudo bash ~/hyprland-dotfiles/setup-ubuntu-packages.sh
```

**Watch out:** the package is **`hyprland-qtutils`**, not `hyprland-guiutils`.
It's a *runtime* dependency of Hyprland — it provides `hyprland-dialog` and the
config-error / update popups. Miss it and Hyprland throws an orange
"hyprland-qtutils is not installed" overlay at **every login**, and there is no
config option to silence it in 0.53 (`misc:disable_hyprland_qtutils_check`
doesn't exist). apt fails closed on the wrong name — `apt install
hyprland-guiutils` just says "Unable to locate package" and installs nothing —
so it's easy to think you handled it when you didn't. This is why it's called
out here and pinned in the script.

## 2. Configs (stow)

Identical to Arch — every top-level directory is a stow package mirroring
`$HOME`.

```bash
cd ~/hyprland-dotfiles
sudo apt install -y stow        # if the package step didn't run yet
stow hypr hypridle hyprlock waybar rofi kitty mako nvim btop
```

**Watch out:** stow refuses to overlay a real file. If GNOME (the default
session) or a first Hyprland launch already wrote e.g.
`~/.config/hypr/hyprland.conf`, move it aside first. On Arch, `scripts/preflight.sh`
does this; on Ubuntu do it by hand, or run that script — it's shell, not pacman,
so it works here too.

## 3. Fonts, cursor, theme

No `ttf-firacode-nerd` package, so fetch the Nerd Font release the configs
expect (waybar and kitty both name `FiraCode Nerd Font`):

```bash
mkdir -p ~/.fonts
cd /tmp && curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -o FiraCode.zip -d ~/.fonts/FiraCode && fc-cache -f
```

Emoji come from `fonts-noto-color-emoji` (in the package list). GTK/Qt dark mode
is the same mechanism the Arch `scripts/install-themes.sh` documents — the
`xdg-desktop-portal-gtk` portal plus `Adwaita-dark` from `gnome-themes-extra`,
both installed above. `qt6ct` reads `theme/.config/gtk-*`; Hyprland's
`env = QT_QPA_PLATFORMTHEME,qt6ct` in `general.conf` wires Qt apps to it.

## 4. Greeter (greetd + nwg-hello)

`scripts/install-greeter.sh` is shell and works on Ubuntu, but stage it — don't
let a broken greeter lock you out of a machine whose only session was working
GNOME.

```bash
Hyprland                         # launch by hand from a GNOME terminal / TTY first
nwg-hello -t                     # preview in a window, greetd untouched
./scripts/install-greeter.sh
sudo systemctl start greetd      # live, before you `enable` it
```

To switch the default session manager from GDM to greetd:

```bash
sudo systemctl disable gdm       # or gdm3
sudo systemctl enable greetd
```

**Watch out:** keep a TTY reachable (`Ctrl+Alt+F3`) the first time you enable
greetd. If it comes up black, `sudo systemctl disable greetd && sudo systemctl
enable gdm` from there and you're back to a known-good login.

## 5. Keyring

Same two-login gotcha as Arch, same fix. `gnome-keyring` and the PAM wiring
(`scripts/install-keyring.sh`) are what stop it re-prompting for the eduroam /
Wi-Fi password every login — and `nm-applet` (from `network-manager-gnome`, in
autostart) is the secret agent that feeds those saved secrets to
NetworkManager. On GNOME, gnome-shell filled that role; under Hyprland nothing
does unless nm-applet runs.

## If it goes wrong

- **"hyprland-qtutils is not installed" nag on every login** — you don't have
  the package, or you tried the wrong name. `sudo apt install hyprland-qtutils`
  (see §1). There is no config toggle; the package is the only fix.
- **stow: "existing target is not a symlink"** — a real file is in the way (§2).
  Move it, re-run `stow`.
- **Blank/black greeter** — reachable TTY → disable greetd, re-enable gdm (§4),
  debug `Hyprland` and `nwg-hello -t` by hand.
- **Wi-Fi/eduroam re-prompts every login** — nm-applet isn't running as the
  secret agent, or the keyring PAM step didn't take (§5).
- **`apt` can't find a hypr* package** — check `universe` is enabled
  (`add-apt-repository universe`) and you're on 26.04; several of these landed in
  the repos only recently.
