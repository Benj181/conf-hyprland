#!/usr/bin/env bash
# scripts/packages.sh
# pacman packages for the Hyprland setup on europa (Arch Linux, RTX 5070 Ti).
#
# Everything goes into ONE `pacman -Syu --needed` transaction: `pacman -Sy <pkg>`
# is a partial upgrade, which Arch does not support. The arrays are only for
# reading. On a re-run this can pull a new kernel -- reboot before expecting the
# NVIDIA modules to load.

set -euo pipefail

core=(
    hyprland                     # provides start-hyprland, used by greetd
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk       # puts libadwaita apps into dark mode
    waybar
    rofi
    kitty
    mako
    nautilus
    wl-clipboard
    cliphist
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    networkmanager
    network-manager-applet       # nm-connection-editor for waybar's network module
    bluez
    bluez-utils
    blueman
    btop
    grim
    slurp
    hyprshot
    jq
    libnotify
    stow
    git                          # also needed by install-aur.sh
)

# Brave and Claude Code come from the AUR (scripts/install-aur.sh).
apps=(
    discord
)

# Needs the PAM setup in scripts/install-keyring.sh, or it prompts on every login.
keyring=(
    gnome-keyring
    libsecret
    seahorse
)

# See scripts/install-greeter.sh. nwg-hello expects greetd's `greeter` user.
login=(
    greetd
    nwg-hello
)

# Not ttf-fira-code: that has no Nerd glyphs.
theming=(
    ttf-firacode-nerd
    noto-fonts-emoji             # the Nerd Font has no real emoji
    papirus-icon-theme
    gnome-themes-extra           # Adwaita-dark
    adwaita-icon-theme
    adwaita-cursors
    gsettings-desktop-schemas    # install-themes.sh writes gsettings keys;
    dconf                        # without these they silently don't persist
    qt5ct
    qt6ct
    nwg-look
)

shell=(
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
)

nvim=(
    neovim
    ripgrep
    fd
    fzf
    base-devel                   # makepkg, needed by install-aur.sh
    python
    python-pip
    nodejs
    npm
    luarocks
)

# rustup, not `rust`: they conflict, and paru's `cargo` makedepend would
# otherwise pull in `rust` during install-aur.sh.
rust=(
    rustup
)

# nvidia-open is prebuilt for the stock `linux` kernel. linux-lts needs
# nvidia-open-lts; any other kernel needs nvidia-open-dkms plus headers.
nvidia=(
    nvidia-open
    egl-wayland
)

# Refuse up front if another network daemon is enabled: two daemons on one
# interface can drop the network mid-install.
for unit in systemd-networkd.service iwd.service; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        echo "==> $unit is enabled, and this installs NetworkManager." >&2
        echo "    Two daemons managing one interface is how you lose the network" >&2
        echo "    mid-install. Disable one or the other by hand, then re-run:" >&2
        echo "        sudo systemctl disable --now $unit" >&2
        echo "    Or, if you want to keep it, drop networkmanager and" >&2
        echo "    network-manager-applet from the core array below." >&2
        exit 1
    fi
done

# rustup conflicts with rust/cargo/rustfmt, and --noconfirm answers that prompt
# "no", aborting the whole transaction. Match exact installed names: `pacman -Qq
# rust` resolves Provides and would report rustup itself.
# Here-strings instead of `pacman -Qq | grep -q`: under pipefail a match returns
# 141 (SIGPIPE). Same in have_family() below.
installed_names="$(pacman -Qq)"
for pkg in rust cargo rustfmt; do
    if grep -Fxq "$pkg" <<<"$installed_names"; then
        echo "==> The package '$pkg' is installed, and this installs rustup," >&2
        echo "    which conflicts with it. pacman --noconfirm cannot resolve" >&2
        echo "    that and would abort the entire transaction." >&2
        echo "    rustup replaces it -- it provides rustc/cargo/rustfmt as shims" >&2
        echo "    over toolchains it manages. Remove it, then re-run:" >&2
        echo "        sudo pacman -Rdd $pkg" >&2
        echo "    (-Rdd because other packages depend on it by name; rustup" >&2
        echo "    satisfies those the moment it is installed.)" >&2
        exit 1
    fi
done

echo "==> Full system upgrade and install (one pacman transaction)"
sudo pacman -Syu --needed --noconfirm \
    "${core[@]}" "${apps[@]}" "${keyring[@]}" "${login[@]}" "${theming[@]}" \
    "${nvim[@]}" "${rust[@]}" "${nvidia[@]}" "${shell[@]}"

echo "==> Enabling NetworkManager and bluetooth"
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

# The rustup package ships only shims; without a toolchain cargo fails, and
# install-aur.sh needs cargo to build paru. Toolchains are per-user ($HOME/.rustup),
# so this must not run as root.
if [ "$(id -u)" -eq 0 ]; then
    echo "==> Refusing to install the Rust toolchain as root: it installs into" >&2
    echo "    \$HOME/.rustup, so it would land in /root and your own user would" >&2
    echo "    still have none. Re-run as your normal user; this script calls" >&2
    echo "    sudo itself for the parts that need it." >&2
    exit 1
fi

echo "==> Installing the Rust toolchain (stable, default profile)"
# Arch builds rustup with self-update disabled.
rustup toolchain install stable --profile default --no-self-update
rustup default stable

# --profile only applies to a fresh toolchain install, so add components
# explicitly. miri is not in the stable manifest.
echo "==> Adding toolchain components (rust-analyzer, rust-src, llvm-tools)"
rustup component add rust-analyzer rust-src llvm-tools

if ! cargo --version >/dev/null 2>&1; then
    echo "==> rustup is installed but 'cargo' does not run:" >&2
    cargo --version 2>&1 | sed 's/^/        /' >&2 || true
    echo "    install-aur.sh builds paru with cargo and would fail here." >&2
    exit 1
fi
echo "    OK: $(cargo --version)"

# Missing fonts fall back silently, so check. Exact match (-Fx): "FiraCode Nerd
# Font" is a substring of "FiraCode Nerd Font Mono".
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

# Probe a real emoji (U+1F5A5). Nerd Font codepoints like U+23FB are covered by
# ttf-firacode-nerd and would pass without any emoji font.
echo "==> Verifying emoji coverage"
if [ -z "$(fc-list ':charset=1F5A5' family 2>/dev/null)" ]; then
    echo "    No installed font covers U+1F5A5." >&2
    echo "    Emoji render as blanks in Discord, Brave and anything else." >&2
    echo "    Check with: fc-list ':charset=1F5A5' family" >&2
    exit 1
fi
echo "    OK: emoji resolve to $(fc-list ':charset=1F5A5' family 2>/dev/null | head -1 | cut -d, -f1)"

echo "==> Packages done"
