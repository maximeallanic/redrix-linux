# Fingerprint reader (`fingerprint`)

Builds the driver for the fingerprint sensor so you can enroll and verify fingers with fprintd. It does not change
how you log in: that is [fingerprint-login](fingerprint-login.md).

## Risk level: medium

It downloads two pinned third-party source trees, builds libfprint and installs it into `/usr/local`, next to
Debian's own libfprint, which is not replaced. PAM is not touched. You are asked to confirm.

## Background

The sensor is not a USB reader. It sits behind a fingerprint microcontroller (FPMCU) of the ChromeOS EC family:
`bloonchipper` with an FPC1025 sensor (160x160 image, at most 5 templates stored on the MCU), reached through
`/dev/cros_fp`. The template matching runs on the MCU.

Debian's libfprint (1.94.10 when tested) has no driver for it: `fprintd` reports "No devices available".

A driver called **crfpmoc** exists outside Debian:

- [Marco Trevisan's libfprint fork](https://gitlab.freedesktop.org/3v1n0/libfprint), branch `feature/crfpmoc`. On its
  own it recognises the sensor, but opening fails with `FP_INFO ... INVALID_VERSION`: that revision only sends
  version 1 of the `FP_INFO` command, which this MCU firmware refuses.
- The [HP Pro c640 Chromebook Linux project](https://github.com/samson1357924/hp-pro-c640-chromebook-linux) carries
  newer driver files (`fingerprint/driver/`) that try `FP_INFO` version 3, then 2, then 1. With them grafted onto
  the same branch, the sensor works.

That project's own installer is not used: it changes PAM by default, and its `.deb` declares an unversioned
`Provides/Conflicts: libfprint-2-2`, which can make apt remove fprintd. The kit only takes its driver files.

What the driver does, from reading its source: it only sends the EC commands `FP_INFO`, `FP_MODE`, `FP_SEED`,
`FP_CONTEXT`, `FP_TEMPLATE`, `FP_FRAME`, `FP_STATS` and `FP_ENC_STATUS`, all of which act on the MCU's RAM. It does
not flash the MCU, reboot it or use the network. Its only disk write is a seed file,
`/var/lib/fprint/crfpmoc.key` (mode 0600). This is third-party code: read it before relying on it.

### Pinned sources

| Source | Commit | Licence |
|---|---|---|
| `https://gitlab.freedesktop.org/3v1n0/libfprint.git` (branch `feature/crfpmoc`) | `56442591a5c302a906289f30988fb50fc3d82ed6` | LGPL-2.1-or-later (libfprint) |
| `https://github.com/samson1357924/hp-pro-c640-chromebook-linux.git`, `fingerprint/driver/` only | `b58b5ac1c6c0526fe49c362da78512009324c1cd` | LGPL-2.1-or-later for `fingerprint/driver/` (per that repository's `REUSE.toml`); the rest of that project is mixed, MIT by default |

The kit fetches exactly these commits and checks them; it does not ship any of their code.

### Build steps (`components/fingerprint/build-libfprint.sh`)

1. Clone both repositories into `/usr/local/src/redrix-linux-fingerprint/` and check out the pinned commits (clean
   checkout every time).
2. Copy `c640/fingerprint/driver/crfpmoc*` over the branch's driver and add `crfpmoc-proto.c` to `meson.build`.
3. Fix a test-suite construct that newer meson rejects (`foreach driver_test, _args : drivers_tests`).
4. `meson setup` with prefix `/usr/local`, `-Ddrivers=crfpmoc,elanspi` (with `crfpmoc` alone the branch never
   defines `HAVE_UDEV`), no introspection, no docs, no examples, no installed tests, udev rules under
   `/usr/local/lib/udev/rules.d` and no hwdb.
5. `ninja` build and install, keep meson's install log as the list of installed files, `ldconfig`.

## What the installer changes

| Path | Content |
|---|---|
| `/usr/local/src/redrix-linux-fingerprint/` | the two source trees, the build directory, `installed-files.txt` |
| `/usr/local/lib/x86_64-linux-gnu/libfprint-2.so*` and the other files in `installed-files.txt` | the built libfprint |
| `/etc/systemd/system/fprintd.service.d/redrix-crfpmoc.conf` | `Environment=LD_LIBRARY_PATH=/usr/local/lib/x86_64-linux-gnu`: fprintd loads that libfprint |

Debian's `libfprint-2-2` package stays installed and untouched; only fprintd's service loads the `/usr/local` copy.

Debian packages: `fprintd`, `git`, `meson`, `ninja-build`, `pkg-config`, `gcc`, `libglib2.0-dev`, `libgusb-dev`,
`libgudev-1.0-dev`, `libnss3-dev`, `libpixman-1-dev`, `libudev-dev`, `libcairo2-dev`, `libssl-dev`. They are installed
with `--no-install-recommends`, so `libpam-fprintd` does not arrive with fprintd.

## After installing: enroll and test

Do this before even thinking about logging in with a finger:

```sh
fprintd-enroll -f right-index-finger      # touch the sensor until it says enroll-completed (about 5 touches)
fprintd-verify                            # the enrolled finger must match
fprintd-verify                            # try other fingers: each must be rejected (verify-no-match)
```

The sensor does not report the finger leaving between enroll touches: lift it fully each time. On the machine
tested, the enrolled finger was accepted every time, and the thumb, the other index finger and both middle fingers
were rejected.

## Requirements

- `/dev/cros_fp` present (the component is hidden otherwise).
- x86-64 Debian or Ubuntu (the library directory is `lib/x86_64-linux-gnu`).
- Network access to `gitlab.freedesktop.org` and `github.com` during the install.

## Verify

```sh
./verify.sh fingerprint
```

| Check | Meaning |
|---|---|
| `fingerprint MCU present (/dev/cros_fp)` | the kernel exposes the FPMCU |
| `libfprint with crfpmoc installed in /usr/local` | the built library exists |
| `fprintd uses that libfprint` | the service drop-in is the kit's |
| `fprintd sees the sensor` | `fprintd-list` reports one device |
| `N finger(s) enrolled for <you>` | INFO when none is enrolled yet |
| `fprintd runs with the crfpmoc libfprint` | read from fprintd's memory map; needs root, otherwise an INFO line gives the command |

## Uninstall

```sh
./uninstall.sh fingerprint
```

Removes the drop-in, every file listed in `installed-files.txt` (only paths under `/usr/local`), and the source
directory, then restarts fprintd. Enrolled fingers stay in `/var/lib/fprint`; delete them first with
`fprintd-delete "$USER"` if you want. [fingerprint-login](fingerprint-login.md) depends on this component: uninstall
it first (the uninstaller offers to).

By hand:

```sh
sudo rm /etc/systemd/system/fprintd.service.d/redrix-crfpmoc.conf && sudo systemctl daemon-reload
sudo xargs -a /usr/local/src/redrix-linux-fingerprint/installed-files.txt rm -f && sudo ldconfig
sudo rm -r /usr/local/src/redrix-linux-fingerprint
```

## Known limitations

- Out-of-tree code, pinned to one revision. Nothing guarantees that a future Debian fprintd keeps working with it:
  run `./verify.sh fingerprint` after fprintd updates.
- Whether the MCU keeps its seed and templates across S3 suspend has not been specifically tested. The c640 project
  ships a hook that stops fprintd before suspend; the kit does not install it. If verification fails after a
  resume, `sudo systemctl restart fprintd` and please open an issue.
- Five templates at most, a limit of the MCU.
