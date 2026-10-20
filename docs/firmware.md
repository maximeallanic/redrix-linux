# Firmware: MrChromebox UEFI Full ROM

This page explains why the kit's results were obtained on MrChromebox's UEFI firmware, how that firmware gets onto
the machine, and the optional tool in `tools/firmware/` that rebuilds it with your own boot logo.

> **Warning.** Everything on this page writes, or prepares to write, the machine's SPI flash: the code the processor
> runs before any operating system. A mistake can leave the laptop unable to power on ("bricked"). Recovery then
> needs extra hardware (a SuzyQ debug cable, or an SPI clip and programmer) and a backup of the original flash that
> you made *before* changing anything. Opening CCD also erases the TPM. Nothing in this kit flashes firmware
> automatically, and nothing here is required to use the kit's other components on firmware you already run. Read
> the whole page and MrChromebox's own documentation first. You proceed at your own risk.

The authoritative documentation is MrChromebox's: <https://docs.mrchromebox.tech/>. In particular:

- supported devices and firmware types: <https://docs.mrchromebox.tech/docs/supported-devices.html>
- disabling write protection: <https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html>
- the Firmware Utility Script: <https://docs.mrchromebox.tech/docs/fwscript.html>
- recovering from a bad flash: <https://docs.mrchromebox.tech/docs/support/unbricking/>, with
  [SuzyQ](https://docs.mrchromebox.tech/docs/support/unbricking/unbrick-suzyq.html) and
  [CH341A](https://docs.mrchromebox.tech/docs/support/unbricking/unbrick-ch341a.html) guides

MrChromebox's firmware, scripts and documentation are the work of that project; this page only records what was
done on one Redrix.

## Why UEFI Full ROM

On the stock ChromeOS firmware, Linux boots through a ChromeOS-style kernel partition (for example with Submarine) in
developer mode. That works, with costs:

- **Suspend crashed the machine.** The EC reported `reset: ap hang detected` after s2idle. In one case the Wi-Fi card
  stayed dead until a full power-off.
- **The developer-mode warning screen** shows at every boot: 30 seconds or Ctrl+D. Shortening it needs a GBB flag
  (below), which already needs write protection off.
- **No UEFI**, so no BGRT boot logo for Plymouth, no Secure Boot, no standard boot loader.

With MrChromebox's UEFI Full ROM (2609.1 tested):

- S3 suspend works (see [suspend](components/suspend.md)); s2idle no longer crashes but does not reach S0ix.
- The machine boots like a regular UEFI PC: an EFI System Partition, systemd-boot or GRUB, and Secure Boot with
  Microsoft's UEFI CA 2011 and 2023 certificates in `db`, so Debian's signed shim boots (see
  [boot chain](boot-chain.md)).
- The firmware draws a logo and publishes it as the ACPI BGRT image ([boot-splash](components/boot-splash.md),
  [shutdown-splash](components/shutdown-splash.md)).
- MrChromebox's script keeps the machine's HWID and VPD data (serial numbers, and the speaker amplifiers' factory
  calibration, which the kernel reads from VPD).

It is a one-way trip in practice: going back to ChromeOS means flashing the stock firmware backup again and running
a ChromeOS recovery, which erases the disk.

## Before anything: what you need

- **A full backup of the stock flash**, read twice, compared, and copied off the machine (below).
- **Your LUKS passphrase**, if the disk is encrypted with a TPM key slot: opening CCD wipes the TPM.
- **A way to recover** if the flash goes wrong: a SuzyQ cable ("SuzyQable", a USB-C debug cable for Closed Case
  Debugging) and a second computer, or an SPI flash programmer (CH341A or similar) with a SOIC-8 clip.
- AC power connected for the whole procedure.

## Write protection

The firmware's read-only part is protected by a hardware write-protect signal controlled by the Cr50 security chip.
On this board:

| Method | Notes |
|---|---|
| **SuzyQ + CCD** | Documented method for Cr50 devices. Enable developer mode; from a root shell, open CCD with `gsctool -a -o` and press the power button each time you are asked (two to five minutes). Then plug the SuzyQ into the **top-left USB-C port** (the debug port) and, on the Cr50 console (`/dev/ttyUSB0`), run `wp false` and `wp false atboot` (or `ccd reset factory`). Check with `crossystem wpsw_cur` (0 = off) |
| **Battery disconnected** | On the tested unit, running from the charger with the battery unplugged gave `Flash WP: disabled` (the Cr50 setting was "at boot: follow_batt_pres"). Opening the case is required; MrChromebox's device table did not list this method for the board when checked, so treat it as an observation |

**Opening CCD wipes the TPM.** `gsctool -a -o` ends in `ccd_open_done()` -> `board_wipe_tpm`, then a reboot. Any LUKS
TPM2 key slot stops working; the passphrase slot keeps working. Re-enroll afterwards (once you will not open CCD
again):

```sh
sudo systemd-cryptenroll /dev/<luks-partition> --wipe-slot=tpm2
sudo systemd-cryptenroll /dev/<luks-partition> --tpm2-device=auto --tpm2-with-pin=yes --tpm2-pcrs=
```

On the tested unit, the wipe also reset the hardware clock and left CCD locked again after a reboot loop; the
battery method then worked.

`gsctool` is not packaged in Debian. It builds from the `gsc_utils` branch of
<https://chromium.googlesource.com/chromiumos/platform/ec> (`make -C extra/usb_updater gsctool`; needs
`libusb-1.0-0-dev`, `libssl-dev`, `pkg-config`).

Developer mode itself powerwashes the machine (all local ChromeOS data is erased).

## Mandatory: back up the stock flash

From Linux, `flashrom` needs `iomem=relaxed` on the kernel command line (otherwise: `Cannot map ecam region`), and
Secure Boot off (kernel lockdown blocks it).

```sh
sudo flashrom -p internal -r stock-1.rom
sudo flashrom -p internal -r stock-2.rom
sha256sum stock-1.rom stock-2.rom          # both must match; otherwise read again
```

Copy the file to another machine and to removable storage. MrChromebox's Firmware Utility Script also offers to save
the stock firmware to USB before flashing: accept. Without this backup, a bad flash may be unrecoverable, and the
board-specific data in it (HWID, VPD) cannot be recreated.

## GBB flags (stock firmware only)

If you stay on the stock firmware, the developer screen delay can be shortened with GBB flag `0x1`
(`VB2_GBB_FLAG_DEV_SCREEN_SHORT_DELAY`: 2 seconds instead of 30, then boots by itself). It sits in the read-only
`GBB` region, so write protection must be off:

```sh
sudo flashrom -p internal --wp-disable
sudo flashrom -p internal --wp-range 0,0
sudo flashrom -p internal -r --fmap -i GBB:gbb.bin
futility gbb --set --flags=0x1 gbb.bin
sudo flashrom -p internal -w --fmap -i GBB:gbb.bin
```

Read back and check with `futility gbb --get --flags`. This flag does nothing once the UEFI Full ROM is installed.
This procedure was prepared but not carried out on the tested unit (the UEFI firmware was chosen instead).

## Installing the UEFI Full ROM

Follow MrChromebox's instructions: run the Firmware Utility Script and choose **Install/Update UEFI (Full ROM)
Firmware**. It backs up the stock firmware, keeps the HWID and VPD, and flashes. On the tested unit, the first UEFI
boot found the disk's `EFI/BOOT/BOOTX64.EFI` and booted. Prepare that boot path *before* flashing: see
[boot chain](boot-chain.md), especially if Linux currently boots through ChromeOS kernel partitions and the disk has
no EFI System Partition.

Notes from the tested unit:

- A SuzyQ cannot flash the main firmware from the same machine: `flashrom -p raiden_debug_spi:target=AP` pauses the
  processor that would run flashrom. Flash internally (script or `flashrom -p internal`).
- After flashing, `/sys/power/mem_sleep` shows `[s2idle] deep`.
- Leave the flash chip's protected range empty: `SMMSTORE` (UEFI variables) and `RW_MRC_CACHE` must stay writable.

## Firmware password and Secure Boot

MrChromebox's UEFI setup (Esc at power-on) can set a firmware password. With one set, it is needed to turn Secure
Boot off, which is needed before any later flash. If it is lost: unplug the battery, open CCD from the Cr50 console
with the SuzyQ, and reflash the whole BIOS region from your backup kit; that also resets the UEFI variables and the
password. This recovery was not exercised on the tested unit.

## Optional: rebuild the firmware with your own logo

`tools/firmware/build-firmware.sh` rebuilds MrChromebox's Full ROM for Redrix with two optional changes:

- **your boot logo** (a 24-bit BMP), which also becomes the ACPI BGRT image Plymouth redraws;
- **no "Press ESC for Boot Options/Settings" text** under the logo (`edk2-hide-boot-prompt.patch`; Esc still
  works). The text is hardcoded in edk2's `PlatformBootManager.c`, with no setting.

Everything else (the release's `.config`, this machine's HWID) is read back from an image of your own machine.

**It never flashes anything.**

### Inputs

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `REF_ROM` | yes | none | a BIOS-region image of **this** machine running MrChromebox `$RELEASE`: `sudo flashrom -p internal -r bios.rom --ifd -i bios` |
| `LOGO` | no | MrChromebox's default logo | path to a 24-bit BMP |
| `HIDE_PROMPT` | no | `1` | `1` applies the edk2 patch; `0` removes it from the tree |
| `RELEASE` | no | `MrChromebox-2609.1` | MrChromebox coreboot tag |
| `TREE` | no | `~/.cache/redrix-linux/coreboot-$RELEASE` | where the coreboot tree is cloned (several GB) |
| `SDK` | no | `coreboot/coreboot-sdk:2026-07-06_c165edb4ce` | pinned coreboot SDK container image |

Docker is required (rootless works). Scratch files go to `/var/tmp`.

```sh
REF_ROM=~/bios.rom LOGO=~/logo.bmp tools/firmware/build-firmware.sh
```

### Steps

1. Clone MrChromebox's coreboot at `$RELEASE` (shallow, with the vboot, blobs, FSP and microcode submodules) and check
   the tag.
2. Build `cbfstool` in the SDK container; extract the release `.config` and the machine's `hwid` from `REF_ROM`.
   With `LOGO`, set `CONFIG_EDK2_BOOTSPLASH_FILE` to it; run `make olddefconfig`.
3. Fetch the edk2 payload at the revision the `.config` names, then apply (or remove) the prompt patch.
4. Build in the SDK container.
5. Write the HWID back into the image.

Output: `$TREE/build/coreboot.rom`.

### Flashing the result (manual, at your own risk)

> **Warning.** Only flash an image built from a `REF_ROM` of the same machine and the same release, and only with a
> verified full backup at hand and a recovery path (SuzyQ with CCD open, or an SPI programmer). Do not flash the
> whole chip: write the `COREBOOT` region only.

1. Turn Secure Boot off in the firmware setup (Esc at power-on; firmware password if set).
2. Boot with `iomem=relaxed` on the kernel command line (with systemd-boot and `editor no`: add it to
   `/etc/kernel/cmdline`, run `sudo kernel-install add-all`, reboot; or use a rescue GRUB entry).
3. Flash the `COREBOOT` region only, using the image's own flash map:

   ```sh
   sudo flashrom -p internal --fmap-file coreboot.rom -i COREBOOT -w coreboot.rom
   ```

4. Reboot, check the logo, then remove `iomem=relaxed` and turn Secure Boot back on.

On the tested unit, the rebuilt image with a custom logo and the patch differed from the reference image only in
`fallback/payload`.

## Recovery

If the machine no longer boots after a flash:

- **SuzyQ (CCD).** From a second computer, with CCD open on the broken machine, flash your full backup:
  `flashrom -p raiden_debug_spi:target=AP -w stock-1.rom`. With CCD locked, the Cr50 refuses AP flashing; unlocking it
  from the Cr50 console works with the battery disconnected (`ccd open`, then power-button presses). See
  MrChromebox's unbricking page.
- **External programmer (CH341A or similar).** Open the case, clip the SPI flash chip and write the full backup.
  Check the chip's voltage before connecting (many CH341A boards drive 5 V on data lines; use a 1.8 V or 3.3 V
  adapter matching the chip). Follow MrChromebox's unbricking page.
- **No backup:** MrChromebox publishes generic firmware images, but board-specific data (HWID, VPD, factory
  calibration of the speaker amplifiers) is lost. This is why the backup is mandatory.
