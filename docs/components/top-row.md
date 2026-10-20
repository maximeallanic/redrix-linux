# Lock and fullscreen keys (`top-row`)

The lock key at the right end of the top row locks the screen instead of suspending the machine, and the fullscreen
key toggles fullscreen.

## Risk level: low

One hwdb entry that only matches this board, and two GNOME shortcuts whose previous values are saved and put back
on uninstall. While installing, the built-in keyboard is re-bound once: it stops answering for about a second.
Preselected in the checklist.

## Background

The Redrix keyboard is a Chromebook "Vivaldi" keyboard. The kernel (`atkbd`) reads its top-row layout from the
firmware (`function_row_physmap`) and most keys already work on a stock Debian GNOME:

| Key | Sends | Out of the box |
|---|---|---|
| Back, Refresh | `XF86Back`, `XF86Reload` | yes |
| Fullscreen | `XF86FullScreen` | no: GNOME binds nothing to it |
| Overview | `XF86LaunchA` | yes |
| Screenshot | screenshot key | yes |
| Brightness down/up | brightness keys | yes |
| Keyboard backlight | `XF86KbdLightOnOff` | yes (GNOME settings daemon and UPower, `chromeos::kbd_backlight`) |
| Play/pause, microphone, mute, volume down/up | media keys | yes |
| Lock (last key) | scancode `0x5d` -> `KEY_SLEEP` | no: it suspends the machine |

**The lock key.** atkbd's default map turns scancode `0x5d` into `KEY_SLEEP`. The key carries a lock icon, and
suspend has its own paths (lid, power menu). A udev hwdb entry, matched on the DMI of this board only, maps it to
`KEY_SCREENLOCK` (keysym `XF86ScreenSaver`), which GNOME binds to "lock screen". Mutter keeps the key list it read when
it opened the keyboard and drops codes missing from it, so the keyboard is unbound and rebound once to make the
compositor reopen it.

**GNOME does not fire the binding: [mutter#3990](https://gitlab.gnome.org/GNOME/mutter/-/issues/3990)** (open since
March 2025). Mutter resolves keysym names case-insensitively. Since xkbcommon 1.6 gained a distinct
`XF86Screensaver` keysym, the default `XF86ScreenSaver` binding lands on that other keysym and never fires. sway, niri
and Hyprland fixed the same lookup on their side. The kit adds the keycode `0xa0` to the lock shortcut, next to the
default `<Super>l`. It stays harmless once Mutter is fixed.

**Fullscreen.** `XF86FullScreen` reaches GNOME but nothing is bound to it; the kit binds it to "toggle fullscreen".

## What the installer changes

| Path or setting | Content |
|---|---|
| `/etc/udev/hwdb.d/61-redrix-lock-key.hwdb` | `evdev:atkbd:dmi:...:svnGoogle:pnRedrix*` -> `KEYBOARD_KEY_5d=screenlock` |
| hwdb database | `systemd-hwdb update` |
| `/sys/bus/serio/drivers/atkbd/{unbind,bind}` | `serio0` re-bound once (the keyboard is silent for about a second) |
| `org.gnome.settings-daemon.plugins.media-keys screensaver` | `['<Super>l', '0xa0']` |
| `org.gnome.desktop.wm.keybindings toggle-fullscreen` | `['XF86FullScreen']` |

The previous values of both GNOME keys are kept the first time (in the kit's state directory under
`~/.local/share/redrix-linux/saved/top-row/`) and restored on uninstall.

## Requirements

- The built-in keyboard on `atkbd` `serio0` (the component is hidden otherwise).

## Verify

```sh
./verify.sh top-row
```

| Check | Meaning |
|---|---|
| `lock key mapping installed` | the hwdb file is the kit's |
| `udev applies KEYBOARD_KEY_5d=screenlock to the built-in keyboard` | udev matched the entry against this board's keyboard |
| `kernel keymap: scancode 0x5d -> KEY_SCREENLOCK` | read from the device; only possible as root, otherwise an INFO line says so and the udev check stands in |
| `lock shortcut also bound by keycode (mutter#3990)` | `0xa0` is in the lock shortcut |
| `fullscreen key bound` | `XF86FullScreen` is bound to toggle fullscreen |

Output on a tested machine, as a normal user:

```
  [ OK ] lock key mapping installed
  [ OK ] udev applies KEYBOARD_KEY_5d=screenlock to the built-in keyboard
  [INFO] kernel keymap not read (/dev/input/by-path/platform-i8042-serio-0-event-kbd is readable by root only); the udev check above covers the mapping
  [ OK ] lock shortcut also bound by keycode (mutter#3990)
  [ OK ] fullscreen key bound
  Lock and fullscreen keys: all 4 checks passed
```

## Uninstall

```sh
./uninstall.sh top-row
```

Removes the hwdb file, re-binds the keyboard and restores both GNOME shortcuts.

By hand:

```sh
sudo rm /etc/udev/hwdb.d/61-redrix-lock-key.hwdb && sudo systemd-hwdb update
# Re-bind the keyboard (or reboot). One command: the keyboard is gone between the two writes.
sudo sh -c 'echo serio0 > /sys/bus/serio/drivers/atkbd/unbind; echo serio0 > /sys/bus/serio/drivers/atkbd/bind'
gsettings reset org.gnome.settings-daemon.plugins.media-keys screensaver
gsettings reset org.gnome.desktop.wm.keybindings toggle-fullscreen
```

## Known limitations

- Without the hwdb entry the key suspends; with it, it only locks. If you want it to suspend, do not install this
  component.
- Locking with the key and unlocking with a fingerprint as soon as the clock shows is a separate component:
  [lockscreen-fingerprint](lockscreen-fingerprint.md).
- Not covered: a PIN on the lock screen (out of scope for this kit).
