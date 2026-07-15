#!/usr/bin/env bash
# scripts/packages.sh
# pacman packages for the Hyprland setup on europa (Arch Linux).
#
# No hardware detection: this targets one machine. europa is a desktop with an
# RTX 5070 Ti (Blackwell), which is open-kernel-module only -- there is no
# proprietary/open branch to pick between, so the driver is named outright.
#
# WHY THIS IS ONE TRANSACTION AND NOT FIVE
#
# `pacman -Sy <pkg>` is a PARTIAL UPGRADE: it refreshes the package databases
# and then installs a package built against library versions the rest of the
# system has not upgraded to yet. Arch does not support this and it breaks
# systems. There is no apt analogue -- `apt update && apt install` is fine,
# this is not -- so it is the one genuinely new rule this file exists to obey.
#
# Everything therefore goes into ONE `pacman -Syu --needed` transaction:
# databases refreshed, whole system brought current, new packages installed,
# all mutually consistent. The arrays below are for reading. They are NOT
# separate transactions; splitting them would mean five full system upgrades
# per run.
#
# `--needed` is what makes this idempotent: already-current packages are
# skipped rather than reinstalled.
#
# COST: on a fresh install the upgrade is nearly free -- everything is already
# current. On a re-run weeks later it can pull hundreds of megabytes and a new
# kernel. That is not this script being greedy, it is the only supported way
# to install anything on Arch. If a kernel lands, REBOOT before expecting the
# NVIDIA modules to load -- see README, Hardware notes.

set -euo pipefail

# Core Hyprland stack.
core=(
    hyprland                     # ships /usr/bin/start-hyprland, which
                                 # /etc/greetd/config.toml invokes
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    hyprland-qtutils
    xdg-desktop-portal-hyprland  # Only an optdepend of hyprland on Arch, but
    xdg-desktop-portal-gtk       # theme/.config/gtk-4.0/settings.ini and
                                 # install-themes.sh both document the portal
                                 # as the mechanism that puts libadwaita apps
                                 # into dark mode. Unnamed, it is not installed
                                 # and both files describe something that does
                                 # not exist.
    waybar
    rofi                         # 2.0.0 and wayland-native (it provides and
                                 # replaces rofi-wayland). Ubuntu shipped 1.7.x.
    kitty
    mako                         # was: mako-notifier
    nautilus
    wl-clipboard
    cliphist
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    networkmanager               # Ubuntu had the daemon by default; a minimal
    network-manager-applet       # Arch install does not. Without it waybar's
                                 # network module and its nm-connection-editor
                                 # on-click are dead icons.
                                 # was: network-manager-gnome
    bluez                        # Same story: blueman is only a frontend.
    bluez-utils
    blueman
    btop
    grim
    slurp
    hyprshot                     # 1.3.0-4 -- the exact tag the old curl block
                                 # pinned. Packaged now, so the download, the
                                 # shebang check and the /usr/local/bin install
                                 # are all gone.
    jq
    libnotify                    # was: libnotify-bin
    stow
    git                          # also required by install-aur.sh
)

# Login screen. See scripts/install-greeter.sh.
#
# greetd creates the `greeter` account from /usr/lib/sysusers.d/greetd.conf at
# install time -- not Debian's `_greetd`. nwg-hello's own source assumes that
# name (main.py and tools.py both gate on os.getenv("USER") == "greeter"), so
# on Ubuntu its --log flag was silently a no-op.
login=(
    greetd
    nwg-hello                    # 0.4.5. This repo's CSS and template edit
                                 # were written against 0.4.2 --
                                 # install-greeter.sh verifies rather than
                                 # assumes.
)

# Theming.
#
# ttf-fira-code is deliberately NOT installed: it provides "Fira Code" with no
# Nerd glyphs, which is not what any config here asks for. Same trap as
# Ubuntu's fonts-firacode, different spelling.
theming=(
    ttf-firacode-nerd            # 3.4.0 -- the exact release install-fonts.sh
                                 # used to download. Lands in /usr/share/fonts,
                                 # which the greeter can read, so the old
                                 # copy-the-font-somewhere-readable step in
                                 # install-greeter.sh is gone with it.
    papirus-icon-theme
    gnome-themes-extra           # Provides Adwaita-dark, which
                                 # theme/.config/gtk-3.0/settings.ini names. It
                                 # happens to be an nwg-hello dependency --
                                 # named here anyway, because a theme that
                                 # arrives by luck silently reverts the day
                                 # that dependency changes.
    adwaita-icon-theme
    adwaita-cursors              # gtk-cursor-theme-name=Adwaita and
                                 # `hyprctl setcursor Adwaita 24` both fall
                                 # back silently without it.
    gsettings-desktop-schemas    # install-themes.sh writes
    dconf                        # org.gnome.desktop.interface keys. With no
                                 # schemas gsettings has nothing to write and
                                 # every key "skips" -- a green install with no
                                 # dark mode. With no dconf it writes to the
                                 # memory backend and the values evaporate at
                                 # logout, which is worse: it reports success.
                                 # Both are guaranteed on Ubuntu and merely
                                 # likely-transitive here.
    qt5ct
    qt6ct
    nwg-look
)

# Neovim toolchain.
#
# neovim itself is now just a package: extra has 0.12.4, the exact version the
# old scripts/install-neovim.sh fetched as a tarball into /opt/nvim. That
# script, its version pin and its PATH-shadowing warning are all gone.
nvim=(
    neovim
    ripgrep
    fd                           # was: fd-find. Arch ships the binary as `fd`,
                                 # so the ~/.local/bin/fd symlink this script
                                 # used to create is gone with it.
    fzf
    base-devel                   # was: build-essential. Also what makepkg
                                 # needs, so install-aur.sh depends on this
                                 # having run first.
    python
    python-pip
    # python3-venv has no counterpart here: venv ships inside `python`.
    nodejs
    npm
    luarocks
)

# NVIDIA. Blackwell is open-kernel-module only.
#
# nvidia-open is the PREBUILT module set for the stock `linux` kernel. If the
# kernel ever changes this must change with it: linux-lts -> nvidia-open-lts,
# anything else -> nvidia-open-dkms plus the matching headers.
nvidia=(
    nvidia-open                  # was: nvidia-driver-595-open
    egl-wayland                  # was: libnvidia-egl-wayland1
)

echo "==> Full system upgrade and install (one pacman transaction)"
sudo pacman -Syu --needed --noconfirm \
    "${core[@]}" "${login[@]}" "${theming[@]}" "${nvim[@]}" "${nvidia[@]}"

# ---------------------------------------------------------------------------
# Services Ubuntu enabled for us and a minimal Arch install does not.
#
# The guard is not paranoia: if archinstall left systemd-networkd or iwd
# managing the link, enabling NetworkManager on top gives two daemons fighting
# over one interface. Refuse loudly rather than half-configure the network --
# this is the one step here that can cost you the network you are installing
# over.
# ---------------------------------------------------------------------------
echo "==> Enabling NetworkManager and bluetooth"
for unit in systemd-networkd.service iwd.service; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        echo "    $unit is enabled; NetworkManager would fight it for the same" >&2
        echo "    interface. Disable one or the other by hand, then re-run." >&2
        exit 1
    fi
done
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

# ---------------------------------------------------------------------------
# Prove the font landed, rather than assuming the package did what it says.
#
# This check used to live in scripts/install-fonts.sh, which downloaded
# FiraCode.zip because apt's fonts-firacode was the wrong font entirely (no
# Nerd glyphs -- bar icons rendered as tofu). ttf-firacode-nerd is that same
# v3.4.0 release, so the download is gone. The check is not: a font GTK cannot
# find does not error, it silently falls back, and that is the bug this whole
# repo keeps tripping over.
#
# Exact family match: "FiraCode Nerd Font" is a substring of "FiraCode Nerd
# Font Mono", so a plain substring grep would report success while the
# proportional family is still missing -- the exact bug this check exists to
# catch. ttf-firacode-nerd also ships a "Propo" family, which makes -Fx matter
# more here than it did on Ubuntu, not less.
#
# The here-string is deliberate: `... | grep -Fxq` under `set -o pipefail`
# returns 141, not 0, *when it matches*. grep -q exits on the first hit, the
# upstream fc-list dies of SIGPIPE, and pipefail propagates that. A successful
# match would be reported as a missing font.
# ---------------------------------------------------------------------------
have_family() {
    local families
    families="$(fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*//')"
    grep -Fxq "$1" <<<"$families"
}

echo "==> Verifying Nerd Font families"
missing=0
for fam in "FiraCode Nerd Font" "FiraCode Nerd Font Mono"; do
    if have_family "$fam"; then
        echo "    OK: $fam"
    else
        echo "    MISSING: $fam" >&2
        missing=1
    fi
done
[ "$missing" -eq 0 ] || {
    echo "ttf-firacode-nerd did not provide the families the configs name." >&2
    echo "Inspect with: fc-list : family | tr ',' '\\n' | grep -i fira" >&2
    exit 1
}

echo "==> Packages done"
