# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org).

## 0.1.1

First published release: 0.1.0 was tagged but never released, because a test of the one-line installer assumed
that no release was pinned and failed on the release commit itself.

- One-line installer that downloads a pinned, checksummed release, checks the board, and opens a checklist with a
  risk level for every component. `--dry-run`, `--yes`, `--list`, per-component `uninstall.sh` and `verify.sh`.
- Components: haptic feedback (touchpad, MX Master 4), pen, lock and fullscreen keys, camera colours, microphone noise
  suppression, speaker protection files, deep suspend, worn battery guard, Keychron Launcher access, fingerprint
  reader, fingerprint login, fingerprint from the lock clock, seamless boot logo, shutdown logo.
- Documentation of the boot chain (MrChromebox UEFI, systemd-boot, Secure Boot) and of the firmware build.

## 0.1.0

Tagged, not released (see 0.1.1).
