# Installing Arch on europa

Replacing Ubuntu with Arch on a disk that **also has Windows on it**. Windows is
never touched. Read this before running anything.

## The one thing that makes this safe

**No partition is created, deleted, moved, or resized.** Not one byte of the
partition table changes.

Ubuntu already lives on a 500G partition at the end of the disk, and its type is
already `Linux filesystem`. So Arch doesn't need a new partition — it reuses
that one. The only destructive act is `mkfs` on that single partition, which
overwrites Ubuntu's filesystem and nothing else.

That means no `fdisk`, no `parted`, no `cfdisk`, no gparted, and no chance of a
wrong partition number.

## The disk

Measured on the live system, 2026-07-16:

| Part | Range | Size | Type | What | Plan |
|---|---|---|---|---|---|
| `p1` | 0.0–0.1G | 100M | EFI System | **shared ESP** — Windows + Ubuntu | **mount, never format** |
| `p2` | 0.1–0.1G | 16M | MS reserved | Windows | untouched |
| `p3` | 0.1–1406.1G | **1.4T** | ntfs | **Windows** | untouched |
| `p4` | 1406.1–1407.0G | 894M | ntfs | Windows recovery | untouched |
| `p6` | 1407.0–1907.0G | **500G** | ext4 | **Ubuntu /** | **← reformat, this one only** |

Windows is **not** BitLocker-encrypted (`p3` probes as plain `ntfs`), so nothing
here can trip an encryption lockout.

**The target is identified by PARTUUID, not by device name:**

```
PARTUUID  d03c7c95-fdf4-43d4-924d-cb56bec0367e     <- Ubuntu's 500G partition
```

Use this, not `/dev/nvme0n1p6`. Device names are assigned at boot and the ISO
may enumerate differently; PARTUUID lives in the GPT and cannot drift. It also
survives the reformat unchanged (only the *filesystem* UUID changes).

> [!WARNING]
> The ESP (`p1`) contains `EFI/Microsoft`. **Formatting it un-boots Windows.**
> archinstall's normal disk flow offers to format the ESP. That is why this
> procedure never lets archinstall near the partition table — see below.

## Why btrfs

You asked whether you could later take space from Windows and give it to Arch.
With ext4 you couldn't, easily: shrinking Windows frees space *before* Arch's
partition, and ext4 only grows forward, so you'd have to physically relocate
500G. With btrfs it's two online commands, no data moved:

```bash
# LATER, only if you shrink Windows and make a new partition, e.g. p5:
sudo btrfs device add /dev/disk/by-partuuid/<new> /
sudo btrfs filesystem balance start -dconvert=single /
```

Btrfs also gives snapshots, which is a real rollback for Arch itself — worth
having, since the NVIDIA and greeter paths are the parts that couldn't be
tested before this machine.

## Before you boot the ISO

- [ ] **The dotfiles are on GitHub.** Branch `arch-linux`. Confirm at
      <https://github.com/Benj181/conf-hyprland/tree/arch-linux>. Once `p6` is
      formatted, anything not pushed is gone.
- [ ] **Anything else in `/home/baas` you want** is backed up somewhere that is
      not `p6`. The 2TB `sda` drive and the Windows partition both survive, but
      nothing is copied for you.
- [ ] **You can boot Windows.** It is your fallback: if Arch won't install, you
      still have a working OS to search from and re-flash a USB with.
- [ ] Know how to reach the **boot menu** (the firmware one, usually F11/F12/Del
      at POST). You will need it to pick the USB, and later to pick between Arch
      and Windows if GRUB misbehaves.

## 1. Boot the ISO

Boot the `ARCH_202607` USB in **UEFI** mode (not Legacy/CSM). Then:

```bash
# Network. Wired should already work; for wifi:
iwctl station wlan0 connect <SSID>
ping -c1 archlinux.org

# Confirm you booted UEFI. If this says "No such file", stop --
# you booted Legacy and GRUB will install wrong.
ls /sys/firmware/efi >/dev/null && echo UEFI OK
```

## 2. Verify the target — do this properly

This is the step that prevents a disaster. Do not skip it, do not eyeball it.

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,PARTUUID /dev/nvme0n1
```

Read the output and confirm **all** of these before continuing:

- the partition with PARTUUID `d03c7c95-fdf4-43d4-924d-cb56bec0367e` is **500G**
  and **ext4** — that is Ubuntu;
- there is a **1.4T ntfs** partition — that is Windows, and you are not going to
  touch it;
- the **100M vfat** EFI partition exists.

If any of that does not match, **stop and ask**. The disk is not what this
document describes.

Now pin the target to a variable, so no later command names a device by hand:

```bash
TARGET=/dev/disk/by-partuuid/d03c7c95-fdf4-43d4-924d-cb56bec0367e

# Prove it resolves to the 500G ext4 partition and nothing else:
lsblk -o NAME,SIZE,FSTYPE "$(readlink -f $TARGET)"
```

If that prints anything other than a 500G ext4 partition, **stop**.

## 3. The only destructive command

```bash
mkfs.btrfs -f -L arch "$TARGET"
```

That is it. That is the whole of the destruction. Ubuntu is now gone; Windows,
the ESP, and the partition table are exactly as they were.

## 4. Subvolumes and mounting

Btrfs subvolumes, laid out so snapshots of `/` don't drag your home or the
package cache with them:

```bash
mount "$TARGET" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt

O=noatime,compress=zstd:3,ssd,space_cache=v2
mount -o $O,subvol=@           "$TARGET" /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots,boot/efi}
mount -o $O,subvol=@home       "$TARGET" /mnt/home
mount -o $O,subvol=@log        "$TARGET" /mnt/var/log
mount -o $O,subvol=@pkg        "$TARGET" /mnt/var/cache/pacman/pkg
mount -o $O,subvol=@snapshots  "$TARGET" /mnt/.snapshots
```

Then the ESP. **Mount only. Never `mkfs` this one** — Windows boots from it:

```bash
mount /dev/disk/by-partuuid/$(lsblk -no PARTUUID /dev/nvme0n1p1) /mnt/boot/efi

# Sanity check: this MUST list Microsoft. If it doesn't, you mounted the
# wrong thing -- unmount and stop.
ls /mnt/boot/efi/EFI
#   Boot  Microsoft  ubuntu   <- expected. Microsoft present = correct ESP.
```

Confirm the whole layout before handing over to archinstall:

```bash
findmnt -R /mnt
```

## 5. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/arch-linux/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

**Do not pass `--silent`.** The config pre-fills everything; the TUI then lets
you review it and set passwords. Passwords are deliberately not in the file —
it lives in a public repo.

In the TUI:

- **Disk configuration** must say **pre-mounted** / `/mnt`. If it offers to wipe
  a disk or format the ESP, something is wrong — quit and re-check step 4.
- Set the **root password**, and add user **`baas`** with sudo. The repo
  hard-codes `/home/baas` in `hyprpaper.conf`, so the username matters.
- Bootloader should read **Grub**.

Why pre-mounted mode: archinstall's `pre_mounted_config` path detects what you
mounted and installs into it. Read from its source, it returns *before* any
partitioning code and never reads a `wipe` flag. It is structurally incapable of
touching your partition table. That's the guarantee, not a promise.

Why GRUB and not archinstall's default systemd-boot: **your ESP is 100M with
59M free.** systemd-boot puts the kernel *and* initramfs inside the ESP; Arch's
initramfs is ~40–90MB, more with NVIDIA modules, plus a fallback image. It will
not fit. GRUB keeps them on `/boot` inside the btrfs root and needs only a small
stub in the ESP. Ubuntu did the same, which is why 38M was enough for it.

## 6. Before you reboot — make GRUB see Windows

archinstall does not enable os-prober, so GRUB's menu will list Arch only.

```bash
arch-chroot /mnt
grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub \
  || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Windows MUST appear in the output. If it doesn't, you get an Arch-only menu
# and reach Windows via the firmware boot menu instead -- annoying, not fatal.
exit
```

Then:

```bash
umount -R /mnt
reboot     # remove the USB
```

## 7. First boot, then the rice

You should land at a TTY login (no display manager yet — that's expected, the
dotfiles install it).

```bash
sudo pacman -Syu                 # confirm network + mirrors work
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
git checkout arch-linux

./install.sh --dry-run           # runs every check, writes nothing
./install.sh --skip-greeter      # packages + configs, no display manager yet
reboot                           # -Syu may have landed a kernel; NVIDIA needs it
```

Then follow **README → Login screen** for the greeter, which is deliberately the
last step and the one to take slowly:

```bash
Hyprland                         # by hand from the TTY first
nwg-hello -t                     # the greeter, in a window, greetd untouched
./scripts/install-greeter.sh
sudo systemctl start greetd      # live, from a TTY, before committing
```

## If it goes wrong

**Arch won't boot.** Windows still does — pick it from the firmware boot menu.
Then re-flash the USB and try again from step 1. `p6` is the only thing that
changed and it's already expendable.

**GRUB doesn't appear at all.** Firmware boot menu → Windows Boot Manager. Then
from the ISO, `arch-chroot` back in and re-run `grub-install`.

**greetd comes up black.** The README's Login screen section covers this; the
rollback is appending `systemd.unit=multi-user.target` at the GRUB menu (press
`e`), which gets you a TTY with greetd never started.

**You want Ubuntu back.** You can't — `p6` was overwritten. That's the one
irreversible thing here, and it's why the checklist at the top exists.

## What is untested

Everything up to and including `install.sh` was tested in an Arch VM (qemu/KVM):
all 482 packages resolve, greetd starts and runs nwg-hello as `greeter`, and the
config in this directory parses against archinstall 4.4's own parser.

**Not tested, and not testable without your hardware:** the NVIDIA driver, your
two monitors, early KMS, GRUB on this specific firmware, the ESP being large
enough in practice, and the reboot. Those are exactly why steps 6 and 7 are
manual and staged rather than one unattended script.
