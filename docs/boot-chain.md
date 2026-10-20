# Boot chain: UEFI, systemd-boot and Secure Boot

A manual guide for moving a Redrix running Debian from a ChromeOS-style boot (for example Submarine in developer
mode) to a standard UEFI boot on MrChromebox's firmware, then to Debian's signed chain with Secure Boot on:

```
firmware (MrChromebox UEFI) -> shim (signed by Microsoft) -> systemd-boot (signed by Debian) -> Debian-signed kernel
```

**This is not automated by the kit**, on purpose. Every step depends on your disk layout, your encryption and your
boot loader, and a mistake can leave the machine unbootable or, with a firmware password and Secure Boot, locked out
of your own setup. Read each step, adapt it, and keep its rollback at hand. The commands below are examples: never
copy partition numbers, sizes or sectors without checking them against your own disk.

What you gain: a boot that does not depend on ChromeOS kernel partitions, a hidden boot menu (the firmware logo stays
until Plymouth redraws it, see [boot-splash](components/boot-splash.md)), Secure Boot with kernel lockdown, and one
kernel command line for every boot loader.

Tested on one machine: Debian testing, systemd 262, shim-signed 1.51, MrChromebox 2609.1.

## Before you start

- A full backup of the stock firmware, and a recovery path: see [firmware](firmware.md).
- A Debian live USB that boots on your machine, to repair things from outside.
- Your LUKS passphrase, if the disk is encrypted.
- Backups of the partition table and of `/boot` (step 1).

## Step 1: back up the partition table and /boot

```sh
sudo mkdir -p /root/boot-migration
sudo sgdisk --backup=/root/boot-migration/gpt.bin /dev/nvme0n1
sudo tar -C /boot -cpf /root/boot-migration/boot.tar .
```

Copy both files off the machine too.

**Rollback:** `sudo sgdisk --load-backup=/root/boot-migration/gpt.bin /dev/nvme0n1 && sudo partx -u /dev/nvme0n1`,
then restore `/boot` from the tar if its filesystem had to be recreated.

## Step 2: make room for an EFI System Partition

A ChromeOS-style layout usually has no EFI System Partition (ESP). The firmware needs one, FAT32, type `EF00`.

Size it for at least two kernels and their initramfs: with systemd-boot, kernels live on the ESP. On the tested
machine, 256 MiB held two Debian kernels with 48 MB left; choose 512 MiB or more if you can.

If you have free space at the end of the disk, create the partition there. Otherwise, shrink a partition. The tested
machine had a separate 1 GiB ext4 `/boot`; it was shrunk to 768 MiB, keeping its start sector, filesystem UUID and
partition GUID, and the freed 256 MiB became the ESP:

1. Stop anything holding `/boot`. `fwupd` runs in its own mount namespace and keeps `/boot` mounted there after you
   unmount it:

   ```sh
   sudo systemctl stop fwupd.service
   sudo umount /boot
   grep -l " - ext4 /dev/nvme0n1pN " /proc/[0-9]*/mountinfo    # must print nothing
   ```

2. Check and shrink the filesystem *below* the target size, so it fits while you edit the partition:

   ```sh
   sudo e2fsck -f /dev/nvme0n1pN
   sudo resize2fs /dev/nvme0n1pN 700M
   ```

3. Recreate the partition with the same start sector and GUID and the smaller end, and add the ESP in the freed
   space (read the current values with `sgdisk -i N /dev/nvme0n1` first):

   ```sh
   sudo sgdisk -d N -n N:<same start>:<new end> -t N:8300 -c N:<same name> -u N:<same GUID> \
               -n M:<new end + 1>:<old end> -t M:EF00 -c M:EFI /dev/nvme0n1
   sudo partx -u --nr N /dev/nvme0n1 && sudo partx -a --nr M /dev/nvme0n1
   ```

4. Grow the filesystem back to the partition, check it, remount, and format the ESP:

   ```sh
   sudo resize2fs /dev/nvme0n1pN && sudo e2fsck -f /dev/nvme0n1pN
   sudo mount /boot
   sudo mkfs.vfat -F 32 -n EFI /dev/nvme0n1pM
   sudo systemctl start fwupd.service
   ```

**Rollback:** unmount `/boot`, restore the GPT backup (step 1), `partx -u`, run `e2fsck -f` on the partition; if the
filesystem is damaged, recreate it with its old UUID (`mkfs.ext4 -U <old UUID>`) and extract the tar.

Your current ChromeOS-style boot keeps working through all of this: its kernel partitions are not touched.

## Step 3: a boot loader the UEFI firmware will find

Before flashing the UEFI firmware, the disk must hold something it can boot. edk2 boots the removable path
`EFI/BOOT/BOOTX64.EFI` on the ESP even without a boot entry in NVRAM, which matters because NVRAM is empty after the
flash.

The tested approach was a standalone GRUB that reads the existing `/boot/grub/grub.cfg`:

1. Mount the ESP permanently:

   ```sh
   sudo mkdir -p /boot/efi
   echo "UUID=$(lsblk -no UUID /dev/nvme0n1pM)  /boot/efi  vfat  umask=0077,noatime  0 2" | sudo tee -a /etc/fstab
   sudo systemctl daemon-reload && sudo mount /boot/efi
   ```

2. Build GRUB with a small embedded configuration that finds `/boot` by UUID and loads its `grub.cfg`
   (package `grub-efi-amd64-bin`):

   ```sh
   cat > /tmp/early.cfg <<EOF
   search --no-floppy --fs-uuid --set=root $(findmnt -no UUID /boot)
   set timeout=2
   source (\$root)/grub/grub.cfg
   EOF
   sudo mkdir -p /boot/efi/EFI/BOOT
   sudo grub-mkstandalone -O x86_64-efi --locales= --fonts= --themes= \
       --modules="part_gpt ext2 fat search search_fs_uuid normal linux all_video" \
       -o /boot/efi/EFI/BOOT/BOOTX64.EFI "boot/grub/grub.cfg=/tmp/early.cfg"
   ```

   With a separate `/boot` partition, paths in that `grub.cfg` are relative to the partition (`/vmlinuz-...`, not
   `/boot/vmlinuz-...`). Make sure `/boot/grub/grub.cfg` exists and boots your kernel with the right `root=` and
   encryption options: ChromeOS-style setups often generate it with their own tool rather than `update-grub`.

3. Test it **before flashing**, for example in QEMU with OVMF firmware and a copy of the ESP and `/boot`, or at least
   check that the file exists and that `grub.cfg` is complete. The tested setup was checked in QEMU/OVMF first.

**Rollback:** `sudo rm -r /boot/efi/EFI/BOOT`, remove the `/boot/efi` line from `/etc/fstab`. Nothing else changed.

## Step 4: flash the UEFI firmware

See [firmware](firmware.md). On the tested machine the first UEFI boot went straight to `BOOTX64.EFI`, GRUB, then the
disk passphrase prompt.

## Step 5: one kernel command line

systemd-boot's `kernel-install` takes the command line from `/etc/kernel/cmdline`. Make it the single source:

```sh
echo "root=UUID=$(findmnt -no UUID /) ro quiet splash fbcon=vc:2-6" | sudo tee /etc/kernel/cmdline
```

Add what your system needs (`rootflags=subvol=@` for a btrfs root with an `@` subvolume, encryption options if your
initramfs needs them). `quiet splash` shows the Plymouth splash; `fbcon=vc:2-6` keeps the kernel console from
clearing the firmware logo (see [troubleshooting](troubleshooting.md)). If you keep a rescue GRUB (next step),
generate its `grub.cfg` from the same options so both loaders agree.

**Rollback:** delete the file; nothing reads it until step 7.

## Step 6: move GRUB to a rescue entry

shim will take the removable path `EFI/BOOT/BOOTX64.EFI`. Keep the unsigned GRUB as a rescue loader in its own
directory with its own firmware entry, last in the boot order. It only runs with Secure Boot off.

```sh
sudo mkdir -p /boot/efi/EFI/grub-rescue
sudo cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/grub-rescue/grubx64.efi
ORDER=$(efibootmgr | sed -n 's/^BootOrder: //p')
sudo efibootmgr --create --disk /dev/nvme0n1 --part M --loader '\EFI\grub-rescue\grubx64.efi' --label 'GRUB (rescue)'
sudo efibootmgr --bootorder "$ORDER,<new entry number>"
```

For a rescue loader, a longer GRUB timeout (3 seconds or more) helps: rebuild it with `set timeout=3`.

**Rollback:** `sudo efibootmgr --delete-bootnum --bootnum <number>` and `sudo rm -r /boot/efi/EFI/grub-rescue`.

## Step 7: shim and systemd-boot

On Debian testing at the time of testing, installing systemd-boot with its signed EFI binary and shim, while removing
`grub-efi-amd64-signed`, made shim load the signed systemd-boot:

```sh
sudo apt install systemd-boot systemd-boot-efi-amd64-signed shim-signed grub-efi-amd64-signed-
```

apt may warn about removing an essential-marked package; read what it plans to remove before confirming. Check
Debian's documentation for the current recommended way: package relationships change on testing.

Loader settings, `/boot/efi/loader/loader.conf`:

```
timeout menu-hidden
console-mode keep
editor no
```

`menu-hidden`: no menu unless you press a key (Space) while it starts; `console-mode keep`: no mode switch, so the
firmware logo stays; `editor no`: the command line cannot be edited at boot, which Secure Boot requires to mean
anything.

Install an entry for every kernel (apt does it once; this refreshes them after changing `/etc/kernel/cmdline`):

```sh
for k in /boot/vmlinuz-*; do v=${k#/boot/vmlinuz-}; sudo kernel-install add "$v" "$k" "/boot/initrd.img-$v"; done
bootctl status
ls /boot/efi/loader/entries/
efibootmgr
```

Reboot once **with Secure Boot still off** and check that the normal entry boots.

**Rollback:** `sudo apt install systemd-boot- systemd-boot-efi-amd64-signed- grub-efi-amd64-signed` (or put the GRUB
binary back: `sudo cp /boot/efi/EFI/grub-rescue/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI`), with Secure Boot off.
The rescue entry still boots in the meantime.

## Step 8: turn Secure Boot on

In the firmware setup (Esc at power-on, then Device Manager), enable Secure Boot. MrChromebox's firmware ships
Microsoft's UEFI CA 2011 and 2023 certificates in `db`, which is what shim is signed with.

Check:

```sh
mokutil --sb-state          # SecureBoot enabled
bootctl status | grep -i 'secure boot'
cat /sys/kernel/security/lockdown    # [integrity]
```

Consequences:

- The kernel is in lockdown (integrity): unsigned kernel modules are refused. DKMS or other out-of-tree modules need
  to be signed with a Machine Owner Key enrolled with `mokutil`. On the tested machine, four unsigned module loads
  are refused at boot; they already failed before with `Invalid ELF header magic`, so nothing was lost.
- `flashrom` no longer works from Linux. To flash firmware later: disable Secure Boot, add `iomem=relaxed` to
  `/etc/kernel/cmdline`, `sudo kernel-install add-all`, reboot (or use the rescue GRUB entry).
- If you set a firmware password, it is needed to disable Secure Boot. Do not lose it (see [firmware](firmware.md)).
- A LUKS TPM2 key slot enrolled without PCRs (`--tpm2-pcrs=`) keeps working across these changes, as long as the TPM
  is not cleared.

**Rollback:** disable Secure Boot in the firmware setup.

## Step 9 (optional): retire the ChromeOS kernel partitions

Once the UEFI chain has worked for a while, the ChromeOS kernel partitions (`KERN-A`, `KERN-B`) are unused. Save their
images before deleting anything:

```sh
lsblk -o NAME,SIZE,PARTLABEL /dev/nvme0n1                          # find KERN-A and KERN-B
sudo dd if=/dev/nvme0n1pK of=/root/boot-migration/KERN-A.img bs=1M   # K = the KERN-A partition number
```

There is no need to delete them; they take a few MB.

## Rescue

| Problem | Way out |
|---|---|
| systemd-boot does not show its menu | press Space repeatedly from power-on |
| normal entry fails | pick an older kernel in the systemd-boot menu |
| systemd-boot or shim broken | Esc at power-on, disable Secure Boot, then choose "GRUB (rescue)" in the boot menu |
| nothing on the disk boots | a Debian live USB; mount root, `/boot`, `/boot/efi`; chroot and reinstall the loader or restore the step 1 backups |
| firmware will not start at all | see Recovery in [firmware](firmware.md) |
