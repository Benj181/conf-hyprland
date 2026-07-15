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
| **Login** | greetd + nwg-hello |
| **Theme** | Catppuccin Mocha, everywhere |

## Install

```bash
git clone git@github.com:Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
./install.sh
```

That's the whole thing — pacman packages, NVIDIA driver, Neovim, Nerd Fonts,
theming, the login screen, and every config symlinked into place with GNU Stow.
Then reboot: the greeter and, if the kernel or NVIDIA driver moved, the driver
both need it.

```bash
./install.sh --dry-run        # report what would change, write nothing
./install.sh --skip-packages  # configs only, skips pacman/AUR/themes/nvim
./install.sh --skip-greeter   # everything except the display manager switch
```

`--dry-run` is worth more than a stow rehearsal here: the AUR and greeter steps
do all their checking with reads, so a dry run actually runs those checks.

Anything already in the way (say, a config from a previous setup) is moved to
`~/.dotfiles-backup-<timestamp>/` rather than overwritten.

> [!IMPORTANT]
> **`pacman -Sy <pkg>` is a partial upgrade and breaks Arch systems.** It
> refreshes the databases, then installs a package built against libraries the
> rest of the system hasn't caught up to. There's no apt analogue — `apt update
> && apt install` is fine, this isn't. So `scripts/packages.sh` puts everything
> in one `pacman -Syu --needed` transaction rather than installing group by
> group. On a fresh install that upgrade is nearly free; on a re-run months
> later it can pull a kernel, and then you reboot before expecting the NVIDIA
> modules to load. `paru -Sy` is the same footgun.

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

Do *not* point `@theme` at `/usr/share/rofi/themes/`. Arch's rofi does ship
themes there, unlike Ubuntu's — which makes the rule *more* worth stating, not
less: a distro theme path is not yours, its contents change under you, and when
the name isn't found rofi falls back to stock without a word. Vendor it.

Both layouts style **every** element state explicitly. Rofi loads its built-in
default theme first, which sets `background: rgba(253,246,227,100%)`
(Solarized light) on `element normal.normal`, and a `*` wildcard block does not
override a selector that specific. Any state left unstyled renders cream on the
dark theme.

> [!NOTE]
> That colour was measured on rofi **1.7** (Ubuntu). Arch ships **2.0**, which
> is a major version and now Wayland-native. The defensive styling stays right
> either way — but if you're checking, re-measure with `rofi -dump-theme`
> rather than trusting the number above. A justification that quietly stopped
> being true is the same failure as a dead selector.
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

The font comes from `ttf-firacode-nerd`. `scripts/packages.sh` verifies both
families with `fc-list` afterwards rather than trusting that the package did
what its name says.

- `ttf-fira-code` provides **"Fira Code"** — no Nerd glyphs. It is not a
  substitute and is deliberately not installed. (Ubuntu's `fonts-firacode` was
  the identical trap under a different name; the packaging changes, the trap
  doesn't.)
- The check is an **exact** match (`grep -Fx`), because `FiraCode Nerd Font` is
  a substring of `FiraCode Nerd Font Mono` — and `ttf-firacode-nerd` ships a
  third `Propo` family besides. A substring test would report success while the
  family you actually need is missing.

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
field. On a minimal Arch install there is no display manager at all, so this
installs the only one rather than replacing anything.

greetd runs nwg-hello inside a throwaway Hyprland session
(`/etc/nwg-hello/hyprland.conf`), which exits the moment you log in.

**This is the one step here that can leave you without a graphical login.**
The plumbing is tested — in an Arch VM greetd starts, runs Hyprland as
`greeter` and launches nwg-hello, with no CSS errors and no missing widgets on
nwg-hello 0.4.5. But a VM has no GPU, and NVIDIA is exactly what it cannot
check. So confirm it here rather than taking it on faith — greetd starts live
from a TTY, and nwg-hello renders in your normal session:

```bash
nwg-hello -t                    # draws the real greeter in a window, as you
./install.sh --skip-greeter     # everything else, no display manager change
sudo systemctl start greetd     # takes vt1; you keep your shell
sudo systemctl stop greetd      # ...and back out
sudo journalctl -u greetd -b
```

`install-greeter.sh` checks rather than assumes: that the CSS selectors still
match nwg-hello's widget names, that `config.toml`'s VT matches what
`greetd.service` keeps clear, that pacman won't clobber the config on upgrade,
that `greeter` can actually read the font and wallpaper, and that the default
target is `graphical.target`. If one of those fires, it is telling you
something real — read it rather than working around it.

#### The default target reaches greetd (checked, not assumed)

`greetd.service` is `WantedBy=graphical.target`, so the default target has to
reach it or `enable` is theatre. On stock Arch it does: systemd ships
`/usr/lib/systemd/system/default.target` → `graphical.target`, and Arch writes
no `/etc/systemd/system/default.target` override, so `get-default` answers
`graphical.target` on a bare install.

Measured in an Arch VM rather than reasoned about — `enable --force` creates
the `display-manager.service` alias, and greetd really does appear under
`systemctl list-dependencies graphical.target`, which is the question that
matters. `systemctl is-enabled` answering `enabled` would not have told you
that.

`install-greeter.sh` still sets the target, because it's free and idempotent
and fixes the case where something explicitly wrote `multi-user.target`. But
it's a no-op on a stock system, not a fix for a known bug.

#### Rolling back is the bootloader, not another greeter

On Ubuntu the escape hatch was `systemctl enable --force gdm3`, because gdm3
was still installed. **There is no second display manager here.** So:

At the boot menu press `e` and append to the kernel line:

```
systemd.unit=multi-user.target
```

That boots to a TTY with greetd never started. Then:

```bash
sudo systemctl disable greetd
sudo systemctl set-default multi-user.target
```

Rehearse reaching that menu **before** you reboot — systemd-boot often hides it
(`timeout 0`) and you may need to hold `Space` during POST. `Ctrl+Alt+F2` also
still works: VT switching is kernel-level and survives a compositor holding the
keyboard. `systemctl enable sshd` first is cheap insurance for one reboot.

### Why not ly

ly was the original plan. **ly is a TUI** — it draws text cells on the Linux
console, so it has no images, no wallpaper, no blur, no rounded corners, and no
custom font (it uses the kernel console font). "Make ly look like hyprlock" is
not a hard problem, it is an impossible one; the closest achievable result is
Catppuccin-tinted text. nwg-hello is GTK3, takes a real wallpaper and a real
stylesheet, and is what makes matching the lock screen possible at all.

This section used to carry a second reason — that ly wasn't packaged for Ubuntu
and would mean vendoring a Zig build. **On Arch that's simply false: ly is in
the repos.** It's retired rather than quietly left standing, because a
justification nobody rechecks is how you end up defending a decision with an
argument that stopped being true. The TUI reason never depended on packaging,
and it was always the decisive one.

### Why `greeter/` is not a stow package

Every other top-level directory mirrors `$HOME` and is symlinked there. The
greeter cannot work that way: greetd runs it as the **`greeter`** system user
before anyone logs in, and `/home/baas` is mode **750**. `greeter` cannot even
traverse it. So two things have to be copied out of `$HOME` rather than linked
into it, and `scripts/install-greeter.sh` does that:

- the **config**, to `/etc/nwg-hello/` and `/etc/greetd/` (nwg-hello only ever
  reads `/etc/nwg-hello/`, it has no `$HOME` lookup at all);
- the **wallpaper**, to `/usr/share/nwg-hello/wallpaper.jpg`.

The **font** used to be a third copy, for the same reason — it lived in
`~/.local/share/fonts`, where the greeter couldn't see it. `ttf-firacode-nerd`
puts it in `/usr/share/fonts`, so there's nothing left to copy. What the copy
was really guarding against still applies, though: a font GTK cannot find does
not error, it silently falls back. So it's replaced by the check the copy never
did — `install-greeter.sh` asks **`greeter`**, not you, whether it can see the
font:

```bash
sudo -u greeter fc-list : family | grep -Fx "FiraCode Nerd Font"
```

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
- **`greeter` must be in the `video` group**, or it cannot open a DRM device:
  black screen at boot. Arch's greetd does handle this — its sysusers file
  carries `m greeter video`, verified — whereas Debian's postinst didn't, which
  is why `install-greeter.sh` grew the check. It's kept because it checks
  membership before adding, so it's a no-op here and a fix elsewhere. `id
  greeter` tells you which.
- **The centred template is generated, not vendored.** `ui.py` calls
  `builder.get_object(...)` on whatever template it is handed, so a stale
  vendored copy missing a widget added by a later nwg-hello returns `None` and
  the greeter dies on startup — which means being unable to log in.
  `scripts/greeter-template.py` derives it from the installed template at
  install time and makes exactly one edit; if that fails it falls back to the
  stock left-aligned layout rather than risking an unbootable greeter.

## Neovim

`install.sh` installs Neovim and syncs plugins headlessly.

Neovim is just a package: `extra/neovim` is **0.12.4**, which is what this
config targets. It used to be an upstream tarball pinned into `/opt/nvim` and
symlinked onto `PATH`, because apt only had 0.11.6 — on Arch that whole
apparatus, and the PATH-shadowing problem it created, is gone.

`lua/plugins/{mason,treesitter,none-ls}.lua` are still AstroNvim template
stubs, guarded by `if true then return {} end` on line 1. Delete that line to
activate one — but do it in an interactive nvim, not the install script.

## Hardware notes (europa)

RTX 5070 Ti (Blackwell), `nvidia-open`, two LG UltraGears at 2560x1440@180
with DP-2 rotated to portrait, Endgame Gear OP1 8k mouse.

- **Blackwell is open-kernel-module only.** `nvidia-open` is named outright in
  `scripts/packages.sh`; there is no proprietary variant to choose.
- **The driver package is coupled to the kernel.** `nvidia-open` is prebuilt
  for the stock `linux` kernel. Change the kernel and this must change with it:
  `linux-lts` → `nvidia-open-lts`, anything else → `nvidia-open-dkms` plus the
  matching headers. And after any `pacman -Syu` that lands a kernel, **reboot**
  — the running kernel's modules go away with it.
- **`nvidia-drm.modeset=1` is not needed.** It's default-on for this driver —
  there is no such kernel parameter set here and no
  `/sys/module/nvidia_drm/parameters/modeset` knob, and Hyprland runs fine.
  Ignore older guides insisting on it.
- **Early KMS is a different question, and it is not settled here.** The bullet
  above is about a kernel *parameter*; early KMS is about loading the NVIDIA
  modules from the *initramfs* (`MODULES=(nvidia nvidia_modeset nvidia_uvm
  nvidia_drm)` in `/etc/mkinitcpio.conf`, then `mkinitcpio -P`). Ubuntu's
  packaging handled the initramfs; Arch's does not, and missing early KMS is a
  classic cause of a black screen *specifically at a display manager* — i.e.
  exactly the riskiest step in this repo. Nothing here configures it. If greetd
  comes up black while `nwg-hello -t` works fine in a session, start here.
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

That unlinks the configs. It does **not** touch the login screen, which isn't a
stow package — and unstowing while greetd is still your only display manager
leaves you logging into a session whose config just vanished. Undo that part
separately, and before you reboot:

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
