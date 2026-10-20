# Third-party notices

The code of this repository (installer, components, configuration files, tools, tests) is released under the MIT
License (see `LICENSE`). Everything below keeps its own license. The rule of the kit: **third-party code, firmware and
data are never committed here.** When a component needs them, it fetches them from their upstream at a pinned commit
or checks them against a pinned SHA-256, or it derives them on your machine from a package you already have.

## Fetched or derived at install time (not redistributed here)

| What | Upstream | License | How the kit uses it |
|---|---|---|---|
| **libfprint with the crfpmoc driver** | <https://gitlab.freedesktop.org/3v1n0/libfprint> (branch `feature/crfpmoc`, Marco Trevisan) | LGPL-2.1-or-later | `fingerprint` clones commit `56442591a5c3`, builds it on your machine and installs it into `/usr/local`. |
| **crfpmoc driver revision** | <https://github.com/samson1357924/hp-pro-c640-chromebook-linux> (`fingerprint/driver/`; Abhinav Baid, Felix Niederer, Marco Trevisan, Samson) | LGPL-2.1-or-later (per its `REUSE.toml`) | `fingerprint` clones commit `b58b5ac1c6c0` and grafts its driver files into the libfprint tree before building. |
| **Speaker DSM parameter files** (`dsm_param_*_Google_Redrix.bin`) | Google's official ChromeOS recovery image for Redrix, listed in <https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json> | Google's terms for ChromeOS recovery images; **not redistributable by this project** | `speakers` downloads the image on your machine, reads the four files from it without mounting it, and installs them only if they match the SHA-256 values in `components/speakers/dsm-param-redrix.sha256`. The image is deleted afterwards. |
| **Plymouth `bgrt` and `spinner` themes** | `plymouth-themes` package of your distribution (<https://gitlab.freedesktop.org/plymouth/plymouth>) | GPL-2.0-or-later | `boot-splash` generates its theme from the installed `bgrt.plymouth`; `shutdown-splash` copies the installed spinner frames. Nothing of Plymouth is stored here. |
| **Firmware boot logo** | your machine's firmware (ACPI BGRT table) | belongs to the firmware vendor | `shutdown-splash` converts the logo your firmware already shows into a PNG on your machine. |
| **Solaar** | <https://github.com/pwr-Solaar/Solaar> | GPL-2.0-or-later | Installed from your distribution; `haptic-bridge` imports it as a library for the optional MX Master 4 haptics. |

## Not shipped at all

- **Firmware images.** `tools/firmware/build-firmware.sh` builds MrChromebox's coreboot/edk2 firmware from source on
  your machine and never flashes it; no ROM is stored here. Read [docs/firmware.md](docs/firmware.md) first.
- **Logos.** The kit uses whatever logo your firmware already displays; it ships none, and the firmware build script
  only embeds a logo if you give it a BMP of your own.
- **Audio topology and UCM.** They come from your distribution and from
  [WeirdTreeThing/chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) (BSD-3-Clause),
  which you install yourself beforehand.

## Written for this kit, with reference to other work

- `components/haptics/haptic_touchpad.py`: the Google vendor waveform ids and their use follow Chromium's
  `ui/events/ozone/evdev/libgestures_glue/haptic_touchpad_handler.cc` (BSD-3-Clause, The Chromium Authors). No
  Chromium code was copied; only the protocol constants, which describe the hardware.
- `components/pen/*.tablet`, `*.stylus`: data files in the format of [libwacom](https://github.com/linuxwacom/libwacom)
  (HPND-style permissive license, Red Hat), written for this machine's ELAN 2F75 panel.
- `components/camera/hi556.yaml`: a [libcamera](https://libcamera.org) software-ISP tuning file, measured on this
  hardware, released as CC0-1.0 so that it can go upstream.
- `components/microphone`: a configuration of PipeWire's `libpipewire-module-echo-cancel` with the WebRTC audio
  processing backend (PipeWire: MIT; webrtc-audio-processing: BSD-3-Clause).
- `tools/firmware/edk2-hide-boot-prompt.patch`: a patch against MrChromebox's edk2 fork (BSD-2-Clause-Patent).
