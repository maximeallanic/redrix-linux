# Security policy

## Reporting a vulnerability

Please report security issues **privately** through GitHub: *Security* tab, *Report a vulnerability*. Do not open a
public issue. Include the version (`./install.sh --version`), your distribution and what an attacker can do. You will
get an answer within a week.

## What the kit does that matters for security

This kit changes system configuration as root. These are the promises it makes, and a way around any of them is
exactly the kind of report we want:

- **Root only when needed, asked once.** The installer runs as your user and asks for `sudo` once, after you have
  chosen components and seen what each one changes. Components marked "no root" never call `sudo`.
- **Login and boot changes are never preselected.** `fingerprint-login` (PAM) and `boot-splash` (initramfs) are high
  risk: you must type the component name to confirm, and `--yes` alone never installs them (it also needs the
  component named and `--accept-risk`).
- **PAM is changed through Debian's own tool.** `fingerprint-login` backs up `/etc/pam.d` first, enables the profile
  with `pam-auth-update`, and if `pam_unix` (your password) is no longer in `common-auth` afterwards it disables the
  profile again, puts the `common-*` files back from the backup and stops. Your password keeps working everywhere.
- **Pinned, verified downloads.** Sources are cloned at a full commit hash; Google's speaker files are installed only if
  they match pinned SHA-256 values. The one-line installer only runs a release tarball that matches the SHA-256
  written in `install.sh`.
- **Exact removal.** Uninstall removes the paths a component lists, one by one; it never expands a pattern.
- **No firmware is ever flashed.** `tools/firmware/build-firmware.sh` builds an image and stops.

## Out of scope

Vulnerabilities in fprintd, libfprint, Solaar, Plymouth, PipeWire, GNOME Shell or the firmware: report them to those
projects. Tell us if a pinned version has a known issue so that we can move the pin.

## Supported versions

Only the latest release.
