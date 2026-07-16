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
# systems -- so this file goes out of its way to never do it.
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
    # hyprland-qtutils is NOT here: it exists in neither Arch's repos nor the
    # AUR, nothing in this repo references it, and pacman aborts the whole
    # transaction on one unknown target -- so carrying it would have installed
    # nothing at all.
    xdg-desktop-portal-hyprland  # Only an optdepend of hyprland on Arch, but
    xdg-desktop-portal-gtk       # theme/.config/gtk-4.0/settings.ini and
                                 # install-themes.sh both document the portal
                                 # as the mechanism that puts libadwaita apps
                                 # into dark mode. Unnamed, it is not installed
                                 # and both files describe something that does
                                 # not exist.
    waybar
    rofi                         # 2.0.0 and wayland-native (it provides and
                                 # replaces rofi-wayland).
    kitty
    mako
    nautilus
    wl-clipboard
    cliphist
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    networkmanager               # A minimal Arch install has no network daemon.
    network-manager-applet       # Without it waybar's network module and its
                                 # nm-connection-editor on-click are dead icons.
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
    libnotify
    stow
    git                          # also required by install-aur.sh
)

# Desktop applications that Arch carries itself.
#
# Brave and Claude Code are NOT here -- neither is in the repos, so both come
# from the AUR via scripts/install-aur.sh. Discord is, so it does not need to.
apps=(
    discord
)

# Secrets. The PAM half is scripts/install-keyring.sh, and it is not optional:
# these packages on their own give you a keyring that prompts for a password on
# every login, which is the thing a keyring exists to avoid.
keyring=(
    gnome-keyring   # the daemon, and pam_gnome_keyring.so, which
                    # install-keyring.sh wires into /etc/pam.d
    libsecret       # the library every client links, and secret-tool. Only
                    # transitive today (brave and nautilus both pull it in), so
                    # it is named outright rather than left to arrive by luck.
    seahorse        # the only way to look inside the keyring, rename one, or
                    # re-key it after a password change -- see README, Keyring.
)

# Login screen. See scripts/install-greeter.sh.
#
# greetd creates the `greeter` account from /usr/lib/sysusers.d/greetd.conf at
# install time. nwg-hello's own source assumes that exact name (main.py and
# tools.py both gate on os.getenv("USER") == "greeter").
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
# Nerd glyphs, which is not what any config here asks for.
theming=(
    ttf-firacode-nerd            # 3.4.0 -- the same Nerd Fonts release this
                                 # repo used to unzip by hand. Lands in
                                 # /usr/share/fonts, which the greeter can
                                 # read, so install-greeter.sh no longer has to
                                 # copy the font somewhere readable either.
    noto-fonts-emoji             # Emoji are their own font, and the Nerd Font is
                                 # not one. ttf-firacode-nerd covers U+23FB (the
                                 # power glyph) because that is a Nerd Font
                                 # codepoint, which makes this look handled --
                                 # but nothing on a minimal Arch install covers
                                 # U+1F5A5 or any other real emoji, so Discord,
                                 # Brave and this repo's own README rendered them
                                 # as blanks. Verified below.
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
                                 # Both are only likely-transitive here, so they
                                 # are named outright.
    qt5ct
    qt6ct
    nwg-look
)

# Neovim toolchain.
#
# neovim is just a package: extra has 0.12.4, which is exactly what this config
# targets.
nvim=(
    neovim
    ripgrep
    fd                           # Arch ships the binary as `fd`.
    fzf
    base-devel                   # what makepkg needs, so install-aur.sh depends
                                 # on this having run first.
    python
    python-pip
    # python3-venv has no counterpart here: venv ships inside `python`.
    nodejs
    npm
    luarocks
)

# Rust, via rustup rather than the `rust` package.
#
# These two cannot coexist: rustup Provides `rust` and `cargo` AND Conflicts
# with both -- see the guard above the transaction. Naming rustup here is what
# decides which one wins, and the timing is not incidental. paru's makedepend is
# `cargo`, so if this did not run first, `makepkg -s` in install-aur.sh would
# resolve that by installing `rust`, and rustup could never be installed
# afterwards without removing it again.
#
# A toolchain is a separate step from the package -- see below. The package
# alone gives you shims that error.
rust=(
    rustup
)

# NVIDIA. Blackwell is open-kernel-module only.
#
# nvidia-open is the PREBUILT module set for the stock `linux` kernel. If the
# kernel ever changes this must change with it: linux-lts -> nvidia-open-lts,
# anything else -> nvidia-open-dkms plus the matching headers.
nvidia=(
    nvidia-open
    egl-wayland
)

# ---------------------------------------------------------------------------
# Check for a competing network manager BEFORE the transaction, not after.
#
# This installs NetworkManager, which a minimal Arch install does not have. If
# something else is already managing the link -- archinstall offers
# systemd-networkd, and iwd is a common pick -- then enabling NM on top gives
# two daemons fighting over one interface. That is the one thing here that can
# cost you the network you are installing over, so it refuses rather than
# half-configuring it.
#
# It is up here on purpose: this fired at the *end* of a ~500-package download
# in testing, which is a long wait to be told the run was never going to
# finish. The condition has nothing to do with the transaction, so it does not
# have to wait for it.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Check for the rust/rustup conflict BEFORE the transaction too, and for the
# same reason as above: this aborts the whole run, so find out in a second
# rather than at the end of a ~500-package download.
#
# rustup declares `Conflicts: rust cargo rustfmt`. pacman resolves a conflict
# against an already-installed package by PROMPTING, and --noconfirm answers
# every prompt with its default -- which for this one is "no". So the entire
# transaction aborts as "unresolvable package conflicts detected" and nothing
# here installs at all, including the packages that have nothing to do with
# Rust.
#
# `pacman -Qq rust` is NOT the test, and this is the trap worth naming: pacman
# resolves Provides on query, so on a machine with only rustup installed
# `pacman -Qq rust` prints "rustup" and exits 0. It answers "is anything
# providing rust installed?", which is yes for the very package being
# installed -- so the obvious check reports a conflict with itself, forever.
# Match the real package NAME against the installed list instead.
#
# The here-string is the same defence as have_family() below: `pacman -Qq |
# grep -Fxq` under `set -o pipefail` returns 141 when it MATCHES, because grep
# exits early and pacman dies of SIGPIPE.
# ---------------------------------------------------------------------------
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
    "${nvim[@]}" "${rust[@]}" "${nvidia[@]}"

# A minimal Arch install does not enable these. blueman and waybar's
# network/bluetooth modules are frontends -- without the daemons they are dead
# icons.
echo "==> Enabling NetworkManager and bluetooth"
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

# ---------------------------------------------------------------------------
# Install an actual Rust toolchain.
#
# The rustup PACKAGE is not a Rust toolchain. /usr/bin/cargo and /usr/bin/rustc
# are symlinks to /usr/bin/rustup -- shims that dispatch to whichever toolchain
# is default. Fresh from pacman there is no toolchain and no default, so every
# one of them exits with:
#
#     error: no default toolchain configured
#
# That is not a cosmetic gap, and it is why this step is here rather than left
# to the user. rustup PROVIDES cargo, so `makepkg -s` in install-aur.sh sees
# paru's `cargo` makedepend as already satisfied, installs nothing, and starts
# building -- then `cargo build` dies on the missing toolchain. The dependency
# is met on paper and absent in fact. This must therefore run before
# install-aur.sh, which install.sh already orders correctly.
#
# NOT UNDER SUDO. Toolchains are per-user: they install into $HOME/.rustup and
# $HOME/.cargo. Run this as root and they land in /root, root's cargo works,
# and your shell still has nothing -- a green run with no toolchain, which is
# the failure mode this repo keeps having to design against.
# ---------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "==> Refusing to install the Rust toolchain as root: it installs into" >&2
    echo "    \$HOME/.rustup, so it would land in /root and your own user would" >&2
    echo "    still have none. Re-run as your normal user; this script calls" >&2
    echo "    sudo itself for the parts that need it." >&2
    exit 1
fi

echo "==> Installing the Rust toolchain (stable, complete profile)"
# --no-self-update: Arch builds rustup with self-update disabled ("you should
# probably use your system package manager"), so let it not try.
rustup toolchain install stable --profile complete --no-self-update
rustup default stable

# --profile applies ONLY when a toolchain is first installed. On a machine that
# already has stable -- from rustup's `default` profile, say -- the line above
# reports "unchanged" and adds nothing, so rust-analyzer and rust-src stay
# missing while the run looks completely successful. Name the extras outright so
# the top-up path works as well as the fresh one; `component add` is idempotent.
#
# miri is deliberately not in this list even though `complete` implies it: it is
# not in the stable channel's manifest. The profile omits it silently, but
# `rustup component add miri` fails outright and would take the script with it.
echo "==> Adding toolchain components (rust-analyzer, rust-src, llvm-tools)"
rustup component add rust-analyzer rust-src llvm-tools

# Same reflex as the font check below: prove the toolchain answers, rather than
# trusting that the install said so. This is the exact call install-aur.sh is
# about to depend on.
if ! cargo --version >/dev/null 2>&1; then
    echo "==> rustup is installed but 'cargo' does not run:" >&2
    cargo --version 2>&1 | sed 's/^/        /' >&2 || true
    echo "    install-aur.sh builds paru with cargo and would fail here." >&2
    exit 1
fi
echo "    OK: $(cargo --version)"

# ---------------------------------------------------------------------------
# Prove the font landed, rather than assuming the package did what it says.
#
# ttf-firacode-nerd provides the families the configs name -- but a package
# being installed is not the same claim as the family being findable under that
# name. A font GTK cannot find does not error, it silently falls back, and that
# is the bug this whole repo keeps tripping over. So verify rather than assume.
#
# Exact family match: "FiraCode Nerd Font" is a substring of "FiraCode Nerd
# Font Mono", so a plain substring grep would report success while the
# proportional family is still missing -- the exact bug this check exists to
# catch. ttf-firacode-nerd also ships a "Propo" family, which makes -Fx matter.
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

# ---------------------------------------------------------------------------
# Prove emoji resolve to a font, by codepoint rather than by family name.
#
# A family check cannot answer this. The question is not "is Noto Color Emoji
# installed", it is "does ANY font cover this character" -- and the failure is
# the usual one: no error, just a blank where a glyph should be.
#
# U+1F5A5 is the probe on purpose. U+23FB, the power glyph, is covered by
# ttf-firacode-nerd all on its own, because it is a Nerd Font codepoint -- so
# probing with that one reports success on a machine with no emoji font at all.
# That is not hypothetical: it is exactly what made this missing package look
# handled here for so long, while every other emoji rendered as nothing.
# ---------------------------------------------------------------------------
echo "==> Verifying emoji coverage"
if [ -z "$(fc-list ':charset=1F5A5' family 2>/dev/null)" ]; then
    echo "    No installed font covers U+1F5A5." >&2
    echo "    Emoji render as blanks in Discord, Brave and anything else." >&2
    echo "    Check with: fc-list ':charset=1F5A5' family" >&2
    exit 1
fi
echo "    OK: emoji resolve to $(fc-list ':charset=1F5A5' family 2>/dev/null | head -1 | cut -d, -f1)"

echo "==> Packages done"
