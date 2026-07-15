<h3 align="center">
	Hyprland — Catppuccin Mocha
</h3>

<p align="center">
	A complete, reproducible Hyprland rice for Ubuntu.<br/>
	One clone, one command.
</p>

<p align="center">
	<img src="https://img.shields.io/badge/Hyprland-0.53-cba6f7?style=for-the-badge&labelColor=1e1e2e&logo=hyprland&logoColor=cba6f7"/>
	<img src="https://img.shields.io/badge/Ubuntu-26.04-89b4fa?style=for-the-badge&labelColor=1e1e2e&logo=ubuntu&logoColor=89b4fa"/>
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
| **Theme** | Catppuccin Mocha, everywhere |

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

> [!NOTE]
> This targets one machine (`europa`) on purpose — there is no hardware
> detection and no per-host profiles. Everything machine-specific lives in
> `hypr/.config/hypr/hardware.conf`. See [Hardware notes](#hardware-notes-europa).

## Structure

Each top-level directory is a stow package: its contents mirror `$HOME`, so
`hypr/.config/hypr/general.conf` is symlinked to `~/.config/hypr/general.conf`.

```
.
├── install.sh          # the only command you need
├── scripts/            # install steps, each idempotent and re-runnable
├── assets/             # README screenshots
├── hypr/               # compositor: entry point + modules
├── waybar/             # status bar
├── rofi/               # launcher, power menu (+ vendored Catppuccin palette)
├── mako/               # notifications
├── kitty/              # terminal (+ vendored Catppuccin theme)
├── btop/               # system monitor (+ vendored Catppuccin theme)
├── nvim/               # AstroNvim config
├── hyprlock/           # lock screen
├── hypridle/           # idle handling
├── theme/              # GTK3/GTK4/Qt colours
├── greeter/            # login screen -- copied to /etc, not stowed
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
from distro paths or third-party repos at install time.

<details>
<summary><b>Rofi</b> — vendored palette, and why every element state is styled</summary>
<br/>

The palette lives in `rofi/.config/rofi/catppuccin-mocha.rasi`; the layouts
(`config.rasi` for the launcher, `powermenu.rasi` for the power menu) are ours.

Do *not* point `@theme` at `/usr/share/rofi/themes/` — Ubuntu's rofi ships no
Catppuccin, so that silently falls back to the stock theme.

Both layouts style **every** element state explicitly. Rofi loads its built-in
default theme first, which sets `background: rgba(253,246,227,100%)`
(Solarized light) on `element normal.normal`, and a `*` wildcard block does not
override a selector that specific. Any state left unstyled renders cream on the
dark theme.
</details>

<details>
<summary><b>Power menu</b> — rofi, not wlogout</summary>
<br/>

`rofi/.config/rofi/powermenu.sh`. This is what
[hyprsimple](https://github.com/rizukirr/hyprsimple) actually does — its
`custom/power` calls a rofi script, and the wlogout config in that repo is
vestigial and unused. It's why the menu is a small centred panel rather than a
fullscreen overlay. It reuses the same palette as the launcher, so the two
match by construction.
</details>

<details>
<summary><b>btop</b> — the theme name must be bare, or you get a black box</summary>
<br/>

`color_theme` takes the **bare theme name** — not a path, not with the `.theme`
suffix. `color_theme = "themes/catppuccin_mocha.theme"` is silently ignored:
btop logs nothing, falls back to its built-in default, and the only symptom is
a black background.

`theme_background = False` makes btop draw the terminal's background instead of
the theme's `main_bg`. Beware that it can *mask* the above: with the theme
failing to load, False still yields a Catppuccin-looking background, because
it's kitty's. If btop's colours look off, set it True to see what the theme is
really painting.

The distro package ships no Catppuccin theme, so it's vendored in
`btop/.config/btop/themes/`.
</details>

<details>
<summary><b>GTK / Qt</b> — why nothing is downloaded</summary>
<br/>

Apps like Nautilus link libadwaita, which ignores `gtk-theme-name` entirely —
no GTK theme can touch them. The supported route is overriding libadwaita's
named colours, which `theme/.config/gtk-4.0/gtk.css` does.

This is also why `install-themes.sh` downloads nothing: `catppuccin/gtk` was
archived in June 2024, and it wouldn't have helped here anyway.

GTK3 apps keep Adwaita-dark as a base and get recoloured on top. Qt goes
through qt6ct with a Fusion palette (`QT_QPA_PLATFORMTHEME` is set in
`general.conf`).
</details>

<details>
<summary><b>Wallpaper</b> — hyprpaper ≥ 0.8 changed its config format</summary>
<br/>

`hyprpaper.conf` uses **block syntax**:

```
wallpaper {
    monitor = DP-3
    path = /home/baas/hyprland-dotfiles/wallpapers/mocha-landscape.jpg
    fit_mode = cover
}
```

The older flat form (`preload = ...` / `wallpaper = DP-3,...`) that most guides
still show is *silently ignored* by 0.8 — no error, just no wallpaper. Paths
must be absolute; `~` and `$HOME` are not expanded.

If the wallpaper ever vanishes, run `hyprpaper --verbose` (it logs nothing
without it) and look for `has no target`.
</details>

### Fonts

Configs ask for **`FiraCode Nerd Font`** (UI) and **`FiraCode Nerd Font Mono`**
(terminal/editor). Both names must match `fc-list : family` exactly or the app
silently falls back and icons render as tofu boxes.

- `fonts-firacode` from apt provides **"Fira Code"** — no Nerd glyphs. It is
  not a substitute and is deliberately not installed.

### Icons

> [!IMPORTANT]
> Nerd Font icons are written as **escapes, never literal glyphs**: `\uXXXX` in
> the waybar JSON (regenerate with `json.dump(..., ensure_ascii=True)`) and
> `printf '\uXXXX'` in `powermenu.sh`. Both files are pure ASCII and should stay
> that way — regenerate, don't paste.

Three separate bugs here came from pasted Private Use Area characters silently
becoming nothing:

- waybar's `pulseaudio` and `battery` icons sat in this repo as **empty
  strings** (`["","",""]`), which is why those icons were invisible.
- `powermenu.sh` first shipped with all five menu entries blank.
- The cpu icon came out as U+F075B (a crossed-out music note) instead of the
  intended U+F035B (a chip).

Two traps when picking a codepoint:

- **Existing is not the same as correct.** U+F035B and U+F075B both exist in
  the font; only one is a chip. `fc-list :charset=...` proves nothing about
  which glyph you get. Render it and look:

  ```bash
  magick -background '#1e1e2e' -fill '#cdd6f4' \
    -font ~/.local/share/fonts/NerdFonts/FiraCodeNerdFont-Regular.ttf \
    -pointsize 30 label:"$(printf '\U000f035b')" /tmp/check.png
  ```

- **`\u` takes exactly 4 hex digits.** For codepoints above U+FFFF use `\U`
  with 8: `printf '\uf035b'` yields U+F035 followed by a literal `b`,
  not U+F035B. The icons in `powermenu.sh` are all BMP, so `\u` is right there.

Icon choice is font-specific too: hyprsimple's memory icon (U+F0F86) renders as
a vague swirl in FiraCode, so this config uses U+F1C0 instead.

## Login screen

**greetd** + **nwg-hello**, styled to match hyprlock: same wallpaper, same
Catppuccin palette, same clock and date format, same mauve rounded input
field. `install.sh` switches the display manager from gdm3 automatically.

greetd runs nwg-hello inside a throwaway Hyprland session
(`/etc/nwg-hello/hyprland.conf`), which exits the moment you log in.

**This is the one step here that can leave you without a graphical login, and
it is the one step that could not be tested.** Verifying it needs sudo, which
needs interactive authentication. Before rebooting:

```bash
systemctl status greetd
sudo journalctl -u greetd -b
```

Keep a TTY reachable (Ctrl+Alt+F3) the first time. gdm3 is deliberately left
installed so rolling back is one command, not an apt transaction from a
console:

```bash
sudo systemctl disable greetd
sudo systemctl enable --force gdm3
sudo reboot
```

### The apt error during install is expected

`install.sh` prints this while installing greetd, and it looks worse than it
is:

```
Failed to preset unit: File '/etc/systemd/system/display-manager.service'
already exists and is a symlink to /lib/systemd/system/gdm3.service
deb-systemd-helper: error: systemctl preset failed on greetd.service
```

greetd's postinst tries to claim `display-manager.service` while gdm3 still
owns it. **Nothing is wrong**: the package still configures (`dpkg -l greetd`
shows `ii`), and `install-greeter.sh` takes the alias afterwards with
`systemctl enable --force greetd`. Confirm with:

```bash
readlink -f /etc/systemd/system/display-manager.service   # -> greetd.service
systemctl is-enabled greetd gdm                           # -> enabled, disabled
```

### Why not ly

ly was the original plan, and it does not work here for two independent
reasons. It is **not packaged for Ubuntu 26.04** at any version, so it would
mean carrying a Zig build in `install.sh`. More fundamentally, **ly is a TUI**
— it draws text cells on the Linux console, so it has no images, no wallpaper,
no blur, no rounded corners, and no custom font (it uses the kernel console
font). "Make ly look like hyprlock" is not a hard problem, it is an impossible
one; the closest achievable result is Catppuccin-tinted text. nwg-hello is
GTK3, takes a real wallpaper and a real stylesheet, and is in apt.

### Why `greeter/` is not a stow package

Every other top-level directory mirrors `$HOME` and is symlinked there. The
greeter cannot work that way: greetd runs it as the **`_greetd`** system user
before anyone logs in, and `/home/baas` is mode **750**. `_greetd` cannot even
traverse it. So three things have to be copied out of `$HOME` rather than
linked into it, and `scripts/install-greeter.sh` does that:

- the **config**, to `/etc/nwg-hello/` and `/etc/greetd/` (nwg-hello only ever
  reads `/etc/nwg-hello/`, it has no `$HOME` lookup at all);
- the **wallpaper**, to `/usr/share/nwg-hello/wallpaper.jpg`;
- the **font**, to `/usr/local/share/fonts/`. `FiraCode Nerd Font` lives in
  `~/.local/share/fonts` for the session, where the greeter cannot see it —
  and a font GTK cannot find does not error, it silently falls back.

Files under `greeter/` are the source of truth; the copies in `/etc` are build
output. Edit the former and re-run.

### The form is on DP-3 only, on purpose

`nwg-hello.json` sets `"monitor_nums": [1]`, so the login form appears on DP-3
alone and DP-2 shows a matching flat background. That is not a style choice —
**it is what makes the password field typable.**

nwg-hello builds one window per monitor and *every* window asks
gtk-layer-shell for `keyboard-mode: exclusive`. Two exclusive surfaces cannot
both hold the keyboard, and `main.py` loops `for i in
reversed(range(n_monitors))`, so DP-2 is created last and wins. The first
version of this shipped with the form on both monitors, and typing at DP-3 fed
the *portrait* screen's password field. Measured with each window's
`has_toplevel_focus()`:

| Setting | DP-3 | DP-2 | Result |
|---|---|---|---|
| `"monitor_nums": []` (default) | `False` | `True` | can't type at DP-3 |
| `"form_on_monitors": [1]` | `False` | `True` | worse — focused window is an `EmptyWindow` with no field |
| `"monitor_nums": [1]` | `True` | no surface | works |

`form_on_monitors` reads like the setting for exactly this and does not fix
it: `EmptyWindow` sets the same exclusive keyboard mode as `GreeterWindow`, so
it still steals the keyboard, into a window that has nowhere to type.

The indices are GDK's, and **both panels report the model `LG ULTRAGEAR`**, so
geometry is the only way to tell them apart: index 0 is `1440x2560` (DP-2,
portrait), index 1 is `2560x1440` (DP-3). If the monitors ever change, this
number has to be re-derived — `scripts/install-greeter.sh` carries the
one-liner.

DP-2's colour is `misc:background_color = rgb(292b3f)` in
`/etc/nwg-hello/hyprland.conf`: the wallpaper's mean composited under the CSS
overlay, i.e. what DP-3 actually renders.

### Gotchas found the hard way

- **The CSS selectors are not the glade widget ids.** nwg-hello's template
  calls the clock `lbl-clock`, but GTK3 does *not* use a GtkBuilder id as a
  CSS name — verified: `Gtk.Buildable.get_name()` returns `lbl-clock` while
  `widget.get_name()` returns `GtkLabel`, and a `#lbl-clock` rule matches
  nothing. `ui.py` renames each widget with `set_property("name", ...)`, and
  *those* are the CSS names: `form-wrapper`, `welcome-label`, `clock-label`,
  `date-label`, `form-label`, `form-combo`, `password-entry`, `login-button`,
  `power-button`. Anything else (`lbl-message`, `cb-show-password`) is never
  renamed and has no id selector.
- **A button's `color` does not reach its text.** GtkButton wraps its label in
  a child node, and any rule matching that node beats the colour inherited
  from the button — including `window { color: ... }`. The Login button
  shipped light-on-light until `#login-button label` set it directly.
- **The form is centred by a `<packing>` property, not by CSS.** nwg-hello
  inherits the Sugar Candy layout, which packs the form into a horizontal box
  with `expand=False, fill=False` so it sits against the left edge. `halign`
  and `hexpand` are GtkWidget properties with no CSS equivalent, and setting
  them on the widget does nothing — measured at runtime, `form-wrapper` still
  reported `halign=fill`. Only the child's packing moves it.
- **The blur is not reproduced, and does not need to be.** hyprlock sets
  `blur_passes = 3`, but the wallpaper is a smooth radial gradient with no
  detail — blurring it at sigma 12, 20 and 32 renders indistinguishably. Only
  hyprlock's `brightness = 0.6` is visible, and GTK3 does that itself with an
  overlay layer, so there is no second pre-blurred asset to keep in sync.
- **`_greetd` is not in the `video` group.** Debian's greetd postinst creates
  the account but does not add it, and nwg-hello's own README calls the
  packaging out for this. Without it the greeter cannot open a DRM device:
  black screen at boot. `install-greeter.sh` fixes it.
- **The centred template is generated, not vendored.** `ui.py` calls
  `builder.get_object(...)` on whatever template it is handed, so a stale
  vendored copy missing a widget added by a later nwg-hello returns `None` and
  the greeter dies on startup — which means being unable to log in.
  `scripts/greeter-template.py` derives it from the installed template at
  install time and makes exactly one edit; if that fails it falls back to the
  stock left-aligned layout rather than risking an unbootable greeter.

## Neovim

`install.sh` installs Neovim and syncs plugins headlessly.

Neovim comes from the **upstream tarball**, pinned, into `/opt/nvim` and
symlinked to `/usr/local/bin/nvim` — apt only has 0.11.6, which is older than
this config targets. If `nvim --version` disagrees with
`scripts/install-neovim.sh`, an apt-installed `neovim` is probably shadowing it.

`lua/plugins/{mason,treesitter,none-ls}.lua` are still AstroNvim template
stubs, guarded by `if true then return {} end` on line 1. Delete that line to
activate one — but do it in an interactive nvim, not the install script.

## Hardware notes (europa)

RTX 5070 Ti (Blackwell), driver 595 open modules, two LG UltraGears at
2560x1440@180 with DP-2 rotated to portrait, Endgame Gear OP1 8k mouse.

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
- **Mouse acceleration is off** via `accel_profile = flat` in `general.conf` —
  libinput's 1:1 profile, not `force_no_accel`, which bypasses libinput and is
  discouraged upstream.

## Uninstall

```bash
cd ~/hyprland-dotfiles
stow -D -t "$HOME" hypr waybar rofi mako kitty btop nvim hyprlock hypridle theme
```

<p align="center">
	<img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg?sanitize=true"/>
</p>

<p align="center">
	Palette by <a href="https://github.com/catppuccin/catppuccin">Catppuccin</a> ·
	Inspired by <a href="https://github.com/rizukirr/hyprsimple">hyprsimple</a>
</p>
