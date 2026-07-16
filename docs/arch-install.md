# Installing Arch into free space

Installs Arch onto **unallocated space** on a disk that may already hold other
operating systems, then hands over to the dotfiles' `install.sh` for the desktop.

Written for `europa` (Windows + Ubuntu on one NVMe), but it only assumes *"there
is unallocated space on a GPT disk"*, so it generalises. europa specifics are
called out where they matter.

## Prerequisites

- [ ] Arch ISO on a USB stick, booted.
- [ ] **Dotfiles pushed to GitHub** — branch `arch-linux`, at
      <https://github.com/Benj181/conf-hyprland/tree/arch-linux>.
- [ ] **Windows still boots** — it's your fallback if Arch won't install.
- [ ] You know the firmware boot-menu key (usually F11/F12/Del at POST).
- [ ] Unallocated space on a GPT disk (or a whole empty disk). §1 is how you make
      it if you don't have it yet.
- [ ] Anything you want off the partition you're about to reuse is backed up.

## The three safety rules

Everything below enforces these. The checks *are* the enforcement.

1. **Only write to a partition that is provably empty** — one `blkid` confirms
   holds no filesystem, LVM/RAID member, or swap signature. If anything lives
   there, refuse.
2. **Never modify an existing partition.** The only partition-table write is
   *creating* one in free space. Nothing is deleted, moved, or resized — except
   the one destructive step in §1, which is separate and gated on purpose.
3. **Never format the ESP.** It is shared with Windows. Mount it, read it, leave
   it.

> [!CAUTION]
> **`mkfs` does not prompt.** It won't warn that a filesystem is already there
> and exits 0. The GO check in §3 is the only thing between you and an overwritten
> disk — don't skip it, and don't edit it to pass.

## 0. Inspect the disk

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,PARTUUID /dev/nvme0n1
sudo parted /dev/nvme0n1 unit GB print free
```

europa's layout (measured 2026-07-16):

| Part | Size | Type | Plan |
|---|---|---|---|
| `p1` | 100M | EFI System | **mount, never format** — shared with Windows |
| `p2` | 16M | MS reserved | untouched |
| `p3` | 1.4T | ntfs — **Windows** | untouched |
| `p4` | 894M | Windows recovery | untouched |
| `p6` | 500G | ext4 — **Ubuntu** | **→ becomes the free space** |

Windows is **not** BitLocker-encrypted (`p3` probes as plain `ntfs`), so nothing
here trips an encryption lockout.

## 1. Make free space — the destructive step

**This is the only step that destroys anything. Everything after is guarded.**

On europa, delete Ubuntu's `p6`. It's the **last** partition, so deleting it
leaves one contiguous free region at the end and cannot disturb Windows:

```bash
# Confirm p6 is Ubuntu's 500G ext4 and is NOT mounted:
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/nvme0n1p6

sudo wipefs -a /dev/nvme0n1p6        # clears the ext4 signature
sudo sgdisk --delete=6 /dev/nvme0n1  # destroys Ubuntu
sudo partprobe /dev/nvme0n1
sudo parted /dev/nvme0n1 unit GB print free
```

Expect ~500G free at the end. Windows (`p3`) must still be listed.

> [!IMPORTANT]
> **`wipefs` is mandatory.** Deleting a partition only removes its table entry —
> the old filesystem's superblock stays on those sectors, and the new partition
> in §2 inherits it, so §3 refuses a legitimate install. Wipe it *here*, inside
> the step already gated as destructive — never `wipefs` later to make the guard
> shut up.

Other ways to get free space: reformat an existing Linux partition in place (skip
§1, but §3 will refuse until you're certain — the old filesystem is still there),
shrink Windows **from within Windows** (Disk Management, Fast Startup and
hibernation off), or use a whole empty disk.

## 2. Create the partition

```bash
DISK=/dev/nvme0n1
sudo sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:arch "$DISK"
sudo partprobe "$DISK"
sudo sgdisk -p "$DISK"
```

`--new=0:0:0` = next free number, fill the largest free block. sgdisk allocates
inside free space only and won't overlap an existing partition. `8300` is the
Linux filesystem type code.

**Check:** the Windows and EFI entries must be identical to §0. If anything about
them changed, stop.

## 3. GO / NO-GO check

Set `TARGET` to the partition §2 just created (sgdisk reuses the lowest free
number, so read the table — it's probably `p5`, not `p7`):

```bash
TARGET=/dev/nvme0n1p5      # whatever §2 actually created

ok=1
[ -b "$TARGET" ] || { echo "NO-GO: not a block device"; ok=0; }
usage=$(sudo blkid -p -o value -s USAGE "$TARGET" 2>/dev/null)
[ -z "$usage" ] || { echo "NO-GO: something lives here ($usage) -- refusing"; ok=0; }
findmnt -S "$TARGET" >/dev/null 2>&1 && { echo "NO-GO: it is mounted"; ok=0; }
sudo blkid -p -o value -s PART_ENTRY_NUMBER "$TARGET" >/dev/null 2>&1 \
  || { echo "NO-GO: no GPT entry -- wrong device?"; ok=0; }
lsblk -bno FSTYPE,SIZE "$DISK" | awk '$1=="ntfs" && $2>1e12' | grep -q . \
  || { echo "NO-GO: cannot see Windows' 1.4T ntfs -- WRONG DISK"; ok=0; }
[ "$ok" = 1 ] && echo "GO: $TARGET is empty, unmounted, on the right disk"
```

**If it doesn't print `GO`, stop. Do not edit the check to make it pass.**

The last test asserts a >1TB NTFS is still on this disk — a cheap way to prove
you're not about to install onto the wrong device. On a machine with no Windows,
replace it with something equally distinctive (a serial via `lsblk -dno SERIAL`),
don't delete it. If it says `something lives here (filesystem)` on a partition you
just created, that's the stale superblock from §1 — go back and `wipefs`, don't
override.

(Why `USAGE` and not the exit code: `blkid -p` returns 0 on an empty partition
and 2 on a missing device, so exit codes say the opposite of what you'd assume.
`USAGE` is empty only when nothing is there.)

## 4. Format and mount

```bash
sudo mkfs.ext4 -L arch "$TARGET"
sudo mount "$TARGET" /mnt
sudo mkdir -p /mnt/boot/efi
```

ext4, not btrfs — see [Why ext4](#why-ext4). Then the ESP — **mount only, never
`mkfs` it:**

```bash
sudo mount /dev/nvme0n1p1 /mnt/boot/efi

ls /mnt/boot/efi/EFI    # MUST list Microsoft. If not, wrong partition -- unmount and stop.
findmnt -R /mnt         # confirm the whole layout before handing over
```

## 5. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/arch-linux/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

**Do not pass `--silent`.** The TUI is your last look at the disk config, and
where you set passwords (deliberately not in the file — it's a public repo).

In the TUI:

- **Disk configuration** must say **pre-mounted** / `/mnt`. If it offers to wipe a
  disk or format the ESP, something is wrong — quit and re-check §4. (Pre-mounted
  mode is structurally incapable of touching the partition table — it returns
  before any partitioning code runs.)
- Set the **root password**, and add user **`baas`** with sudo. `hyprpaper.conf`
  hard-codes `/home/baas`, so the username matters.
- Bootloader should read **Grub**.

> [!IMPORTANT]
> The config is written for archinstall **4.4** (`"version": "4.4"`), but the ISO
> ships whatever archinstall is current, and the config schema drifts between
> releases. If archinstall rejects or mis-parses the file, check `archinstall
> --version` and reconcile the config to it — don't assume the file is simply
> wrong.

**Why GRUB, not systemd-boot:** europa's ESP is 100M with ~59M free. systemd-boot
puts the kernel *and* initramfs inside the ESP (Arch's initramfs is 40–90MB, more
with NVIDIA modules, plus a fallback) — it doesn't fit. GRUB keeps them on `/boot`
in the root filesystem. If your ESP is ≥1G, systemd-boot is fine.

## 6. Let GRUB see Windows, then reboot

archinstall doesn't enable os-prober, so GRUB would list Arch only.

```bash
sudo arch-chroot /mnt
grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub \
  || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
# Windows MUST appear in the output. If not, reach it via the firmware boot menu.
exit

sudo umount -R /mnt
reboot          # remove the USB
```

## 7. First boot → the rice

You land at a TTY login — no display manager yet, that's expected; the dotfiles
install it. Continue from the [README → Install](../README.md#install), which
picks up here:

```bash
sudo pacman -Syu                 # confirm network + mirrors work
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
git checkout arch-linux

./install.sh --dry-run           # runs every check, writes nothing
./install.sh --skip-greeter      # packages + configs, no display manager yet
reboot                           # -Syu may have landed a kernel; NVIDIA needs it
```

Then the greeter, deliberately last — see [README → Login screen](../README.md#login-screen):

```bash
Hyprland                         # by hand from the TTY first
nwg-hello -t                     # the greeter, in a window, greetd untouched
./scripts/install-greeter.sh
sudo systemctl start greetd      # live, from a TTY, before committing
```

## Why ext4

Chosen over btrfs. The one thing given up is **snapshots** — a real loss on a
rolling distro, but it matters less here: this system *is* a git repo and one
command, so rebuilding is `./install.sh`, Windows stays bootable as a fallback,
and pacman's cache plus `downgrade` cover most bad updates. In exchange you avoid
btrfs's ENOSPC-on-metadata surprises, its `check --repair` caveat, and CoW
fragmentation.

**Consequence to know:** ext4 only grows *forward*. If you later shrink Windows,
the freed space lands *before* this partition and can't be absorbed without
relocating the whole filesystem. Make that space its own partition mounted at
`/home` or `/mnt/games` instead — a normal layout that costs nothing.

## If it goes wrong

- **Arch won't boot** — Windows still does (firmware boot menu). Re-flash the USB
  and start from §1; the Arch partition is the only thing that changed.
- **GRUB doesn't appear** — firmware boot menu → Windows Boot Manager, then
  `arch-chroot` from the ISO and re-run `grub-install`.
- **greetd comes up black** — at the GRUB menu press `e` and append
  `systemd.unit=multi-user.target` to boot to a TTY with greetd never started.
  See README → Login screen.
- **You want Ubuntu back** — you can't; §1 destroyed it. That's the one
  irreversible thing here, which is why the checklist sits in front of it.

## What's untested

Verified in an Arch VM: package resolution, the GO check against every case, the
config against archinstall 4.4's parser, greetd running nwg-hello as `greeter`,
and `sgdisk --new=0:0:0` filling free space without touching neighbours.

**Not testable without the real hardware** — so §6 and §7 are staged and manual:
the NVIDIA driver, the two monitors, early KMS, GRUB on this firmware, and the
reboot.
