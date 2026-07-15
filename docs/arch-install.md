# Installing Arch into free space

Installs Arch onto **unallocated space** on a disk that may already hold other
operating systems, then hands over to `install.sh` for the desktop.

Written for `europa` (Windows + Ubuntu on one NVMe), but the procedure only
assumes *"there is unallocated space on a GPT disk"*, so it generalises. The
europa specifics are called out where they exist.

## The safety model

Three rules. Everything below enforces them, and the checks are the enforcement
— not the prose.

1. **Only ever write to a partition that is provably empty.** Not "the one I
   meant", not "the one at that PARTUUID" — one that `blkid` confirms holds no
   filesystem, no LVM/RAID member, no swap signature. If anything lives there,
   refuse.
2. **Never modify an existing partition.** The only partition-table write is
   *creating* one in free space. Nothing is deleted, moved, or resized.
3. **Never format the ESP.** It is shared with Windows. Mount it, read it,
   leave it.

The one destructive act in this document is making the free space in the first
place (§1) — and that is deliberately a separate, explicit step, because it is
the only place your data is at risk.

> [!CAUTION]
> **`mkfs` does not ask you anything.** It will not warn that a filesystem is
> already there, will not prompt, and exits 0. Verified — an earlier draft of
> this document claimed a confirmation prompt existed. It does not. The `GO`
> check in §3 is the only thing between you and an overwritten disk.

## 0. The disk (europa, measured 2026-07-16)

| Part | Range | Size | Type | Plan |
|---|---|---|---|---|
| `p1` | 0.0–0.1G | 100M | EFI System | **mount, never format** — shared with Windows |
| `p2` | 0.1–0.1G | 16M | MS reserved | untouched |
| `p3` | 0.1–1406.1G | **1.4T** | ntfs — **Windows** | untouched |
| `p4` | 1406.1–1407.0G | 894M | Windows recovery | untouched |
| `p6` | 1407.0–1907.0G | **500G** | ext4 — **Ubuntu** | **→ becomes the free space** |

Windows is **not** BitLocker-encrypted (`p3` probes as plain `ntfs`), so nothing
here trips an encryption lockout.

Check your own before starting:

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,PARTUUID /dev/nvme0n1
sudo parted /dev/nvme0n1 unit GB print free
```

## 1. Get unallocated space — the destructive step

**This is the only step that destroys anything. Everything after it is guarded.**

Before you run it:

- [ ] **Dotfiles are on GitHub** — branch `arch-linux`, at
      <https://github.com/Benj181/conf-hyprland/tree/arch-linux>.
- [ ] **Anything else you want from `/home/baas` is off this partition.**
- [ ] **You can boot Windows.** It is your fallback if Arch won't install.
- [ ] You know how to reach the firmware boot menu (usually F11/F12/Del at POST).

On europa the free space is made by deleting Ubuntu's `p6`. It is the **last**
partition on the disk, so deleting it leaves one contiguous free region at the
end and cannot disturb Windows:

```bash
# Confirm p6 is Ubuntu's 500G ext4 and is NOT mounted:
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/nvme0n1p6

sudo wipefs -a /dev/nvme0n1p6           # <- clears the ext4 signature
sudo sgdisk --delete=6 /dev/nvme0n1     # <- destroys Ubuntu
sudo partprobe /dev/nvme0n1
sudo parted /dev/nvme0n1 unit GB print free
```

> [!IMPORTANT]
> **The `wipefs` is not optional, and it is not cosmetic.** Deleting a partition
> only removes its *entry* from the table — the filesystem's data, including its
> superblock, is still on those sectors. The new partition in §2 starts at the
> same place, so it inherits the old signature, and §3's "must be empty" check
> then refuses a perfectly legitimate install. Verified: without this line, the
> flow below stops with `NO-GO: something lives here (filesystem)`.
>
> Wiping *here*, inside the step already marked destructive and gated by the
> checklist, is what lets §3 be a real check rather than one you learn to
> override. Never `wipefs` a partition to make the guard shut up.

Expect ~500GB of free space at the end. Windows (`p3`) must still be listed.

> [!NOTE]
> **If you are replacing an existing Linux partition and want the least risk
> possible, skip this step.** You do not have to delete and recreate: you can
> reformat the old partition in place and never touch the partition table at
> all. Jump to §3 with `TARGET` set to that partition — but then §3's "must be
> empty" check *will* refuse, because the old filesystem is still there, and you
> must be certain before overriding it. Deleting first is slower and safer,
> because it makes the emptiness real rather than asserted.

Other ways to get free space: shrink Windows **from within Windows** (Disk
Management, with Fast Startup and hibernation disabled — never with
`ntfsresize` on a volume Windows left dirty), or use a whole empty disk.

## 2. Create the partition

```bash
DISK=/dev/nvme0n1

sudo sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:arch "$DISK"
sudo partprobe "$DISK"
```

`--new=0:0:0` means: next free partition number, and **fill the largest free
block**. sgdisk will not overlap an existing partition — it allocates inside
free space only. `8300` is the Linux filesystem type code.

Verify that existing partitions are untouched and note the new number:

```bash
sudo sgdisk -p "$DISK"
```

The Windows and EFI entries must be **identical** to §0. If anything about them
changed, stop.

## 3. GO / NO-GO — the check that protects you

Set `TARGET` to the partition you just created (`p5` here — sgdisk reuses the
lowest free number, so it is probably *not* `p7`; read the table above rather
than assuming):

```bash
TARGET=/dev/nvme0n1p5      # <- whatever §2 actually created

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

**If it does not print `GO`, stop. Do not edit the check to make it pass.**

That last line is the europa-specific one: it asserts a >1TB NTFS is still on
this disk, which is a cheap way of proving you are not about to install onto the
wrong device entirely. On a machine with no Windows, replace it with something
equally distinctive about the right disk (a serial via `lsblk -dno SERIAL`, say)
rather than deleting it — an unconditional `GO` is not a check.

If §3 says `NO-GO: something lives here (filesystem)` on a partition you just
created, that is almost always the stale superblock of whatever used to occupy
those sectors — see the `wipefs` note in §1. Go back and understand *what* it
found before you clear it. That message doing its job is the entire point.

Why `USAGE` and not the exit code: `blkid -p` returns **0 on an empty
partition** (it reports the GPT entry, not a filesystem) and **2 on a
non-existent device** — so exit codes say the opposite of what you'd assume.
`USAGE` is empty only when nothing is there, and is non-empty for filesystems
(`filesystem`), LVM/RAID members (`raid`) and swap (`other`). All six cases
verified.

## 4. Format and mount

```bash
sudo mkfs.ext4 -L arch "$TARGET"

sudo mount "$TARGET" /mnt
sudo mkdir -p /mnt/boot/efi
```

ext4 rather than btrfs — see [Why ext4](#why-ext4-and-what-it-costs).

Then the ESP. **Mount only. Never `mkfs` this one:**

```bash
sudo mount /dev/nvme0n1p1 /mnt/boot/efi

# MUST list Microsoft. If it doesn't, you mounted the wrong thing -- unmount
# and stop.
ls /mnt/boot/efi/EFI
#   Boot  Microsoft  ubuntu
```

Confirm the whole layout before handing over:

```bash
findmnt -R /mnt
```

## 5. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/arch-linux/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

**Do not pass `--silent`.** The config pre-fills everything; the TUI is your
last look at the disk config before it commits, and where you set passwords —
which are deliberately not in the file, because it lives in a public repo.

In the TUI:

- **Disk configuration** must say **pre-mounted** / `/mnt`. If it offers to wipe
  a disk or format the ESP, something is wrong — quit and re-check §4.
- Set the **root password**, and add user **`baas`** with sudo. The repo
  hard-codes `/home/baas` in `hyprpaper.conf`, so the username matters.
- Bootloader should read **Grub**.

**Why pre-mounted mode:** the config uses `pre_mounted_config`. Read from
archinstall 4.4's source, that path calls `detect_pre_mounted_mods()` and
returns *before* any partitioning code, never reading a `wipe` flag. It is
structurally incapable of touching your partition table. That is the guarantee
— not a promise.

**Why GRUB, not archinstall's default systemd-boot:** europa's **ESP is 100M
with 59M free**. systemd-boot puts the kernel *and* initramfs inside the ESP;
Arch's initramfs is ~40–90MB, more with NVIDIA modules for early KMS, plus a
fallback image. It does not fit. GRUB keeps them on `/boot` inside the root
filesystem and needs only a small stub in the ESP — which is why 38M was enough
for Ubuntu. If your ESP is ≥1G, systemd-boot is fine and this doesn't apply.

## 6. Before rebooting — let GRUB see Windows

archinstall does not enable os-prober, so GRUB would list Arch only.

```bash
sudo arch-chroot /mnt
grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub \
  || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
# Windows MUST appear in the output. If not, you reach it via the firmware
# boot menu instead -- annoying, not fatal.
exit
```

```bash
sudo umount -R /mnt
reboot          # remove the USB
```

## 7. First boot, then the rice

You land at a TTY login. No display manager yet — that is expected; the dotfiles
install it.

```bash
sudo pacman -Syu                 # confirm network + mirrors work
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
git checkout arch-linux

./install.sh --dry-run           # runs every check, writes nothing
./install.sh --skip-greeter      # packages + configs, no display manager yet
reboot                           # -Syu may have landed a kernel; NVIDIA needs it
```

Then the greeter, deliberately last and slowly — see **README → Login screen**:

```bash
Hyprland                         # by hand from the TTY first
nwg-hello -t                     # the greeter, in a window, greetd untouched
./scripts/install-greeter.sh
sudo systemctl start greetd      # live, from a TTY, before committing
```

## Why ext4, and what it costs

ext4, chosen deliberately over btrfs. The one thing given up is **snapshots** —
a real loss on a rolling distro, where a bad `pacman -Syu` can break the boot.
It matters less here than elsewhere: this system *is* a git repo and one
command, so rebuilding is `./install.sh` rather than a lost weekend. Windows
stays bootable as a fallback, and pacman's cache plus `downgrade` cover most bad
updates.

What ext4 avoids in exchange: btrfs's free-space accounting (`df` can report
space free while the filesystem returns ENOSPC on metadata exhaustion), a
`check --repair` that ships with a "don't run this" warning next to `e2fsck`'s
thirty years of hardening, CoW fragmentation on VM images and databases, and
subvolume/balance/scrub concepts that earn nothing if you never snapshot.

**The consequence to know about:** ext4 only grows *forward*. If you later shrink
Windows, the freed space lands *before* this partition, and growing into it
would mean physically relocating the whole filesystem — hours, and a power cut
loses it. Don't. Make the freed space its own partition and mount it at `/home`
or `/mnt/games` instead; that is a normal layout, costs nothing, and is probably
what you'd want anyway. You would have to grow from 46G to 500G before it is
even a question.

## If it goes wrong

**Arch won't boot.** Windows still does — firmware boot menu. Re-flash the USB
and start again from §1. The Arch partition is the only thing that changed.

**GRUB doesn't appear at all.** Firmware boot menu → Windows Boot Manager. Then
from the ISO, `arch-chroot` back in and re-run `grub-install`.

**greetd comes up black.** README → Login screen. The rollback is appending
`systemd.unit=multi-user.target` at the GRUB menu (press `e`), which gets you a
TTY with greetd never started.

**You want Ubuntu back.** You can't — §1 destroyed it. That is the one
irreversible thing here, and why the checklist is where it is.

## What is untested

Tested in an Arch VM (qemu/KVM): all 482 packages resolve; greetd starts and
runs nwg-hello as `greeter`; the config parses against archinstall 4.4's own
parser; `sgdisk --new=0:0:0` fills free space without touching neighbours; the
`GO` check was verified against every case (empty, filesystem, LVM member, swap,
missing device) and against this machine's real partition table.

**Not tested, and not testable without your hardware:** the NVIDIA driver, your
two monitors, early KMS, GRUB on this firmware, and the reboot. Those are why §6
and §7 are staged and manual rather than one unattended script.
