# hyprland-dotfiles

Personal Hyprland setup, structured to be reproducible on any new machine
(NVIDIA desktop or Intel/AMD-igpu laptop) with one command.

## Structure

```
.
├── install.sh                  # stows configs + links the right machine.conf
├── scripts/
│   └── bootstrap-packages.sh   # apt installs, run once on a fresh machine
├── hypr/.config/hypr/
│   ├── hyprland.conf           # entry point, only `source =` lines
│   ├── general.conf            # GPU-agnostic look/feel
│   ├── keybinds.conf           # GPU-agnostic keybinds
│   ├── windowrules.conf        # GPU-agnostic window rules
│   ├── autostart.conf          # GPU-agnostic autostart apps
│   └── machine/
│       ├── nvidia-desktop.conf # NVIDIA env vars, monitor layout, render opts
│       └── laptop-igpu.conf    # power mgmt, monitor layout, lid switch
├── waybar/.config/waybar/      # status bar, GPU-agnostic
└── rofi/.config/rofi/          # launcher, GPU-agnostic
```

The split is deliberate: everything that's the same across machines lives in
the top-level `hypr/.config/hypr/*.conf` files. Everything that differs
(GPU env vars, monitor layout, power management) lives in `machine/*.conf`,
and `hyprland.conf` always sources a generic `machine.conf` symlink that
`install.sh` points at the right file. This means the bulk of the repo
never needs to change when you add a new machine -- you only ever add a
new file under `machine/`.

## Bringing up a brand-new machine

```bash
git clone <this-repo-url> ~/hyprland-dotfiles
cd ~/hyprland-dotfiles

# 1. Install packages (adjust driver version in the script if needed)
./scripts/bootstrap-packages.sh nvidia-desktop   # or: laptop-igpu

# 2. Reboot if the NVIDIA driver was just installed
sudo reboot

# 3. Symlink dotfiles into place
./install.sh nvidia-desktop                      # or: laptop-igpu

# 4. Log out, pick Hyprland in your display manager, log in
```

If you omit the profile argument to `install.sh`, it tries to guess from
`hostname` (matching on "nvidia"/"desktop" or "laptop") and otherwise asks
interactively -- but explicit is safer, especially the first time.

## Adding a third machine

1. Create `hypr/.config/hypr/machine/<name>.conf` with whatever's specific
   to that box (monitor line at minimum).
2. Add a case for it in `scripts/bootstrap-packages.sh` if it needs
   different packages.
3. Run `./install.sh <name>`.

## NVIDIA-specific notes (desktop)

- Requires driver **555 or newer** for explicit sync support in wlroots-based
  compositors. Check with `nvidia-smi`.
- On Turing (RTX 20-series) and newer, prefer the **open kernel modules**
  (`nvidia-driver-570-open` or similar) -- noticeably fewer Wayland quirks
  than the proprietary blob.
- Confirm `nvidia-drm.modeset=1` is set. Check:
  ```bash
  cat /sys/module/nvidia_drm/parameters/modeset
  ```
  If it prints `N` instead of `Y`, add it as a kernel parameter:
  ```bash
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
  sudo update-grub
  sudo reboot
  ```
- If you see cursor corruption/lag, toggle `WLR_NO_HARDWARE_CURSORS` in
  `machine/nvidia-desktop.conf` (commented out by default -- try without it
  first on driver 555+, since it's often no longer needed and hardware
  cursors have lower latency when they work).

## Laptop with hybrid graphics (Optimus)?

`laptop-igpu.conf` assumes **integrated graphics only**. If a laptop has
both an integrated GPU and a discrete NVIDIA GPU (common on gaming
laptops), that's a different setup entirely -- you'd want a
`laptop-hybrid.conf` with PRIME offload env vars (`__NV_PRIME_RENDER_OFFLOAD`,
`__GLX_VENDOR_LIBRARY_NAME`, etc.) and possibly `nvidia-prime`/`optimus-manager`
installed. Ask if/when this applies and it's worth its own machine profile.

## Uninstalling / unstowing

```bash
cd ~/hyprland-dotfiles
stow -D -t "$HOME" hypr waybar rofi
```
