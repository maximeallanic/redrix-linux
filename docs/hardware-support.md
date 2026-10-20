# Hardware support

What works on the HP Elite Dragonfly Chromebook (board `redrix`, Intel Core i7-1265U, Alder Lake-P) under Linux,
with and without this kit. "Out of the box" means a stock Debian testing install with GNOME, on MrChromebox's UEFI
firmware, before installing any component.

## Tested configuration

| Item | Version |
|---|---|
| Firmware | MrChromebox UEFI Full ROM 2609.1 (see [firmware](firmware.md)) |
| Distribution | Debian testing ("forky") |
| Desktop | GNOME 51 on Wayland |
| Kernel | Debian 7.2 (7.2.8) |

One machine was tested. Other units of the same model should behave the same, but unit-to-unit differences (camera
calibration, battery wear) have not been measured. Older firmware, other distributions and other desktops are not
covered by these results.

## Legend

| Status | Meaning |
|---|---|
| Works | works out of the box |
| Works with kit | needs a kit component (named) or a documented external step |
| Partial | usable, with a limitation described in the row |
| Not working | does not work, no known fix |
| Unknown | not tested |

## Matrix

| Hardware | Status | Notes |
|---|---|---|
| CPU (i7-1265U) | Works | power-profiles-daemon drives the energy/performance preference (balanced-performance on AC, balanced-power on battery). TLP and thermald are not needed |
| GPU (Iris Xe, i915) | Works | Mesa, Vulkan and VA-API work. Hardware AV1 decoding needs Debian's `intel-media-va-driver-non-free` (non-free section): the free driver is built without it. The newer `xe` driver still needs `force_probe` for Alder Lake-P in 7.2 and brings nothing here |
| Internal display (2256x1504, 3:2, touch) | Partial | Works, including panel self-refresh (PSR2 with selective update). Fractional scaling: on GNOME 50, Mutter only accepted 100, 133, 200 and 267 % at the native resolution, so a value around 150-160 % is not available without patching Mutter. GNOME 51 fixes a Shell CPU spike during fades with fractional scaling on Alder Lake ([mutter#4979](https://gitlab.gnome.org/GNOME/mutter/-/issues/4979)). A 0.3-0.5 s black flash before the disk-unlock prompt remains (see [troubleshooting](troubleshooting.md)) |
| Touchscreen (ELAN2513) | Works | Multi-touch, GNOME gestures |
| Pen (USI, ELAN `04f3:2f75`) | Works with kit | Hover, touch, pressure work out of the box (38 levels seen, no tilt). The [pen](components/pen.md) component tells libwacom and GNOME that the digitiser is part of the laptop display (keeps it on that screen with an external monitor) and draws a dot instead of the mouse arrow |
| Keyboard | Works | Vivaldi top row: back, refresh, overview, screenshot, brightness, keyboard backlight, media and volume keys work |
| Top row: lock and fullscreen keys | Works with kit | The lock key suspends by default and GNOME misses the lock keysym ([mutter#3990](https://gitlab.gnome.org/GNOME/mutter/-/issues/3990)); the fullscreen key is unbound. Component [top-row](components/top-row.md) |
| Keyboard backlight | Works | 21 steps of 5 % (`chromeos::kbd_backlight`). It once stayed dark while every layer reported 100 %; a full power-off fixed it (see [troubleshooting](troubleshooting.md)). GNOME does not adjust it from the ambient light sensor on its own; the [Adaptive Brightness](https://github.com/dmy3k/gnome-adaptive-brightness) extension does (not part of this kit) |
| Touchpad (ELAN2703, haptic) | Works | Click, gestures and the click vibration work out of the box. Vibration on desktop events: component [haptics](components/haptics.md). The click strength itself cannot be changed with Debian's kernel (needs `CONFIG_HID_HAPTIC`) |
| Speakers (4 x MAX98390) | Works with kit | Needs the Chromebook audio configuration ([chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)); without it the only output is "Dummy Output". The [speakers](components/speakers.md) component adds the amplifiers' DSM files from Google's recovery image |
| Headphone jack (RT5682) | Works with kit | Outputs and headset microphone appear once the Chromebook audio configuration is installed. Not tested beyond being listed and selectable |
| Internal microphones | Partial | Need the Chromebook audio configuration. Mic1 works; Mic2 returns a saturated constant. Low raw level. Noise suppression: [microphone](components/microphone.md); no echo cancellation of the speakers |
| External display over USB-C | Works | Tested at 5120x1440, 144 Hz, 10 bpc with DSC; HDR modes offered. Resume with a USB-C dock is slower (USB resets, link training). Other video outputs not tested separately |
| USB-C storage | Partial | Reported on the community thread for this board (stock firmware era): on Alder Lake, a USB-C storage device had to be connected at boot to be seen. Not re-tested on the UEFI firmware |
| Camera (hi556 behind IPU6) | Partial | Works through libcamera 0.7.2 (software ISP), 1280x720 at 30 fps. Without tuning: washed out and slightly green. Component [camera](components/camera.md) fixes black level and colours; a cool cast in warm light remains |
| Wi-Fi (Intel AX211) | Works | After a crash during suspend on the stock firmware, the card failed to probe (`-110`) until a full power-off (a reboot did not help). See [troubleshooting](troubleshooting.md) |
| Bluetooth | Works | The controller works with GNOME's Bluetooth settings; a phone pairs and stays reachable. Bluetooth audio was not specifically tested |
| Fingerprint (FPMCU bloonchipper, FPC1025) | Works with kit | Debian's libfprint has no driver. Component [fingerprint](components/fingerprint.md) builds the out-of-tree crfpmoc driver; login with a finger is [fingerprint-login](components/fingerprint-login.md) |
| Suspend: S3 (deep) | Works with kit | Only on MrChromebox's UEFI firmware. The touchpad wakes the machine right after suspending unless its wake-up is disabled: component [suspend](components/suspend.md) |
| Suspend: s2idle | Partial | On the UEFI firmware it suspends but never reaches S0ix (`slp_s0_residency_usec` stays 0), so the battery drains. On the stock firmware, suspend crashed the EC (`reset: ap hang detected`) |
| Tablet mode | Works | Folding the screen switches GNOME to touch mode (on-screen keyboard). Lid angle, accelerometers and light sensor are exposed through `cros-ec` IIO devices |
| Screen rotation | Unknown | The accelerometers are present; automatic rotation was not specifically tested |
| Ambient light sensor | Works | `cros-ec-light` through iio-sensor-proxy; GNOME's automatic screen brightness uses it. A second, RGB light sensor of the EC is not supported by the kernel (`cros-ec-sensorhub ... unknown type 8`, harmless) |
| Battery | Works | Level, rate and health read correctly. Battery life was not measured with this kit; community reports give 5-7 h under Linux versus about 11 h under ChromeOS. Worn batteries can cut out at a few percent: [battery-guard](components/battery-guard.md) |
| TPM (Cr50, TPM 2.0) | Partial | ChromeOS takes ownership of the TPM with passwords Linux does not know, so `systemd-cryptenroll --tpm2-device` fails (`TPM_RC_BAD_AUTH`) until the TPM is cleared. Opening CCD clears it (see [firmware](firmware.md)); after that, TPM2 + PIN unlocking of a LUKS disk works |
| LTE modem | Unknown | Not tested and not covered by this kit |
| Widevine L1 (DRM) | Not working | Lost when leaving ChromeOS: streaming services fall back to L3, typically capped at 720p (for example Netflix) |
| ChromeOS features | Not working | No Android apps, no ChromeOS updates. Leaving ChromeOS also means developer mode and a powerwash (all local data erased) |

## Boot messages you can ignore

These appear on working machines and need no action. Details in [troubleshooting](troubleshooting.md).

| Message | Why |
|---|---|
| `dummy regulator` | normal on this platform |
| `cros-ec-sensorhub ... unknown type 8` | an EC RGB light sensor the kernel does not know |
| `NHLT table not found` | normal with SOF on this board |
| `Parent card not yet available` | probe ordering, resolved a moment later |
| `max98390 ... Put adaptive rdc not supported` | written by `alsa-restore`, harmless |
| ELAN2703 `incorrect report (255 vs 112)` | fwupd's ELAN plugin reading the haptic touchpad |
| `hid-multitouch ... hid_field_extract() called with n (64) > 32` | the pen's 64-bit serial number, a kernel limit |
| nvme `No UUID available` | normal for this drive |
