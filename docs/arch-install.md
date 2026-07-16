# Installing Arch into free space

Installs Arch onto a GPT disk that already holds **another OS (or data you want to
keep)**, into free space, without disturbing what's already there. Then it hands
over to the dotfiles' `install.sh` for the desktop.

`europa` (Windows plus an old Linux install on one NVMe) is the worked example — **substitute your
own disk and partition names throughout**; the doc sets them as variables so you
only type each once. The other OS doesn't have to be Windows, and there doesn't
have to be a second one.

> [!NOTE]
> **Empty disk, nothing to preserve?** You don't need the guards below — run
> archinstall's normal guided install and let it wipe and partition the disk.
> This doc exists for the harder case where something on the disk must survive.

## Prerequisites

- [ ] Arch ISO on a USB stick, **booted in UEFI mode** (pick the `UEFI:` entry
      for the stick in the firmware boot menu). If you use Secure Boot, turn it
      **off** for now — see [Secure Boot](#secure-boot).
- [ ] **Dotfiles pushed to GitHub** — <https://github.com/Benj181/conf-hyprland>.
- [ ] **A fallback you can boot** — your existing OS if you dual-boot, or just a
      way to re-flash the USB and retry. Confirm you can reach it.
- [ ] You know the firmware boot-menu key (usually F11/F12/Del at POST).
- [ ] A GPT disk with free space, or a partition/disk you're willing to erase to
      make some (§1).
- [ ] Anything you want off the partition you're about to reuse is backed up.

## The three safety rules

Everything below enforces these. The checks *are* the enforcement.

1. **Only write to a partition that is provably empty** — one `blkid` confirms
   holds no filesystem, LVM/RAID member, or swap signature. If anything lives
   there, refuse.
2. **Never modify an existing partition.** The only partition-table write is
   *creating* one in free space. Nothing is deleted, moved, or resized — except
   the one destructive step in §1, which is separate and gated on purpose.
3. **Never format an ESP you didn't create.** If it's shared with another OS,
   formatting it destroys that OS's boot files. Mount it, read it, leave it.

> [!CAUTION]
> **`mkfs` does not prompt.** It won't warn that a filesystem is already there
> and exits 0. The GO check in §3 is the only thing between you and an overwritten
> disk — don't skip it, and don't edit it to pass.

## 0. Inspect the disk and set your variables

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT,SERIAL
```

Read your layout off that and identify four things:

- the **disk** you're installing to (`/dev/nvme0n1`, `/dev/sda`, …)
- its **ESP** — the *EFI System* partition (usually 100–500M, FAT). It already
  exists if any UEFI OS is installed. **No ESP at all? see §4.**
- the **partitions to keep** — every other OS or data partition
- your **free space** — either existing unallocated space, or a partition you'll
  erase to make it (§1)

Set these now; the rest of the doc uses them:

```bash
DISK=/dev/nvme0n1          # the whole disk, NOT a partition
ESP=/dev/nvme0n1p1         # the EFI System partition
EXPECT_SERIAL=23180XXXXXXX # the SERIAL of $DISK from the table above — §3 checks it
```

europa's layout, as an example (measured 2026-07-16):

| Part | Size | Type | Plan |
|---|---|---|---|
| `p1` | 100M | EFI System | **mount, never format** — shared with Windows |
| `p2` | 16M | MS reserved | untouched |
| `p3` | 1.4T | ntfs — **Windows** | untouched |
| `p4` | 894M | Windows recovery | untouched |
| `p6` | 500G | ext4 — **old Linux** | **→ becomes the free space** |

> [!NOTE]
> Dual-booting **BitLocker-encrypted** Windows? A partition or boot change can
> trip a recovery-key prompt — disable BitLocker in Windows first. europa's
> Windows probes as plain `ntfs`, so it doesn't.

## 1. Make free space — the destructive step

**This is the only step that destroys anything. Everything after is guarded.**
Already have unallocated space? Skip to §2.

Otherwise, free a partition you no longer need. Set `OLD` to it, confirm it's
really the one you mean and is **not mounted**, then wipe and delete it:

```bash
OLD=/dev/nvme0n1p6         # the partition you're freeing — set this to YOURS

# Confirm it: right size, right filesystem, empty MOUNTPOINT column:
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$OLD"

N=$(sudo blkid -p -o value -s PART_ENTRY_NUMBER "$OLD")   # its GPT number, read off the device
echo "About to wipe $OLD and delete partition $N from $DISK"   # <- read this line before continuing

sudo wipefs -a "$OLD"              # clears the old filesystem signature
sudo sgdisk --delete="$N" "$DISK"  # removes the partition
sudo partprobe "$DISK"
sudo parted "$DISK" unit GB print free
```

Deriving `N` with `blkid` (rather than parsing `p6` out of the name) is on
purpose: naming differs across hardware — `nvme0n1p6` vs `sda6` — and the GPT
entry number read off the device can't disagree with the partition you set.

Expect the partition's space to show as free, and every kept partition still
listed. `sgdisk --new` in §2 fills the largest free block, so it doesn't matter
whether the freed region is at the end of the disk or in the middle.

> [!IMPORTANT]
> **`wipefs` is mandatory.** Deleting a partition only removes its table entry —
> the old filesystem's superblock stays on those sectors, and the new partition
> in §2 inherits it, so §3 refuses a legitimate install. Wipe it *here*, inside
> the step already gated as destructive — never `wipefs` later to make the guard
> shut up.

Other ways to get free space: reformat an existing partition in place (skip §1,
but §3 will refuse until you're certain — the old filesystem is still there),
shrink Windows **from within Windows** (Disk Management, Fast Startup and
hibernation off), or use a whole empty disk.

## 2. Create the partition

```bash
sudo sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:arch "$DISK"
sudo partprobe "$DISK"
sudo sgdisk -p "$DISK"
```

`--new=0:0:0` = next free number, fill the largest free block. sgdisk allocates
inside free space only and won't overlap an existing partition. `8300` is the
Linux filesystem type code.

**Check:** every kept partition must be identical to §0. If anything about them
changed, stop.

## 3. GO / NO-GO check

Set `TARGET` to the partition §2 just created (sgdisk reuses the lowest free
number, so read the table — it's often *not* the highest):

```bash
TARGET=/dev/nvme0n1p5      # whatever §2 actually created

ok=1
[ -b "$TARGET" ] || { echo "NO-GO: not a block device"; ok=0; }
usage=$(sudo blkid -p -o value -s USAGE "$TARGET" 2>/dev/null)
[ -z "$usage" ] || { echo "NO-GO: something lives here ($usage) -- refusing"; ok=0; }
findmnt -S "$TARGET" >/dev/null 2>&1 && { echo "NO-GO: it is mounted"; ok=0; }
sudo blkid -p -o value -s PART_ENTRY_NUMBER "$TARGET" >/dev/null 2>&1 \
  || { echo "NO-GO: no GPT entry -- wrong device?"; ok=0; }
[ "$(lsblk -no pkname "$TARGET")" = "$(basename "$DISK")" ] \
  || { echo "NO-GO: $TARGET is not on $DISK"; ok=0; }
[ -n "$EXPECT_SERIAL" ] && [ "$(lsblk -dno SERIAL "$DISK")" = "$EXPECT_SERIAL" ] \
  || { echo "NO-GO: $DISK is not serial $EXPECT_SERIAL -- WRONG DISK"; ok=0; }
[ "$ok" = 1 ] && echo "GO: $TARGET is empty, unmounted, on the right disk"
```

**If it doesn't print `GO`, stop. Do not edit the check to make it pass.**

The last two tests are what prove you're on the right device: `$TARGET` sits on
`$DISK`, and `$DISK` has the serial you recorded in §0. Leaving `EXPECT_SERIAL`
empty is a deliberate NO-GO — an unconditional `GO` is not a check. (If your disk
reports no serial, e.g. in some VMs, swap that line for another distinctive fact:
its exact size, or model via `lsblk -dno MODEL "$DISK"`.)

If it says `something lives here (filesystem)` on a partition you just created,
that's the stale superblock from §1 — go back and `wipefs`, don't override.

(Why `USAGE` and not the exit code: `blkid -p` returns 0 on an empty partition
and 2 on a missing device, so exit codes say the opposite of what you'd assume.
`USAGE` is empty only when nothing is there.)

## 4. Format and mount

```bash
sudo mkfs.ext4 -L arch "$TARGET"
sudo mount "$TARGET" /mnt
sudo mkdir -p /mnt/boot/efi
```

ext4, not btrfs — see [Why ext4](#why-ext4). Then the ESP:

```bash
sudo mount "$ESP" /mnt/boot/efi

ls /mnt/boot/efi/EFI    # should list your other OS(es), e.g. Microsoft for Windows
findmnt -R /mnt         # confirm the whole layout before handing over
```

If `$ESP` belongs to another OS and `ls` doesn't show its boot dir, you mounted
the wrong partition — unmount and stop; **do not format it.**

> [!NOTE]
> **No ESP on the disk** (a genuinely empty disk with no UEFI OS)? Then there's
> nothing shared to protect: create one you own — a ~512M partition, `mkfs.fat
> -F32`, mounted at `/mnt/boot/efi` — and formatting *that* is fine. At that point
> you have no OS to preserve either, so archinstall's guided install is the easier
> path (see the note at the top).

## 5. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/main/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

**Do not pass `--silent`.** The TUI is your last look at the disk config, and
where you set passwords (deliberately not in the file — it's a public repo).

In the TUI:

- **Disk configuration** must say **pre-mounted** / `/mnt`. If it offers to wipe a
  disk or format the ESP, something is wrong — quit and re-check §4. (Pre-mounted
  mode is structurally incapable of touching the partition table — it returns
  before any partitioning code runs.)
- The config carries **europa's** hostname, timezone, keymap and username — change
  them in the TUI (or edit the JSON) for your machine. Set the **root password**
  and add your user with sudo.
- Bootloader should read **Grub**.

> [!IMPORTANT]
> **Using a different username?** The dotfiles hard-code `/home/baas` (in
> `hyprpaper.conf`), so either keep the user `baas` or plan to adjust that path
> after install.

> [!IMPORTANT]
> The config is written for archinstall **4.4** (`"version": "4.4"`), but the ISO
> ships whatever archinstall is current, and the config schema drifts between
> releases. If archinstall rejects or mis-parses the file, check `archinstall
> --version` and reconcile the config to it — don't assume the file is simply
> wrong.

**Why GRUB, not systemd-boot:** systemd-boot puts the kernel *and* initramfs
inside the ESP, and Arch's initramfs is 40–90MB (more with extra modules) plus a
fallback. On a small ESP that doesn't fit — europa's is 100M. GRUB keeps them on
`/boot` in the root filesystem and needs only a small stub in the ESP. If your ESP
is ≥1G, systemd-boot is fine and you can pick it instead.

## Secure Boot

archinstall does **not** set up Secure Boot, so install with it **off** (in
firmware; on ASUS this is *Boot → Secure Boot → OS Type → Other OS* — that
disables enforcement while staying in UEFI mode; leave CSM alone).

If you need Secure Boot on afterward — e.g. Windows game anti-cheat requires it —
you must **sign Arch's boot chain**, because Secure Boot is a global firmware
toggle and the firmware refuses to launch unsigned GRUB. Once Arch boots, use
`sbctl`:

```bash
sbctl create-keys
sbctl enroll-keys -m          # -m keeps Microsoft's keys, or Windows won't boot under SB
sbctl sign -s /boot/efi/EFI/GRUB/grubx64.efi
sbctl sign -s /boot/vmlinuz-linux
sbctl verify                  # both should show signed
# then re-enable Secure Boot in firmware
```

Enrolling keys needs the firmware in Setup Mode (clear its factory keys first).
GRUB + Secure Boot + your-own-keys is finicky — follow the
[Arch wiki: Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
step by step. Escape hatch if a signed setup won't boot: turn Secure Boot back off
in firmware, fix it, retry. Secure Boot is optional otherwise — Arch runs fine
without it.

## 6. Let GRUB see your other OS, then reboot

archinstall doesn't enable os-prober, so GRUB would list Arch only. If you have
another OS on the disk, turn it on so GRUB adds it to the menu (skip this whole
step on a single-OS install — Arch-only is correct there):

```bash
sudo arch-chroot /mnt
grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub \
  || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
# Your other OS MUST appear in the output. If not, you reach it via the firmware
# boot menu instead -- annoying, not fatal.
exit

sudo umount -R /mnt
reboot          # remove the USB
```

### What happens to the bootloader

The ESP is **shared and never reformatted** — only the partition in §1 was
deleted — so it helps to separate the GRUB *program* in the ESP from the config +
kernels an OS keeps on its own root:

- **The §1 delete** killed that OS's `grub.cfg` and kernels (if it was Linux), but
  left its ESP boot stub pointing at a root that no longer exists. Harmless — you
  install from the USB and never boot it again.
- **archinstall (§5)** adds a new `EFI/GRUB/` beside whatever's already in the ESP,
  writes a fresh `grub.cfg` on the Arch root, and creates a new NVRAM **GRUB** boot
  entry as the default. It does not reformat the ESP or remove other entries.
- **os-prober (§6)** re-adds any OS whose boot files survive — e.g. Windows via
  `EFI/Microsoft/…/bootmgfw.efi`. An OS whose root you deleted does not come back.

Example — replacing a Linux install that shared the disk with Windows:

| In the ESP | Fate |
|---|---|
| `EFI/GRUB/` (Arch) | new default bootloader |
| `EFI/Microsoft/` (Windows) | untouched; shows in Arch's GRUB via os-prober |
| `EFI/<old-distro>/` (its old GRUB) | orphaned, harmless — points at the deleted partition. Clean up later with `rm -rf` on that dir + `efibootmgr -B` on its stale NVRAM entry |

Two dependencies: the **install USB must be booted in UEFI mode** (not
legacy/CSM), or `efibootmgr` can't write the GRUB entry; and if the firmware
ignores the new entry on reboot, that's the "GRUB doesn't appear" fallback in
[If it goes wrong](#if-it-goes-wrong).

## 7. First boot → the rice

You land at a TTY login — no display manager yet, that's expected; the dotfiles
install it. Continue from the [README → Install](../README.md#install), which
picks up here:

```bash
sudo pacman -Syu                 # confirm network + mirrors work
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles

./install.sh --dry-run           # runs every check, writes nothing
./install.sh --skip-greeter      # packages + configs, no display manager yet
reboot                           # -Syu may have landed a kernel; reboot into it
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
command, so rebuilding is `./install.sh`, any other OS on the disk stays bootable
as a fallback, and pacman's cache plus `downgrade` cover most bad updates. In
exchange you avoid btrfs's ENOSPC-on-metadata surprises, its `check --repair`
caveat, and CoW fragmentation.

**Consequence to know:** ext4 only grows *forward*. If you later free space
*before* this partition (e.g. shrinking a neighbour), it can't be absorbed without
relocating the whole filesystem. Make that space its own partition mounted at
`/home` or `/mnt/games` instead — a normal layout that costs nothing.

## If it goes wrong

- **Arch won't boot** — your other OS still does (firmware boot menu). Re-flash the
  USB and start from §1; the Arch partition is the only thing that changed.
- **GRUB doesn't appear** — firmware boot menu → your other OS's boot entry, then
  `arch-chroot` from the ISO and re-run `grub-install`.
- **greetd comes up black** — at the GRUB menu press `e` and append
  `systemd.unit=multi-user.target` to boot to a TTY with greetd never started.
  See README → Login screen.
- **You want the deleted OS back** — you can't; §1 destroyed it. That's the one
  irreversible thing here, which is why the checklist sits in front of it.

## What's untested

Verified in an Arch VM: package resolution, the GO check against every case, the
config against archinstall 4.4's parser, greetd running nwg-hello as `greeter`,
and `sgdisk --new=0:0:0` filling free space without touching neighbours.

**Not testable without your hardware** — so §5–§7 are staged and manual: your GPU
driver, your monitors, the firmware's GRUB/Secure Boot behaviour, and the reboot.
