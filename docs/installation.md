# Installation

## Requirements

- An HP Elite Dragonfly Chromebook. The installer reads `/sys/class/dmi/id` and stops unless the vendor is `Google`
  and the product `Redrix`; `--force` overrides this, but most components make no sense on other hardware.
- Linux installed and booting, with GNOME on Wayland. Debian testing and Ubuntu are handled fully; see
  [other distributions](#other-distributions).
- Firmware: MrChromebox's UEFI firmware (full ROM), or the stock firmware with a RW_LEGACY / Submarine payload. Only
  `suspend` requires MrChromebox. See [firmware.md](firmware.md) and [boot-chain.md](boot-chain.md).
- For `speakers`: the audio setup of [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
  already done, and about 7 GB free in `/var/tmp` during the install.
- Run as your normal user from a terminal inside your GNOME session, not with `sudo`. The installer asks for your
  password once, after you have confirmed the plan.

## One-line install

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
```

What this does, in order:

1. Checks the board. On another machine it stops before downloading anything.
2. Downloads the release pinned in `install.sh` from GitHub Releases and checks it against the SHA-256 written next to
   it. A mismatch stops everything.
3. Unpacks it in `~/.local/share/redrix-linux/releases/<version>/`. It stays there: its `uninstall.sh` and `verify.sh`
   are the ones to use later.
4. Runs that release's `install.sh` with the arguments you passed. To pass arguments through the pipe:
   `curl -fsSL .../install.sh | bash -s -- --dry-run`.

You can read the script first: `curl -fsSL .../install.sh | less`. The whole file is read before anything runs, so a
download cut in the middle cannot execute half a script.

## From a checkout

```sh
git clone https://github.com/maximeallanic/redrix-linux
cd redrix-linux
./install.sh
```

## The checklist

`whiptail` is used when it is installed (it is on Debian and Ubuntu), a numbered list otherwise. Both read the
keyboard from the terminal, so they also work under `curl | bash`.

- **Low risk** components that make sense for everyone are preselected. Low-risk components for specific situations
  (`battery-guard`, `keychron`) are not.
- **Medium risk** components are never preselected. After the checklist, each shows what it changes and how to undo
  it, then asks yes or no.
- **High risk** components (`fingerprint-login`, `boot-splash`) are never preselected and make you type their name.
- Components that cannot work on this machine are listed with the reason (for example `suspend` on the stock firmware)
  and cannot be chosen.
- A component that needs another (`fingerprint-login` needs `fingerprint`) brings it in. If you then decline the one
  that needed it, the added prerequisite is dropped again.

Then the installer asks to install the missing packages with `apt` (`--no-install-recommends`, so for instance
`fprintd` does not pull in `libpam-fprintd`), installs each component in a safe order, and runs the checks. It stops
at the first component that fails and tells you what was already installed.

## Options

| Option | Effect |
|---|---|
| `--list` | Components, risk, and whether each is available or installed here |
| `--dry-run` | Prints every command, changes nothing (packages included) |
| `-y`, `--yes` | No questions. With no component named: the preselected ones. Medium and high-risk components must be named |
| `--accept-risk` | With `--yes`, allows the high-risk components you named |
| `--no-verify` | Skips the checks after installing |
| `--force` | Runs on hardware that is not a Redrix |
| `--remove ID...` | Same as `./uninstall.sh ID...` |

Examples:

```sh
./install.sh camera microphone                    # these two, with the usual questions
./install.sh --yes                                # the preselected low-risk set, unattended
./install.sh --yes suspend speakers               # medium risk: named, so allowed with --yes
./install.sh --yes --accept-risk fingerprint-login
```

## Checking

```sh
./verify.sh               # the components you installed
./verify.sh pen camera    # these, installed or not: shows the state before installing
./verify.sh --all
```

Each check prints `[ OK ]`, `[FAIL]` with a hint, `[INFO]` (for example a check that needs root to read) or `[SKIP]`.
The exit status is the number of components with a failure. Several checks only pass after a new login (GNOME Shell
extensions) or a reboot (speakers, suspend, boot logo); their hint says so. `haptics` plays one short vibration.

## Uninstalling

```sh
./uninstall.sh camera     # one component; components that depend on it are offered first
./uninstall.sh            # everything this user installed, after asking
./uninstall.sh --dry-run fingerprint
```

Each component puts back what it replaced (previous settings, previous Plymouth theme, PAM through
`pam-auth-update --disable`) and removes the exact files it installed. Packages installed with `apt` stay installed,
because other software may use them; the uninstaller says which. Your own edits to
`~/.config/haptic-bridge/events.toml` are kept.

The installer records what it installed in `~/.local/share/redrix-linux/installed/`, and the settings it replaced in
`~/.local/share/redrix-linux/saved/`. Every component page has a manual rollback section for the case where the kit
itself is gone.

## Other distributions

Package installation is automatic on Debian and Ubuntu only. Elsewhere the installer lists the needed packages under
their Debian names and asks whether you installed the equivalents. What is known to differ:

| Component | Fedora | Arch |
|---|---|---|
| fingerprint-login | Not supported: uses Debian's `pam-auth-update` and `/etc/gdm3`. Fedora uses `authselect enable-feature with-fingerprint`. | Not supported: edit PAM by hand (see the component page). |
| boot-splash | Not supported: needs `update-initramfs`; Fedora uses dracut (`dracut -f`). | Not supported: mkinitcpio. |
| fingerprint | Build dependencies have other names (`glib2-devel`, `libgusb-devel`, `libgudev-devel`, `nss-devel`, `pixman-devel`, `cairo-devel`, `openssl-devel`, `systemd-devel`). | `base-devel meson glib2 libgusb libgudev nss pixman cairo openssl`. |
| haptics | `solaar python3-gobject python3-tomlkit` | `solaar python-gobject python-tomlkit` |
| camera | `libcamera libcamera-ipa pipewire-plugin-libcamera gstreamer1-plugins-bad-free` (names vary by release) | `libcamera libcamera-ipa pipewire-libcamera gst-plugin-libcamera` |
| pen | `libwacom` (provides `libwacom-update-db`) | `libwacom` |

The other components only use systemd, udev, PipeWire, WirePlumber and Plymouth paths that are the same everywhere.
None of this has been tested outside Debian; reports are welcome (use the *Hardware report* issue form).
