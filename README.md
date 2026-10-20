# redrix-linux

**The last mile of Linux on the HP Elite Dragonfly Chromebook: haptics, pen, camera, mic, speakers, suspend and
fingerprint, from one checklist where every step is optional, checked and reversible.**

[![CI](https://github.com/maximeallanic/redrix-linux/actions/workflows/ci.yml/badge.svg)](https://github.com/maximeallanic/redrix-linux/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Tested on Debian testing, GNOME 51, kernel 7.2](https://img.shields.io/badge/tested-Debian%20testing%20%C2%B7%20GNOME%2051%20%C2%B7%20kernel%207.2-informational)

[Français](README.fr.md) · [Hardware support](docs/hardware-support.md) · [Installation](docs/installation.md) ·
[Troubleshooting](docs/troubleshooting.md)

<p align="center">
  <img src="docs/assets/support-at-a-glance.svg" width="900"
       alt="Hardware support at a glance. Works out of the box: CPU, GPU, touchscreen, keyboard, keyboard backlight, haptic touchpad, external USB-C display, Wi-Fi, Bluetooth, tablet mode, ambient light sensor, battery. Works with the kit or a setup step: pen, lock and fullscreen keys, speakers, headphone jack, fingerprint reader, S3 suspend. Partial: internal display scaling, internal microphones, camera, USB-C storage, s2idle, TPM. Not working: Widevine L1, ChromeOS features. Untested: screen rotation, LTE modem.">
</p>

Board `redrix`, Intel Alder Lake, "Brya" family. Tested on one machine: Debian testing (forky), GNOME Shell 51 on
Wayland, kernel 7.2, MrChromebox UEFI firmware 2609.1. Ubuntu should work (same packaging tools) but has not been
tested; other distributions are [partly covered](docs/installation.md#other-distributions).

## Why

Getting Linux to boot on this Chromebook is the solved part: MrChromebox, chrultrabook and
[chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) take care of it. What is left is
a dozen small things that make the machine feel unfinished:

| Out of the box | With the kit |
|---|---|
| The haptic touchpad only vibrates on click | Short vibrations on window, workspace and lock events, and when the volume hits a limit ([haptics](docs/components/haptics.md)) |
| The pen jumps to the external monitor | The pen stays on the built-in screen and shows in Settings ([pen](docs/components/pen.md)) |
| The lock key suspends the machine; the fullscreen key does nothing | Lock locks, fullscreen works ([top-row](docs/components/top-row.md)) |
| Camera picture washed out and slightly green | Measured black level and colour matrix: colour error from dE 18.8 to 6.8 on a test chart ([camera](docs/components/camera.md)) |
| Fan and keyboard noise in calls | A noise-suppressed microphone, set as default: noise floor from -47.7 to -60.9 dBFS in a noisy room ([microphone](docs/components/microphone.md)) |
| `dsm_param_R_Google_Redrix.bin failed with error -2`: the amplifiers run without their speaker model | Google's own DSM files, extracted from the official recovery image on your machine ([speakers](docs/components/speakers.md)) |
| s2idle never reaches S0ix and drains the battery | S3 deep sleep on lid close, and the touchpad no longer wakes it a second later ([suspend](docs/components/suspend.md)) |
| No fingerprint driver in Debian's libfprint | The crfpmoc driver built for you, then optional login, unlock and `sudo` by finger ([fingerprint](docs/components/fingerprint.md)) |
| The firmware logo gives way to another splash, and shutdown jumps to text | The logo stays from power-on to the login screen ([boot-splash](docs/components/boot-splash.md)); shutdown fades to it ([shutdown-splash](docs/components/shutdown-splash.md)) |

The numbers come from the tested machine; each component page explains how they were measured.

## Quick start

From your normal user account, in a terminal inside your GNOME session:

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
```

It stops at once on any machine that is not a Redrix, downloads a pinned release, checks its SHA-256 and opens a
checklist. Prefer to read first? Use a checkout:

```sh
git clone https://github.com/maximeallanic/redrix-linux
cd redrix-linux
./install.sh --list        # what is available on this machine
./install.sh --dry-run     # every command it would run, nothing changed
./install.sh               # the checklist
```

Then, at any time:

```sh
./verify.sh                    # every installed component, one line per check
./uninstall.sh camera          # undo one component (what depends on it is offered too)
```

Full details: [docs/installation.md](docs/installation.md).

## What you can install

Fourteen components. Low-risk ones that make sense for everyone are preselected; nothing else is.

| Component | What you get | Risk |
|---|---|---|
| [haptics](docs/components/haptics.md) | Touchpad (and MX Master 4) vibrations on window, workspace and lock events | low, preselected |
| [pen](docs/components/pen.md) | Pen stays on the built-in screen with a monitor plugged in, appears in Settings, dot under the tip | low, preselected |
| [top-row](docs/components/top-row.md) | The lock key locks instead of suspending; the fullscreen key works | low, preselected |
| [camera](docs/components/camera.md) | Calibrated colours and black level; 32 unusable raw camera entries hidden from apps | low, preselected |
| [microphone](docs/components/microphone.md) | A noise-suppressed internal microphone, set as default input | low, preselected |
| [battery-guard](docs/components/battery-guard.md) | For worn batteries that die at a few percent: warn at 20 %, power off at 6 % | low |
| [keychron](docs/components/keychron.md) | Lets launcher.keychron.com configure a Keychron keyboard from Chrome | low |
| [speakers](docs/components/speakers.md) | Speaker amplifier tuning files from Google's recovery image (~1.5 GB download) | medium |
| [suspend](docs/components/suspend.md) | Real S3 deep sleep on lid close (MrChromebox firmware only) | medium |
| [fingerprint](docs/components/fingerprint.md) | Builds the fingerprint sensor driver so you can enroll fingers; login unchanged | medium |
| [shutdown-splash](docs/components/shutdown-splash.md) | Fade to black, then the firmware logo when shutting down or restarting | medium |
| [lockscreen-fingerprint](docs/components/lockscreen-fingerprint.md) | Touch the sensor on the lock screen clock to unlock | medium |
| [fingerprint-login](docs/components/fingerprint-login.md) | Log in, unlock and approve `sudo` with a finger; the password keeps working | **high** |
| [boot-splash](docs/components/boot-splash.md) | The firmware logo stays on screen from power-on to the login screen | **high** |

Every component page has the same four parts: background, what changes, how to check it, how to roll it back.

## Before you start

- Linux already installed and booting, with GNOME on Wayland. Firmware: MrChromebox's UEFI firmware, or the stock
  firmware with a RW_LEGACY/Submarine payload. Only `suspend` requires MrChromebox.
- For sound, the setup of [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) first.
- The kit does not flash firmware, install a bootloader or partition your disk.
  [docs/firmware.md](docs/firmware.md) and [docs/boot-chain.md](docs/boot-chain.md) describe how the tested machine
  was set up, as background.

## Safety

The kit changes a laptop you depend on, so it is built to be predictable:

- **You see before it acts.** `--dry-run` prints every command, packages included. Medium-risk components show what
  they change and how to undo it, then ask. High-risk ones make you type their name; `--yes` alone never installs
  them.
- **It only runs where it makes sense.** The installer reads the board from `/sys/class/dmi/id` and stops on other
  hardware before downloading anything. Components that cannot work on your setup (for example `suspend` on the
  stock firmware) are listed with the reason and cannot be chosen.
- **Login.** `fingerprint-login` backs up `/etc/pam.d`, uses Debian's `pam-auth-update`, checks that password login
  is still there, and asks you to test `sudo` in a second terminal before closing the first. Keep a root shell or a
  live USB at hand the first time.
- **Boot.** `boot-splash` rebuilds the initramfs. The exact commands to go back to another Plymouth theme are on its
  page and on the confirmation screen.
- **Undo.** Each component puts back what it replaced and removes the exact files it installed. Packages installed
  with `apt` stay, and the uninstaller says which.
- **Third-party files.** Google's speaker files, libfprint and the firmware are fetched or built on your machine,
  pinned by commit or hash, never stored in this repository. See [NOTICE.md](NOTICE.md).
- **Checked code.** CI runs ShellCheck on every shell script and the test suite on Debian testing.

## FAQ

**Does it work on other Chromebooks or other Brya boards?**
Not tested. The installer stops unless the board is Redrix; `--force` overrides that, but most components target
this model's exact hardware (touchpad, pen digitiser, camera sensor, amplifiers, fingerprint MCU). If you try a
component on a related board, a [hardware report](https://github.com/maximeallanic/redrix-linux/issues/new?template=hardware_report.yml)
helps everyone.

**Fedora, Arch, KDE?**
Packages are installed automatically on Debian and Ubuntu only. Elsewhere the installer lists what is needed under
Debian names; `fingerprint-login` and `boot-splash` are Debian-specific. The kit expects GNOME on Wayland. None of
this has been tested outside Debian: see [other distributions](docs/installation.md#other-distributions).

**Does it fix audio?**
No. Sound comes from [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio). The kit adds
the speaker amplifiers' DSM files and a noise-suppressed microphone on top of it.

**Why does `speakers` download 1.5 GB?**
The DSM files are Google's and are not redistributed. The component downloads the official recovery image for
Redrix, checks it against Google's index, extracts four files and installs them only if they match hashes pinned in
the kit. It needs about 7 GB free in `/var/tmp` while it runs.

**Can it brick my laptop?**
It never touches firmware. The two high-risk components change login (PAM) and boot (initramfs); both are opt-in,
ask you to type their name, and document a manual rollback that works even if the kit itself is gone.

**What still does not work?**
Widevine L1 (streaming falls back to L3), Android apps and ChromeOS updates are gone once you leave ChromeOS. s2idle
never reaches S0ix, the camera keeps a cool cast in warm light, Mic2 is unusable, and a fractional scale around
150 % is not available. The full list is in [docs/hardware-support.md](docs/hardware-support.md).

**What about battery life?**
Not measured with this kit. Community reports give 5-7 h under Linux against about 11 h under ChromeOS.

## Contributing

One machine has been tested so far, so the most useful contribution is a report from yours: open a
[hardware report](https://github.com/maximeallanic/redrix-linux/issues/new?template=hardware_report.yml) with the
output of `./verify.sh --all`, whether things work or not. Bugs go in the
[bug report form](https://github.com/maximeallanic/redrix-linux/issues/new?template=bug_report.yml); code changes
follow [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: [SECURITY.md](SECURITY.md).

If the kit saved you an evening, a star helps other Dragonfly owners find it.

## Credits

This kit stands on the work of [MrChromebox](https://mrchromebox.tech) and [coreboot](https://coreboot.org) (UEFI
firmware), the [chrultrabook](https://docs.chrultrabook.com) community and its
[Redrix reference thread](https://forum.chrultrabook.com/t/the-ultimate-reference-guide-running-full-linux-on-hp-elite-dragonfly-chromebook-redrix-via-submarine/8149),
[WeirdTreeThing](https://github.com/WeirdTreeThing/chromebook-linux-audio) (audio),
[Submarine](https://github.com/FyraLabs/submarine) (Fyra Labs), Marco Trevisan's
[libfprint crfpmoc driver](https://gitlab.freedesktop.org/3v1n0/libfprint) and Samson's
[HP Pro c640 project](https://github.com/samson1357924/hp-pro-c640-chromebook-linux), [Solaar](https://github.com/pwr-Solaar/Solaar),
Chromium's haptic touchpad handler, [libwacom](https://github.com/linuxwacom/libwacom),
[libcamera](https://libcamera.org), PipeWire's WebRTC echo canceller and
[Adaptive Brightness](https://github.com/dmy3k/gnome-adaptive-brightness) by dmy3k.

## License

MIT, see [LICENSE](LICENSE). Third-party components keep their own licenses: [NOTICE.md](NOTICE.md).
