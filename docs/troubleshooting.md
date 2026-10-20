# Troubleshooting

Problems seen on the Redrix under Debian testing and GNOME, with their cause when it is known. Start with the kit's
own checks, which print a hint under each failure:

```sh
./verify.sh                 # every installed component
./verify.sh camera pen      # only these
```

## The kit

### `extension ... is ERROR`, `INACTIVE` or `unknown` right after installing

GNOME Shell on Wayland loads an extension's code once per session; a newly installed extension is not seen until the
next login. Log out and back in once, then run `./verify.sh` again. If it still reports `ERROR`:

```sh
gnome-extensions info <uuid>
journalctl --user -b -o cat /usr/bin/gnome-shell | grep -i -A5 '<uuid>'
```

The kit's extensions declare GNOME Shell 50 and 51. On another version GNOME marks them `OUT_OF_DATE`.

### `no write access to /dev/hidrawN` (haptics) or a Keychron device not reachable

`uaccess` rules grant access to the user of the *active* session when the device appears or the session starts. Log
out and back in, or unplug and replug the device.

### A check needs root

Some checks read files only root can read (the kernel keymap, fprintd's memory map, the initramfs). They print an
INFO line with the command to run yourself instead of failing.

## Display and boot

### Black flash of 0.3-0.5 s just before the disk-unlock prompt

**Cause (kernel):** when i915 takes over the display the firmware set up, it tries a "fastset" (keep the mode as is).
On Debian's 7.2 kernel the check fails with:

```
fastset requirement not met in set_context_latency (expected 0, found 1)
```

so the driver does a full modeset, which powers the panel off and on (`PPS 0 turn panel power off`). In
`intel_display.c`, the vblank-start difference is exempted for state inherited from the firmware
(`allow_vblank_delay_fastset`), but `PIPE_CONF_CHECK_I(set_context_latency)` is not. When last checked it was not
fixed in mainline or `drm-intel-next`.

**Workaround:** none in the kit. It is left as is until a kernel fix.

### The screen goes black or shows text early in boot, before the splash

**Cause:** the framebuffer console takes over and clears the screen. Debian's kernel is built without
`CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER`, which would otherwise keep the firmware picture until something is
printed.

**Fix:** add `fbcon=vc:2-6` to the kernel command line (the console stays off the first virtual terminal, where the
splash is drawn). With GRUB: `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then `sudo update-grub`. With
systemd-boot and `kernel-install`: `/etc/kernel/cmdline`, then `sudo kernel-install add-all`.

### No logo during boot, only text

The kernel command line lacks `splash`. See [boot-splash](components/boot-splash.md#requirements).

### Text appears for a moment at logout or shutdown

Seen when `plymouth.debug` was on the kernel command line: Plymouth writes its trace to tty1, which shows during the
gap between the end of GNOME Shell and the login screen or the shutdown screen. Remove `plymouth.debug`. The short
black gap itself remains; [shutdown-splash](components/shutdown-splash.md) fades to black over it.

### GNOME stutters or freezes (community report)

On the community thread for this board, `i915.enable_psr=0 i915.enable_fbc=1` was suggested against GNOME stutter.
It was not needed on the tested setup (GNOME 51, panel self-refresh PSR2 active). GNOME 51 also fixed a Shell CPU
spike during fades with fractional scaling on Alder Lake ([mutter#4979](https://gitlab.gnome.org/GNOME/mutter/-/issues/4979)).
Disabling PSR costs battery: try it only if you see the problem.

### A fractional scale around 150-160 % is not offered

On the native 2256x1504 resolution, Mutter only accepted 100, 133, 200 and 267 % (observed on GNOME 50): a scale is
valid only if it gives a whole-number logical size. `video=` modes on the kernel command line do not help, since i915
keeps only the panel's native mode on eDP. The only route found was patching Mutter.

## Keyboard

### The lock key suspends the machine

atkbd maps that key (scancode `0x5d`) to `KEY_SLEEP`. Install [top-row](components/top-row.md).

### The lock key does nothing in GNOME

[mutter#3990](https://gitlab.gnome.org/GNOME/mutter/-/issues/3990): Mutter's case-insensitive keysym lookup sends the
`XF86ScreenSaver` binding to xkbcommon's newer `XF86Screensaver` keysym. [top-row](components/top-row.md) adds the
keycode `0xa0` to the lock shortcut. By hand:

```sh
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l', '0xa0']"
```

### The keyboard backlight stays off

Seen once after about two days of uptime: the backlight stayed dark while sysfs (`chromeos::kbd_backlight`), UPower
and the EC (requested level 100 %, PWM at maximum, enable line high) all said it was on. A reboot did not help; a
**full power-off** followed by a cold start did, although the EC itself had not restarted. Whatever is stuck sits
after the EC, on a supply only cut in S5. The trigger is unknown (unplugging a USB-C dock is suspected, not proven).

## Wi-Fi

### Wi-Fi gone: `probe with driver iwlwifi failed with error -110`

Seen after the machine crashed during s2idle suspend on the stock firmware: `iwlwifi` fails with `CSR_RESET = 0x10`
and `error -110`, and NetworkManager reports `WIFI-HW missing`. Reloading the module or removing and rescanning the
PCI device changes nothing: a warm reboot does not cut the card's power.

**Fix:** a full power-off, wait about 30 seconds with the charger unplugged, then power on.

If the machine asks for the disk's TPM PIN or passphrase when you did not shut it down, it crashed during suspend.
On MrChromebox's firmware, use S3: [suspend](components/suspend.md).

## Suspend

### The machine wakes up a second after suspending

The haptic touchpad's interrupt wakes it from S3. [suspend](components/suspend.md) disables the touchpad as a wake
source.

### Suspend crashes or drains the battery

- Stock ChromeOS firmware: suspend crashed the EC (`reset: ap hang detected`). Move to MrChromebox's UEFI firmware
  ([firmware](firmware.md)).
- UEFI firmware with s2idle: no crash, but no S0ix (`cat /sys/kernel/debug/pmc_core/slp_s0_residency_usec` stays 0
  as root). Use S3: [suspend](components/suspend.md).
- KDE Plasma: a community report on the stock firmware said Plasma broke suspend on this board. Not tested on the
  UEFI firmware.

### `\_SB.PCI0.RP06.RTD3._STA` not found, at each S3 entry

A firmware ACPI table bug, without visible effect.

## Audio

### Only "Dummy Output"

Debian alone does not configure this board's audio (SOF with RT5682 and MAX98390). Install the Chromebook audio
configuration from [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio); read the script
first. Then restart PipeWire or log out and back in.

### `Direct firmware load for dsm_param_..._Google_Redrix.bin failed with error -2`

The speaker amplifiers' DSM files are missing. Install [speakers](components/speakers.md), then reboot.

### `max98390 ... Put adaptive rdc not supported`

Written when `alsa-restore` restores mixer controls. Harmless.

### The microphone and an HDMI output freeze together

Seen when the noise suppression module took its echo reference from a real output: the microphone then follows that
output's clock, which it cannot. The kit's [microphone](components/microphone.md) configuration avoids it; if you
edited it to add an echo reference, revert the file.

## Camera

### Washed-out, greenish picture; `Failed to create camera sensor helper for hi556`

No tuning file for the sensor: libcamera uses `uncalibrated.yaml`. Install [camera](components/camera.md). The sensor
helper warning itself remains (libcamera has no gain model for the hi556).

### Applications list dozens of cameras

The 32 raw IPU6 nodes. [camera](components/camera.md) hides them.

## Pen and touchpad messages

### `hid-multitouch ... hid_field_extract() called with n (64) > 32!`

The pen reports a 64-bit serial number; the kernel's HID field extraction handles at most 32 bits. Harmless: the pen
works.

### `ELAN2703 ... incorrect report (255 vs 112)` or similar

Not the touchpad driver: fwupd's `elantp` plugin reads the haptic touchpad's EEPROM at boot and logs this. Harmless.
Disabling the plugin would silence it but also stop touchpad firmware updates through fwupd.

## Sensors

### `cros-ec-sensorhub ... unknown type 8`

The EC reports an RGB light sensor (type 8) and the kernel's sensor list stops at 7. The regular ambient light sensor
(type 4) works. A kernel gap, harmless.

## Fingerprint

### `fprintd-list` says `No devices available`

Debian's libfprint has no driver for this sensor. Install [fingerprint](components/fingerprint.md).

### `FP_INFO ... INVALID_VERSION`

The crfpmoc driver of the `feature/crfpmoc` libfprint branch alone only sends `FP_INFO` version 1, which this MCU
firmware refuses. The kit grafts newer driver files that negotiate the version; see
[fingerprint](components/fingerprint.md).

### Logged in with a finger, then asked for the keyring password

Expected: the GNOME keyring is encrypted with your password. See [fingerprint-login](components/fingerprint-login.md).

## Firmware and TPM

### `flashrom`: `Cannot map ecam region`

Boot with `iomem=relaxed` on the kernel command line. With Secure Boot on, kernel lockdown also blocks flashrom:
turn Secure Boot off first. See [firmware](firmware.md).

### `systemd-cryptenroll --tpm2-device=auto` fails with `TPM_RC_BAD_AUTH` (`0x9a2`)

ChromeOS owns the TPM with passwords Linux does not know (`ownerAuthSet: 1` in `tpm2_getcap properties-variable`). The
TPM has to be cleared first; opening CCD clears it (see [firmware](firmware.md)).

### Debian's `crossystem` answers `nonchrome`

Debian's `vboot-utils` looks for `/sys/devices/platform/chromeos_acpi`; this kernel exposes the interface as
`/sys/devices/platform/GOOG0016:00`. Upstream `vboot_reference` handles it: build `crossystem` from upstream if you
need it (for example `crossystem wpsw_cur` to check write protection).

## Other known limits

- **Widevine L1** is lost when leaving ChromeOS: streaming services fall back to L3, typically capped at 720p.
- **USB-C storage** had to be connected at boot to be seen, according to a community report on the stock firmware.
  Not re-tested on the UEFI firmware.

See [hardware support](hardware-support.md) for the full status of each device.
