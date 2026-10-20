# Seamless boot logo (`boot-splash`)

The firmware's logo stays where it is from power-on to the login screen. The disk-unlock prompt and the spinner
appear below it, instead of the screen switching to a different splash.

## Risk level: high

It changes the default Plymouth theme and rebuilds the initramfs of every installed kernel. If a rebuild fails, a
kernel can be left unbootable. The installer asks you to type the component's name back; with `--yes` it also needs
`--accept-risk`. Read the rollback section before installing.

## Background

UEFI firmware draws its logo at power-on and publishes it to the operating system as the ACPI BGRT image, with its
position. Plymouth's `bgrt` theme (package `plymouth-themes`) redraws that image at the same place, so the logo does
not jump. With MrChromebox's firmware, edk2 centres the logo at 38.2 % of the screen height.

The stock `bgrt` theme puts its password dialog over the logo and clears it. The kit generates a derived theme,
`redrix-bgrt`, from the installed `bgrt.plymouth`:

| Key in `[two-step]` | Value | Effect |
|---|---|---|
| `DialogClearsFirmwareBackground` | `false` | the logo stays while a password or PIN prompt shows |
| `DialogVerticalAlignment`, `TitleVerticalAlignment` | `.72` | the prompt and title sit below the logo |
| `VerticalAlignment` | `.82` | the spinner sits below them |
| `Transition`, `TransitionDuration` | `fade-over`, `0.5` | a short fade into the login screen |

The theme is generated on the machine by `components/boot-splash/render-theme.sh`: the kit ships no copy of Debian's
theme and follows its updates. If a future `bgrt.plymouth` loses one of these keys, generation fails instead of
producing a half-modified theme.

To change the logo itself, the firmware has to be rebuilt: see [firmware](../firmware.md).

## What the installer changes

| Path or action | Content |
|---|---|
| `/usr/share/plymouth/themes/redrix-bgrt/redrix-bgrt.plymouth` | the generated theme |
| `plymouth-set-default-theme redrix-bgrt` | the default theme; the previous one is recorded in `~/.local/share/redrix-linux/saved/boot-splash/previous-theme` |
| `update-initramfs -u -k all` | every initramfs is rebuilt, since Plymouth's theme is copied into it |

Debian packages: `plymouth`, `plymouth-themes`, `initramfs-tools`.

## Requirements

- **A firmware that publishes a BGRT image** (`/sys/firmware/acpi/bgrt/image`). MrChromebox's UEFI firmware does; the
  stock ChromeOS firmware does not. The component is hidden otherwise.
- **initramfs-tools** (`update-initramfs`). Systems that build their initramfs with dracut are not supported by the
  component: there, the equivalent is to generate the theme with `render-theme.sh`, set it with
  `plymouth-set-default-theme`, and rebuild with `dracut --regenerate-all --force`. That path is not tested by the kit.
- **`splash` on the kernel command line** (usually with `quiet`). Without it Plymouth shows text, not the logo. The
  installer warns if it is missing; it does not edit the command line for you. Where to add it:
  - GRUB: `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` in `/etc/default/grub`, then `sudo update-grub`.
  - systemd-boot with `kernel-install`: add `quiet splash` to `/etc/kernel/cmdline`, then
    `sudo kernel-install add-all` (see [boot chain](../boot-chain.md)).
- Optional, for the cleanest result: `fbcon=vc:2-6` on the command line keeps the kernel console from clearing the
  logo early (see [troubleshooting](../troubleshooting.md)).

## Verify

```sh
./verify.sh boot-splash
```

| Check | Meaning |
|---|---|
| `theme redrix-bgrt installed and up to date` | the installed theme equals what `render-theme.sh` produces now from the installed `bgrt` theme |
| `Plymouth's default theme is redrix-bgrt` | `plymouth-set-default-theme` reports it |
| `kernel command line has "splash"` | `/proc/cmdline` contains `splash` |
| `the firmware publishes its logo (ACPI BGRT, x,y)` | the BGRT image is there, with its offset |

The initramfs copy is readable by root only; an INFO line gives the command:

```sh
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep redrix-bgrt
```

After a `plymouth-themes` update, run `./verify.sh boot-splash`: if the first check fails, reinstall to regenerate
the theme from the new version.

## Uninstall

```sh
./uninstall.sh boot-splash
```

Puts the previous default theme back (`bgrt` if none was recorded), rebuilds every initramfs, and removes the theme
directory.

### Manual rollback

From a running system:

```sh
sudo plymouth-set-default-theme bgrt          # or the theme you had before
sudo update-initramfs -u -k all
sudo rm -r /usr/share/plymouth/themes/redrix-bgrt
```

**If the machine does not boot after installing:**

1. **Try an older kernel.** With systemd-boot, hold Space during power-on (or press it repeatedly) to show the menu;
   with GRUB, hold Shift or press Esc. Each kernel has its own initramfs; if one boots, run the commands above.
2. **Boot without the splash.** In GRUB, press `e` on the entry and remove `quiet splash` from the `linux` line,
   then Ctrl+X. (With systemd-boot and `editor no`, the command line cannot be edited at boot; use step 1 or 3.)
3. **From a live USB**, chroot into the installed system and run the same commands. For an unencrypted root on
   `/dev/nvme0n1pX` (adapt the names; with LUKS, open the volume first with `cryptsetup open`):

   ```sh
   sudo mount /dev/nvme0n1pX /mnt                  # root filesystem (add -o subvol=@ for a btrfs layout)
   sudo mount /dev/nvme0n1pY /mnt/boot             # if /boot is a separate partition
   sudo mount /dev/nvme0n1pZ /mnt/boot/efi         # if the ESP is mounted there
   for d in dev proc sys run; do sudo mount --rbind /$d /mnt/$d; done
   sudo chroot /mnt
   plymouth-set-default-theme bgrt && update-initramfs -u -k all
   exit
   ```

Plymouth does not hold the disk-unlock logic itself: systemd-cryptsetup only asks for the passphrase through it. A
theme problem affects how the prompt looks, not the encrypted disk.

## Known limitations

- **A black flash of 0.3 to 0.5 s before the disk-unlock prompt** remains with Debian's kernel 7.2: the i915 driver
  refuses to take over the firmware's display mode as is (`fastset requirement not met in set_context_latency`) and
  does a full modeset, which turns the panel off and on. It is a kernel issue; see
  [troubleshooting](../troubleshooting.md).
- The logo position follows the firmware's BGRT data. If you rebuild the firmware with another logo, nothing needs to
  change here: the theme reads the image and its position at boot.
- Not available for dracut-based systems through the installer (see Requirements).
