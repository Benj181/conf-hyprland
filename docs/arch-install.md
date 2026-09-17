# Installing Arch onto a new drive

Installs Arch onto a **brand new, empty NVMe** that gets its own ESP, on a
machine that keeps Windows on a different disk. Hands over to `install.sh` for
the desktop.

Worked example is `europa` — a new M.2 alongside a Kingston 2TB holding Windows,
its 100M ESP, and the previous Arch install. Substitute your own names
throughout.

Installing into free space on a disk that already has another OS, sharing its
ESP? That's a different job — GRUB, a shared 100M partition, and a much narrower
path. `git log -- docs/arch-install.md` has that version.

## What this buys you

A drive of its own is the easy case, and it's worth being explicit about why:

- **Its own ESP.** Nothing shared with Windows, so nothing to destroy by
  formatting the wrong partition. The old doc's single most dangerous step is
  gone.
- **The old install stays bootable.** It is on a different disk with its own
  bootloader and its own NVRAM entry. It is your fallback until you decide
  otherwise ([Reclaiming the old partition](#reclaiming-the-old-partition)).
- **systemd-boot instead of GRUB.** No compiled-in prefix to get wrong, and no
  shim_lock verifier to fight when you want Secure Boot.

It costs one thing, and you should decide you're fine with it before starting:
**Windows will not appear in the boot menu.** See [§6](#6-booting-windows).

## Before you start

- Seat the M.2 and boot the Arch ISO in **UEFI mode** (pick the `UEFI:` entry for
  the stick).
- **Secure Boot off** in firmware — archinstall doesn't set it up. See
  [Secure Boot](#secure-boot).
- BitLocker can stay on. Nothing here touches Windows' disk — that's the point
  of the new drive. (Secure Boot later does; that section says so.)

## 1. Find the new disk

Adding an NVMe **renumbers the others**. What was `nvme0n1` yesterday may be
`nvme1n1` now, depending on which slot enumerates first.

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT,MODEL
```

europa, after fitting the new drive:

| Disk | Size | Model | Plan |
|---|---|---|---|
| ? | 1.9T | KINGSTON SKC3000D | Windows + old ESP + old Arch — **leave entirely** |
| ? | 1.8T | WDC WD20EARS | NTFS data — leave |
| ? | — | the new one | **install here** |

Identify by **model and size**, then pin it down once:

```bash
DISK=/dev/nvme1n1        # the NEW drive -- whatever lsblk actually called it
lsblk -o NAME,SIZE,MODEL "$DISK"
```

Every command below uses `$DISK`. Set it in each shell you open, and re-read that
`lsblk` line before the first destructive one.

**Watch out:** the new drive is the one with **no partitions and no filesystems**.
If `$DISK` lists an `ntfs` child or a partition named `Basic data`, you have
Windows' disk. Stop and re-read.

**Watch out:** renumbering doesn't hurt the old Arch install — its `/etc/fstab`
mounts by UUID, not by `/dev` name. Don't "fix" anything there.

## 2. Partition it

Fresh GPT, two partitions — a 1G ESP and everything else for root:

```bash
sudo sgdisk --zap-all "$DISK"
sudo sgdisk --new=1:0:+1G  --typecode=1:ef00 --change-name=1:ESP  "$DISK"
sudo sgdisk --new=2:0:0    --typecode=2:8300 --change-name=2:arch "$DISK"
sudo partprobe "$DISK"
lsblk "$DISK"
```

`--zap-all` is safe here and only here: the drive is empty. It is the one command
in this document that would be unrecoverable pointed at the wrong disk.

**Watch out:** `ef00` on partition 1 is load-bearing, and not just for the
firmware. archinstall's pre-mounted mode finds the ESP by reading the **partition
flag**, not by noticing what you mounted where. Get the typecode wrong and it
installs the entire system, then fails at the bootloader step with *"Could not
detect EFI system partition"*.

**Watch out:** 1G, not the 100M Windows hands out. systemd-boot keeps the kernel
and initramfs **on the ESP**, and a fallback initramfs is not small. 100M fits
one kernel and no room to be wrong.

## 3. Format and mount

The ESP mounts at **`/mnt/boot`** — not `/mnt/boot/efi`:

```bash
sudo mkfs.fat -F32 -n ESP "${DISK}p1"
sudo mkfs.ext4 -L arch "${DISK}p2"

sudo mount "${DISK}p2" /mnt
sudo mount --mkdir "${DISK}p1" /mnt/boot

findmnt /mnt /mnt/boot    # ext4 on p2, vfat on p1 -- and nothing else
```

**Watch out:** `/mnt/boot`, not `/mnt/boot/efi`. systemd-boot's entries point at
`/vmlinuz-linux` relative to the partition they live on, so the kernel has to be
on the ESP. Mount the ESP a level deeper and the kernel lands on ext4, which
systemd-boot cannot read — the menu appears and every entry fails.

**Watch out:** do **not** mount the old 100M ESP anywhere under `/mnt`.
archinstall installs into everything it finds mounted there, and it would end up
in the new `fstab`. The new install should never touch that partition again.

## 4. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/main/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

The file already sets pre-mounted disk config, systemd-boot, hostname, timezone
`Europe/Oslo`, `no` keymap, NetworkManager and the base packages. **Type these in
the TUI:**

| Field | What |
|---|---|
| **Disk configuration** | Must already read **pre-mounted** `/mnt`. If it offers to wipe or format anything — quit; your mounts from §3 are wrong. |
| **Root password** | Set it. Not in the file — this is a public repo. |
| **User account** | Add yours, sudo yes. Keep the name **`baas`**, or fix the `/home/baas` path in `hypr/.config/hypr/hyprpaper.conf` afterwards. |
| **Hostname / timezone / keymap** | europa's values. Change for your machine. |

Everything else: leave alone. Don't pass `--silent` — the TUI is your last look at
the disk config.

**Watch out:** the file says `"version": "4.4"`. The ISO ships whatever's current
and the schema drifts. If archinstall rejects it, check `archinstall --version`
and reconcile.

**Watch out:** if you're editing the JSON, push it before you boot the ISO. That
`curl` reads GitHub `main`, not your working copy.

## 5. Verify the boot entry

archinstall ran `bootctl install` for you. Unlike the old GRUB setup, it very
probably got it right — but it can leave you with a bootloader and **no NVRAM
entry**, silently, and that looks exactly like a failed install. Check before you
reboot, not after:

```bash
sudo arch-chroot /mnt
bootctl status        # Product: systemd-boot, ESP: /boot
bootctl list          # one entry per kernel
efibootmgr            # "Linux Boot Manager" must be here
```

If `efibootmgr` has no Linux entry, write it yourself — still in the chroot:

```bash
bootctl install --variables=yes
```

`bootctl` skips EFI variables when it thinks it's running in a container, and
`arch-chroot` looks like one to systemd 257 and up. archinstall passes
`--variables=yes` to force it, but falls back to `--variables=no` if that errors
— and the fallback is what leaves you with nothing.

Then put it first. Windows and the old install both have entries and one of them
currently wins:

```bash
efibootmgr                          # read the boot numbers
efibootmgr -o 0003,0000,0001        # Linux Boot Manager, then the rest
```

Leave the old GRUB entry in place. It still boots the old install off the other
disk, and until the new one is proven that is exactly what you want.

```bash
exit
sudo umount -R /mnt
reboot                              # pull the USB
```

## 6. Booting Windows

**Windows is not in the systemd-boot menu, and won't be.** systemd-boot only
scans its own ESP and XBOOTLDR for boot entries. Windows' `bootmgfw.efi` is on
the other disk's ESP, and a type 1 entry's `efi` path can't reach across
partitions. This is the trade for not sharing an ESP.

Two ways to get there:

- **The firmware boot menu** — F8 on ASUS, held at power-on. Windows has its own
  NVRAM entry; pick it.
- **One-shot from Arch**, which is nicer for a reboot you already planned:

```bash
efibootmgr | grep -i windows          # find its boot number
sudo efibootmgr -n 0000 && reboot     # BootNext -- this reboot only
```

`-n` sets `BootNext`, which the firmware consumes once and clears. `BootOrder` is
untouched, so the boot after that comes back to Arch on its own.

**Watch out:** copying `EFI/Microsoft/` onto the new ESP to force an entry is a
trap. `bootmgfw.efi` reads its BCD from the ESP it was loaded from, so you get a
second boot configuration that Windows Update never patches and that drifts out
of sync with the real one. Use the firmware menu.

## 7. First boot → the rice

You land at a TTY — no display manager yet, that's expected.

```bash
sudo pacman -Syu                 # confirm network + mirrors
git clone https://github.com/Benj181/conf-hyprland.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles

./install.sh --dry-run           # writes nothing
./install.sh --skip-greeter      # packages + configs, no display manager yet
reboot                           # -Syu may have landed a kernel
```

Then the greeter, last:

```bash
Hyprland                         # by hand from the TTY first
nwg-hello -t                     # preview it in a window, greetd untouched
./scripts/install-greeter.sh
sudo systemctl start greetd      # live, from a TTY, before committing
```

## Secure Boot

Install with it **off** (ASUS: *Boot → Secure Boot → OS Type → Other OS*; leave
CSM alone). Arch runs fine without it.

Need it on afterwards — Windows anti-cheat, say — then enrol your own keys and
sign the boot chain. Arch ships nothing Microsoft-signed, so there's no shortcut;
you become the CA. Windows keeps booting because Microsoft's keys go in alongside
yours.

Three steps. On GRUB this was four, and the extra one was rebuilding the binary
to strip a verifier that refused to load anything — systemd-boot has no
equivalent, so that whole problem is gone.

### 1. Setup Mode

Enrolling keys needs the firmware's factory keys cleared (ASUS: *Boot → Secure
Boot → Key Management → Clear Secure Boot Keys*). Leave Secure Boot itself off
until §3.

```bash
sudo pacman -S sbctl
sudo sbctl status                # Setup Mode: Enabled, Vendor Keys: none
```

### 2. Enrol your keys

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys -m        # -m keeps Microsoft's keys, or Windows won't boot
```

Enrolling a PK exits Setup Mode on its own — `status` flipping to *Setup Mode:
Disabled* here is the success case, not a problem.

### 3. Sign, then turn it on

Two files, and that is genuinely all:

```bash
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/vmlinuz-linux
sudo sbctl verify
# re-enable Secure Boot in firmware, reboot
sudo sbctl status                # Secure Boot: Enabled, Setup Mode: Disabled
```

The **initramfs is not signed and does not need to be.** The firmware verifies
systemd-boot; systemd-boot hands the kernel to `LoadImage`, so the firmware
verifies that too. The initramfs arrives through the kernel's EFI stub after
verification is over. This is exactly what GRUB got wrong: its shim_lock verifier
demanded a signature on the initramfs, which is a cpio archive and *cannot carry
one*.

`-s` adds a file to sbctl's database, and the `zz-sbctl.hook` pacman hook re-signs
everything in there after any transaction touching `/boot` — so kernel upgrades
take care of themselves.

**Watch out:** `bootctl update`, and the `systemd-boot-update.service` that runs
it after a systemd upgrade, write a **fresh unsigned** `systemd-bootx64.efi`.
Run `sudo sbctl verify` after any systemd upgrade. If it reports the loader
unsigned, `sbctl sign -s` it again before rebooting.

**Watch out:** `sbctl verify` lists `EFI/BOOT/BOOTX64.EFI` on **Windows' ESP** as
unsigned if that partition happens to be mounted. Leave it alone — it isn't
yours, and `-m` in §2 is what makes the firmware trust Microsoft's chain. Only
the files on the new drive's `/boot` are yours to sign.

**Watch out:** BitLocker treats a Secure Boot state change as tampering and asks
for the recovery key on the first Windows boot after. Have it ready —
`account.microsoft.com/devices/recoverykey`.

## Reclaiming the old partition

Don't do this on install night. The old Arch on the other disk is your fallback,
and it costs you nothing but 500G to keep it until the new system has survived a
week, a kernel upgrade, and the greeter.

When you're ready, from the new install:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL     # find the old root -- ext4, LABEL=arch
```

Make sure it isn't mounted, then take the space back:

```bash
sudo wipefs -a /dev/nvme0n1p5             # the OLD root, on the OTHER disk
sudo sgdisk --delete=5 /dev/nvme0n1
sudo partprobe /dev/nvme0n1
```

**Watch out:** `wipefs` before `--delete`, not after. Deleting a partition only
removes the table entry — the old filesystem's superblock stays on the sectors,
and whatever you create there next inherits it.

Then clear the boot entry that pointed at it, and the GRUB directory on the old
ESP:

```bash
efibootmgr                                # find the old GRUB entry
sudo efibootmgr -B -b 0001                # delete it
sudo mount /dev/nvme0n1p1 /mnt            # the OLD, 100M ESP
sudo rm -rf /mnt/EFI/GRUB
sudo umount /mnt
```

Keep `EFI/Microsoft/` and `EFI/Boot/`. Windows boots from them.

The free space is now unallocated on Windows' disk. Extend the Windows partition
into it from **Disk Management inside Windows** — it's contiguous and adjacent,
so the *Extend Volume* option will be live. Don't try to do it from Linux.

**Watch out:** this is the one irreversible section in this document. Everything
before it leaves both systems bootable.

## If it goes wrong

- **The new drive doesn't appear in the boot menu** — no NVRAM entry was written.
  Boot the ISO, mount and `arch-chroot`, then §5. This is the failure mode to
  expect, because `bootctl` fails at it *quietly*.
- **archinstall dies with "Could not detect EFI system partition"** — the ESP's
  typecode isn't `ef00`, or it isn't mounted under `/mnt`. `sgdisk -p "$DISK"`
  to check, `sgdisk --typecode=1:ef00 "$DISK"` to fix, then re-run §4. The
  partition is not reformatted by changing its type.
- **The menu appears but entries fail to load the kernel** — the ESP is mounted
  at `/boot/efi` instead of `/boot`, so the kernel is on ext4 where systemd-boot
  can't reach it. Redo §3 and reinstall.
- **The firmware boots Windows or the old Arch instead** — their NVRAM entries
  are winning. `efibootmgr -o` to put Linux Boot Manager first (§5).
- **The new install won't boot at all** — the old one still does, off the other
  disk. Pick it from the firmware menu, and you have a full desktop to debug
  from. That's what keeping it is for.
- **Boot stops working right after a systemd upgrade, with Secure Boot on** —
  `bootctl update` replaced the signed loader. Turn Secure Boot off, `sbctl sign
  -s` the loader, turn it back on (Secure Boot §3).
- **greetd comes up black** — at the boot menu press `e`, append
  `systemd.unit=multi-user.target`, and boot to a TTY with greetd never started.
