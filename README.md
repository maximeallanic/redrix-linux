# redrix-linux

Hardware enablement for running Linux on the **HP Elite Dragonfly Chromebook** (board `redrix`, Intel Alder Lake,
"Brya" family): haptic touchpad, pen, top-row keys, camera colours, microphone noise suppression, speaker
protection, deep suspend, fingerprint login and a flicker-free boot logo, each one optional, checked and reversible.

[Français](README.fr.md)

> Tested on Debian testing (forky) with GNOME Shell 51, kernel 7.2 and MrChromebox UEFI firmware 2609.1.
> Ubuntu should work (same packaging tools) but has not been tested. Other distributions: see
> [installation](docs/installation.md#other-distributions).

## Install

From your normal user account, inside your GNOME session:

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
```

This downloads a pinned release, checks its SHA-256, refuses to run on any other machine, and opens a checklist.
Or from a checkout:

```sh
git clone https://github.com/maximeallanic/redrix-linux
cd redrix-linux
./install.sh --list        # what is available on this machine
./install.sh --dry-run     # every command it would run, nothing changed
./install.sh               # the checklist
```

The checklist preselects only low-risk components. Medium-risk components show what they change and how to undo it,
then ask. High-risk ones (login and boot) make you type their name. After installing, the installer runs the checks
and tells you what needs a new login or a reboot. Full details: [docs/installation.md](docs/installation.md).

Undo any component, or check it at any time:

```sh
./uninstall.sh camera          # one component (what depends on it is offered too)
./verify.sh                    # every installed component, one line per check
```

## Before you start

You need Linux already installed and booting: MrChromebox's UEFI firmware, or the stock firmware with a
RW_LEGACY/Submarine payload. Sound needs the audio setup of
[chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) first. The kit does not flash
firmware, install a bootloader or partition your disk; [docs/firmware.md](docs/firmware.md) and
[docs/boot-chain.md](docs/boot-chain.md) describe how this machine was set up, as background.

## Components

| Component | What you get | Risk | Preselected |
|---|---|---|---|
| [haptics](docs/components/haptics.md) | Touchpad (and MX Master 4) vibrations on window, workspace and lock events | low | yes |
| [pen](docs/components/pen.md) | Pen stays on the built-in screen with a monitor plugged in, appears in Settings, dot under the tip | low | yes |
| [top-row](docs/components/top-row.md) | The lock key locks instead of suspending; the fullscreen key works | low | yes |
| [camera](docs/components/camera.md) | Calibrated colours and black level; 32 unusable raw camera entries hidden from apps | low | yes |
| [microphone](docs/components/microphone.md) | A noise-suppressed internal microphone, set as default input | low | yes |
| [battery-guard](docs/components/battery-guard.md) | For worn batteries that die at a few percent: warn at 20 %, power off at 6 % | low | no |
| [keychron](docs/components/keychron.md) | Lets launcher.keychron.com configure a Keychron keyboard from Chrome | low | no |
| [speakers](docs/components/speakers.md) | Speaker amplifier tuning files extracted from Google's recovery image (~1.5 GB download) | medium | no |
| [suspend](docs/components/suspend.md) | Real S3 deep sleep on lid close (MrChromebox firmware only); touchpad no longer wakes it | medium | no |
| [fingerprint](docs/components/fingerprint.md) | Builds the fingerprint sensor driver so you can enroll fingers; login unchanged | medium | no |
| [shutdown-splash](docs/components/shutdown-splash.md) | Fade to black, then the firmware logo when shutting down or restarting | medium | no |
| [lockscreen-fingerprint](docs/components/lockscreen-fingerprint.md) | Touch the sensor on the lock screen clock to unlock | medium | no |
| [fingerprint-login](docs/components/fingerprint-login.md) | Log in, unlock and approve `sudo` with a finger; the password keeps working | **high** | no |
| [boot-splash](docs/components/boot-splash.md) | The firmware logo stays on screen from power-on to the login screen | **high** | no |

What works out of the box, what this kit fixes and what is still broken on this machine:
[docs/hardware-support.md](docs/hardware-support.md). When something goes wrong:
[docs/troubleshooting.md](docs/troubleshooting.md).

## Safety

- **Login.** `fingerprint-login` changes PAM. It backs up `/etc/pam.d`, uses Debian's `pam-auth-update`, checks that
  password login is still there, and asks you to test `sudo` in a second terminal before closing the first. Keep a
  root shell or a live USB at hand the first time.
- **Boot.** `boot-splash` rebuilds the initramfs. If the logo misbehaves, choose another theme with
  `plymouth-set-default-theme` and rebuild; the exact commands are in its page and in the confirmation screen.
- **Firmware.** Nothing here flashes firmware. `tools/firmware/build-firmware.sh` only builds an image; flashing is
  your decision, with your own backup, after reading [docs/firmware.md](docs/firmware.md).
- **Third-party files.** Google's speaker files, libfprint and the firmware are fetched or built on your machine,
  pinned by commit or SHA-256, never stored here. See [NOTICE.md](NOTICE.md).

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
