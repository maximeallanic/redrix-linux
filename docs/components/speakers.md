# Speaker protection files (`speakers`)

Installs the DSM parameter files of the four speaker amplifiers, extracted from Google's own recovery image for this
model, so the amplifiers run with their speaker model and protection instead of without it.

## Risk level: medium

It downloads about 1.5 GB from Google and writes four files into `/lib/firmware`. The files are checked against
hashes pinned in the kit before anything is installed. Not preselected: you are asked to confirm.

## Background

The Redrix has four Maxim MAX98390 smart amplifiers: two woofers (`MX98390:00` right, `:01` left) and two tweeters
(`:02` right, `:03` left). Each one loads a DSM ("dynamic speaker management") parameter file at probe time. Without
it the kernel logs, for each amplifier:

```
Direct firmware load for dsm_param_R_Google_Redrix.bin failed with error -2
```

Sound still works without the files, but the amplifiers run with no speaker model: no excursion or thermal
protection tuned for these drivers, and a thinner sound. The factory calibration of each amplifier (`r0_calib`,
`temperature_calib`) is separate: the kernel reads it from the firmware's VPD through ACPI `_DSD`, and it works
without this component.

The DSM files are Google's. They are not redistributed by this kit, and nothing in Debian ships them. The component
fetches them from the official ChromeOS recovery image for Redrix:

1. Read Google's recovery index (`https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json`) and take the
   first stable-channel entry for `REDRIX`.
2. Download the image (about 1.5 GB) and check its SHA-1 against the index.
3. Unzip it (about 5 GB), attach the ROOT-A partition read-only on a loop device, and copy the four files out with
   `debugfs` (nothing is mounted).
4. Compare them with the SHA-256 hashes pinned in `components/speakers/dsm-param-redrix.sha256`. If any differs, stop
   and install nothing: a newer image that changes them needs a deliberate review and a manifest update.
5. Install the four files into `/lib/firmware`, then delete the work directory.

If the installed files already match the pinned hashes, nothing is downloaded.

Files for other boards (for example Gimble, which uses the same amplifiers) must not be used: the parameters are
specific to the speakers they were tuned for.

## What the installer changes

| Path | Content |
|---|---|
| `/lib/firmware/dsm_param_L_Google_Redrix.bin` | left woofer |
| `/lib/firmware/dsm_param_R_Google_Redrix.bin` | right woofer |
| `/lib/firmware/dsm_param_tt_L_Google_Redrix.bin` | left tweeter |
| `/lib/firmware/dsm_param_tt_R_Google_Redrix.bin` | right tweeter |
| `/var/tmp/redrix-recovery.XXXXXX/` | temporary: the image and its contents, deleted when the script exits |

Each file is 712 bytes. Pinned SHA-256:

```
1876bf17d55920af3ea617ad5b4a0092b9d80de1aa0d0c651adca1a3537e9d95  dsm_param_L_Google_Redrix.bin
f6e9bd1a6d5e7345188b1bf405af27100e8ca2bd33947223f56c009e2180e6cb  dsm_param_R_Google_Redrix.bin
1a00e88720eab59a1e06bd89f50011fba0f2f4712ccaf10e11300f65900501e2  dsm_param_tt_L_Google_Redrix.bin
581b8b391ea7a58cab390f0e7cbc0cbdba896565286cf76f767954cafac411e0  dsm_param_tt_R_Google_Redrix.bin
```

The amplifiers load the files when they probe: **reboot** after installing.

Debian packages: `curl`, `unzip`, `fdisk` (sfdisk), `e2fsprogs` (debugfs), `python3`.

## Requirements

- **7 GB free in `/var/tmp`** during the install (the zip and its unpacked image).
- About 1.5 GB of download from `dl.google.com`.
- The four MAX98390 amplifiers present (`/sys/bus/i2c/devices/i2c-MX98390:*`); the component is hidden otherwise.
- **The Chromebook audio configuration**, for any speaker output at all: on a stock Debian install the only output
  is "Dummy Output". The community script
  [WeirdTreeThing/chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) installs the SOF
  firmware and topology (`sof-adl-max98390-rt5682.tplg`) and the Chromebook UCM configuration into
  `/usr/share/alsa/ucm2/conf.d/`. The kit does not install it; read the script before running it. This component
  works without it (the files are loaded by the kernel), but the last verify check needs the UCM speaker output.

## Verify

```sh
./verify.sh speakers
```

| Check | Meaning |
|---|---|
| `<file> installed, matches its pinned hash` (x4) | each file is in `/lib/firmware` with the pinned SHA-256 |
| `the 4 MAX98390 amplifiers are bound to their driver` | the kernel driver probed all four |
| `all amplifiers loaded their DSM file this boot` | no `Direct firmware load for dsm...` failure in this boot's kernel log |
| `factory calibration read for the 4 amplifiers` | four non-zero `r0_calib` values in the kernel log |
| `speaker output available` | PipeWire has the UCM speaker sink (`HiFi__Speaker__sink`) |

The two kernel-log checks need to read this boot's kernel log (as a member of `adm` or `systemd-journal`, or through
sudo without a password prompt); otherwise they are skipped with a hint. They are also skipped if the log no longer
holds the four probe lines.

Output on a tested machine:

```
Speaker protection files (speakers)
  [ OK ] dsm_param_L_Google_Redrix.bin installed, matches its pinned hash
  [ OK ] dsm_param_R_Google_Redrix.bin installed, matches its pinned hash
  [ OK ] dsm_param_tt_L_Google_Redrix.bin installed, matches its pinned hash
  [ OK ] dsm_param_tt_R_Google_Redrix.bin installed, matches its pinned hash
  [ OK ] the 4 MAX98390 amplifiers are bound to their driver
  [ OK ] all amplifiers loaded their DSM file this boot
  [ OK ] factory calibration read for the 4 amplifiers
  [ OK ] speaker output available
  Speaker protection files: all 8 checks passed
```

## Uninstall

```sh
./uninstall.sh speakers
```

By hand:

```sh
sudo rm /lib/firmware/dsm_param_L_Google_Redrix.bin /lib/firmware/dsm_param_R_Google_Redrix.bin \
  /lib/firmware/dsm_param_tt_L_Google_Redrix.bin /lib/firmware/dsm_param_tt_R_Google_Redrix.bin
```

Then reboot: the amplifiers run without DSM parameters again.

## Known limitations

- The download is large for four small files. There is no smaller official source.
- If Google ships a recovery image whose files differ from the pinned ones, the component refuses to install until
  the kit's manifest is reviewed and updated.
- Harmless kernel messages that remain after installing, all seen on working machines:
  `max98390 ... Put adaptive rdc not supported` (from `alsa-restore`), `NHLT table not found`,
  `Parent card not yet available`. See [troubleshooting](../troubleshooting.md).
