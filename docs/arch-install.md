# Installing Arch into free space

Installs Arch onto a GPT disk that already holds another OS, into free space,
without disturbing it. Hands over to `install.sh` for the desktop.

Worked example is `europa` — Windows on one NVMe, plus an old Linux partition to
reclaim. Substitute your own names throughout.

Empty disk with nothing to keep? Skip all this and run archinstall's guided
install.

## Before you start

- Boot the Arch ISO in **UEFI mode** (pick the `UEFI:` entry for the stick).
- **Secure Boot off** in firmware — archinstall doesn't set it up. See
  [Secure Boot](#secure-boot).
- If Windows uses **BitLocker**, disable it first, or a partition change triggers
  a recovery-key prompt.

## 1. Find the partition

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT
```

europa:

| Part | Size | Type | Plan |
|---|---|---|---|
| `p1` | 100M | EFI System | mount, **never format** — shared with Windows |
| `p2` | 16M | MS reserved | leave |
| `p3` | 1.4T | ntfs — Windows | leave |
| `p4` | 894M | Windows recovery | leave |
| `p6` | 500G | ext4 — old Linux | **reclaim this** |

**Watch out:** the ESP is shared with Windows. Formatting it destroys Windows'
boot files. It gets mounted, never `mkfs`'d.

## 2. Reclaim it

```bash
sudo wipefs -a /dev/nvme0n1p6            # the partition you're freeing
sudo sgdisk --delete=6 /dev/nvme0n1      # 6 = the number at the end of that name
sudo partprobe /dev/nvme0n1
sudo parted /dev/nvme0n1 unit GB print free
```

That space should now show as free, and every other partition unchanged.

**Watch out:** `wipefs` before `--delete`, not after. Deleting a partition only
removes the table entry — the old filesystem's superblock stays on the sectors,
and the partition you create next inherits it.

## 3. Create, format, mount

```bash
sudo sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:arch /dev/nvme0n1
sudo partprobe /dev/nvme0n1
lsblk /dev/nvme0n1                       # read the new partition's name
```

**Watch out:** sgdisk reuses the **lowest** free number, not the next one up. On
europa, deleting `p6` and creating one gave **`p5`**. Read it, don't assume.

```bash
sudo mkfs.ext4 -L arch /dev/nvme0n1p5    # whatever the line above actually says
sudo mount /dev/nvme0n1p5 /mnt
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/nvme0n1p1 /mnt/boot/efi  # the ESP

ls /mnt/boot/efi/EFI                     # must list Microsoft/ — Windows' boot files
```

**Watch out:** if that `ls` doesn't show the other OS, you mounted the wrong
partition as the ESP. Unmount and recheck — `mkfs` never prompts, and never warns
that something is already there.

## 4. archinstall

```bash
curl -fLO https://raw.githubusercontent.com/Benj181/conf-hyprland/main/docs/archinstall-europa.json
archinstall --config archinstall-europa.json
```

The file already sets pre-mounted disk config, GRUB, `removable: false`,
hostname, timezone `Europe/Oslo`, `no` keymap, NetworkManager and the base
packages. **Type these in the TUI:**

| Field | What |
|---|---|
| **Disk configuration** | Must already read **pre-mounted** `/mnt`. If it offers to wipe or format anything — quit; your mounts from §3 are wrong. |
| **Root password** | Set it. Not in the file — this is a public repo. |
| **User account** | Add yours, sudo yes. Keep the name **`baas`**, or fix the `/home/baas` path in `hypr/.config/hypr/hyprpaper.conf` afterwards. |
| **Hostname / timezone / keymap** | europa's values. Change for your machine. |

Everything else: leave alone. Don't pass `--silent` — the TUI is your last look at
the disk config.

**Watch out:** `"removable": false` in the JSON is load-bearing. With `true`, GRUB
installs to `EFI/BOOT/BOOTX64.EFI` with **no NVRAM entry**, Windows wins the boot
order, and it looks exactly like Arch never installed.

**Watch out:** the file says `"version": "4.4"`. The ISO ships whatever's current
and the schema drifts. If archinstall rejects it, check `archinstall --version`
and reconcile.

## 5. GRUB

**archinstall installs GRUB wrong — redo it.** It builds `grubx64.efi` with the
prefix pointing at `/boot/efi/grub` on the ESP instead of `/boot/grub` on the
root. The prefix is compiled into the binary and is where GRUB reads its config
at boot, so you get a menu with no Windows, and editing `/boot/grub/grub.cfg`
changes nothing.

Reinstall it. `--boot-directory` is what rebuilds the prefix:

```bash
sudo arch-chroot /mnt
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub    # Windows in the menu
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
             --boot-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Delete the stray config, and any old distro's boot chain — the firmware falls
through to it and loads that instead:

```bash
sudo rm -rf /boot/efi/grub /boot/efi/EFI/ubuntu   # if present
efibootmgr                                        # find the old distro's entry
sudo efibootmgr -B -b 0005                        # delete it
sudo efibootmgr -o 0001,0000                      # GRUB first, then Windows
```

Keep `EFI/Microsoft/` and `EFI/Boot/`.

Verify — the prefix first, before anything else:

```bash
strings /boot/efi/EFI/GRUB/grubx64.efi | grep -E '/boot.*grub'
#   (,gpt5)/boot/grub    correct
#   /boot/efi/grub       wrong -- reinstall

efibootmgr | grep -E "BootOrder|GRUB"        # GRUB entry exists, and is first
sudo grep -c menuentry /boot/grub/grub.cfg   # >1, with Windows among them
```

**Watch out:** deleting the stray config on its own does nothing — the prefix
sends GRUB back to it. Rebuild the binary.

**Watch out:** `grep boot/grub` matches nothing when the prefix is wrong —
`/boot/efi/grub` doesn't contain `boot/grub`. Use the pattern above.

```bash
exit
sudo umount -R /mnt
reboot                                   # pull the USB
```

## 6. First boot → the rice

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

Need it on afterwards — Windows anti-cheat, say — then sign the boot chain:

```bash
sbctl create-keys
sbctl enroll-keys -m             # -m keeps Microsoft's keys, or Windows won't boot
sbctl sign -s /boot/efi/EFI/GRUB/grubx64.efi
sbctl sign -s /boot/vmlinuz-linux
sbctl verify
# then re-enable Secure Boot in firmware
```

Enrolling needs the firmware in Setup Mode. If a signed setup won't boot, turn
Secure Boot off again and retry.

## If it goes wrong

- **GRUB doesn't appear, or its menu has no Windows, or it ignores your edits** —
  check the prefix first (§5), not the config. A wrong prefix produces all three,
  and no amount of editing `/boot/grub/grub.cfg` touches the file GRUB is actually
  reading. Firmware boot menu → Windows, then `arch-chroot` from the ISO and
  re-run §5.
- **The firmware boots an old distro instead** — its NVRAM entry is winning.
  `efibootmgr -B -b <n>` to delete it, `-o` to put GRUB first (§5).
- **Arch won't boot** — Windows still does. Re-flash the USB, start from §1.
- **greetd comes up black** — at the GRUB menu press `e`, append
  `systemd.unit=multi-user.target`, and boot to a TTY with greetd never started.
- **You want the deleted partition back** — you can't. §2 is the one irreversible
  step here.
