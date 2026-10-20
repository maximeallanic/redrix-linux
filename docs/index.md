# Documentation

## Using the kit

- [Installation](installation.md): requirements, one-line install, checklist, options, uninstall, other distributions
- [Hardware support](hardware-support.md): what works out of the box, what the kit fixes, what is still broken
- [Troubleshooting](troubleshooting.md)

## Components

| Component | Risk | Page |
|---|---|---|
| Haptic feedback | low | [haptics](components/haptics.md) |
| Pen support | low | [pen](components/pen.md) |
| Lock and fullscreen keys | low | [top-row](components/top-row.md) |
| Camera colours | low | [camera](components/camera.md) |
| Microphone noise suppression | low | [microphone](components/microphone.md) |
| Worn battery guard | low | [battery-guard](components/battery-guard.md) |
| Keychron Launcher access | low | [keychron](components/keychron.md) |
| Speaker protection files | medium | [speakers](components/speakers.md) |
| Working suspend (S3) | medium | [suspend](components/suspend.md) |
| Fingerprint reader | medium | [fingerprint](components/fingerprint.md) |
| Shutdown logo | medium | [shutdown-splash](components/shutdown-splash.md) |
| Fingerprint from the lock clock | medium | [lockscreen-fingerprint](components/lockscreen-fingerprint.md) |
| Log in with a fingerprint | high | [fingerprint-login](components/fingerprint-login.md) |
| Seamless boot logo | high | [boot-splash](components/boot-splash.md) |

Every page has the same sections: background, what changes, how to check it, rollback.

## Background (not automated)

- [Firmware](firmware.md): MrChromebox UEFI, write protection, building a firmware image with `tools/firmware`
- [Boot chain](boot-chain.md): systemd-boot, Secure Boot, moving away from a Submarine install

## Development

- [CONTRIBUTING.md](../CONTRIBUTING.md): how a component is structured, checks, commit style
- `tools/camera-calibration/`: the scripts used to measure the camera tuning
