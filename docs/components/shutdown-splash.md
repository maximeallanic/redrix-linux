# Shutdown logo (`shutdown-splash`)

Shutting down or restarting fades the desktop to black, then shows the firmware logo where it sits at power-on,
instead of a jump to a text console.

## Risk level: medium

It adds a Plymouth theme used only at shutdown, systemd drop-ins for Plymouth's shutdown units, and a GNOME Shell
extension. The boot theme and the initramfs are not touched, so it cannot affect booting. You are asked to confirm.

## Background

At shutdown, GNOME Shell is killed, then systemd starts `plymouth-poweroff.service` (or `-reboot`, `-halt`,
`-kexec`), which draws the default Plymouth theme. Between the two, the screen can show a text console, and the
shutdown theme is whatever the boot theme is.

plymouthd reads a fixed configuration file, `/etc/plymouth/plymouthd.conf`, so there is no setting for "a different
theme at shutdown". The kit gives the shutdown units their own view of that file: a drop-in bind-mounts a
shutdown-only configuration over it (`BindReadOnlyPaths=`), inside those units' mount namespace only. Everything
else, boot included, still sees the original file.

The pieces:

- **fade-to-black@maximeallanic.github.io**: when logind emits `PrepareForShutdown(true)`, before it stops GDM, the
  extension fades the screen to black in 300 ms.
- **The `redrix-shutdown` theme** (Plymouth script plugin): starts from black and fades the firmware logo in (about
  0.5 s) where edk2 draws it at power-on, centred horizontally at 38.2 % of the screen height, then a spinner below.
  The logo is converted at install time from the firmware's own BGRT image
  (`/sys/firmware/acpi/bgrt/image`) to `logo.png` by `bgrt_to_png.py`; the 30 spinner frames are copied from the
  `spinner` theme of `plymouth-themes`.

## What the installer changes

| Path | Content |
|---|---|
| `/usr/share/plymouth/themes/redrix-shutdown/redrix-shutdown.plymouth` | theme description |
| `/usr/share/plymouth/themes/redrix-shutdown/redrix-shutdown.script` | theme script |
| `/usr/share/plymouth/themes/redrix-shutdown/logo.png` | the firmware logo, from BGRT |
| `/usr/share/plymouth/themes/redrix-shutdown/throbber-0001.png` ... `throbber-0030.png` | spinner frames, from the `spinner` theme |
| `/etc/plymouth/plymouthd-redrix-shutdown.conf` | `[Daemon] Theme=redrix-shutdown` |
| `/etc/systemd/system/plymouth-{poweroff,reboot,halt,kexec}.service.d/redrix-shutdown-theme.conf` | `BindReadOnlyPaths=/etc/plymouth/plymouthd-redrix-shutdown.conf:/etc/plymouth/plymouthd.conf` |
| `~/.local/share/gnome-shell/extensions/fade-to-black@maximeallanic.github.io` | the extension, enabled |

`systemctl daemon-reload` is run after adding the drop-ins.

Debian packages: `plymouth`, `plymouth-themes`, `python3`.

## Requirements

- **A firmware that publishes a BGRT image**: MrChromebox's UEFI firmware does, the stock ChromeOS firmware does not.
  The component is hidden otherwise.
- **`splash` on the kernel command line.** Plymouth reads the running kernel's command line at shutdown too; without
  `splash` it shows text. See [boot-splash](boot-splash.md#requirements) for where to add it.
- GNOME Shell 50 or 51 for the extension.

The logo is captured once, at install time. If you flash a firmware with a different logo, reinstall this component.

## Verify

```sh
./verify.sh shutdown-splash
```

| Check | Meaning |
|---|---|
| `shutdown theme complete in /usr/share/plymouth/themes/redrix-shutdown` | all 33 theme files exist and are not empty |
| `theme script up to date` | the script is the kit's |
| `shutdown-only Plymouth configuration installed` | `/etc/plymouth/plymouthd-redrix-shutdown.conf` is the kit's |
| `plymouth-<unit>.service uses the shutdown theme` (x4) | `systemctl cat` shows the bind mount for poweroff, reboot, halt and kexec |
| `kernel command line has "splash"` | `/proc/cmdline` contains `splash` |
| `extension files up to date` / `extension running` | the extension matches the kit and is ACTIVE (log out and back in after installing) |

## Uninstall

```sh
./uninstall.sh shutdown-splash
```

By hand:

```sh
sudo rm -r /usr/share/plymouth/themes/redrix-shutdown /etc/plymouth/plymouthd-redrix-shutdown.conf
sudo rm /etc/systemd/system/plymouth-{poweroff,reboot,halt,kexec}.service.d/redrix-shutdown-theme.conf
sudo systemctl daemon-reload
gnome-extensions disable fade-to-black@maximeallanic.github.io
rm -r ~/.local/share/gnome-shell/extensions/fade-to-black@maximeallanic.github.io
```

Nothing here runs at boot, so no rescue procedure is needed.

## Known limitations

- A short black gap between the end of the Shell and Plymouth's shutdown screen remains; the fade makes it a black
  screen rather than text.
- If something on the system writes to the first virtual console during that gap (for example a `plymouth.debug`
  option on the kernel command line, which logs to tty1), that text shows. Remove such debug options.
- Shutting down from a text console or over SSH skips the fade (the extension only runs in the GNOME session); the
  Plymouth shutdown screen still shows.
