# Fingerprint from the lock clock (`lockscreen-fingerprint`)

On the lock screen, touch the sensor while the clock is showing and the session unlocks. No key press or click is
needed first.

## Risk level: medium

A GNOME Shell extension that changes the lock screen's unlock dialog. A bug in it could get in the way of unlocking;
the password path is kept as it is, and the extension can be removed from a text console. You are asked to confirm.

## Background

With fingerprint login enabled, stock GNOME Shell only arms the fingerprint reader once the password prompt is shown:
the lock screen's `UnlockDialog` creates its `AuthPrompt`, which starts the fprintd conversation, when the prompt page
appears, and destroys it again when the clock comes back. So you have to press a key or click, then touch the sensor.
This is [gnome-shell#3048](https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/3048).

`fingerprint-from-clock@maximeallanic.github.io` starts verification while the clock is showing and keeps the prompt
alive, hidden under the clock:

- a finger on the sensor unlocks directly;
- keyboard focus stays on the dialog, so the first key you type still raises the prompt and lands in the password
  field, as before;
- after a failed read or a timeout, GDM's own code restarts the fingerprint service, and the extension starts it
  again while the clock is visible;
- the prompt's "(or place finger on reader)" hint is redundant once the reader is armed from the clock, so it is
  silenced.

## What the installer changes

| Path | Content |
|---|---|
| `~/.local/share/gnome-shell/extensions/fingerprint-from-clock@maximeallanic.github.io` | the extension, enabled |

No root access, no system file.

## Requirements

- [fingerprint-login](fingerprint-login.md) installed (it is added automatically when you pick this component).
- GNOME Shell 50 or 51. The extension uses private parts of the Shell's lock screen (`UnlockDialog`, GDM's
  `authServices`), so a new GNOME release may need an update of the extension.

## Verify

```sh
./verify.sh lockscreen-fingerprint
```

| Check | Meaning |
|---|---|
| `extension files up to date` | the installed files match the kit |
| `extension running` | GNOME reports the extension ACTIVE. Right after installing, log out and back in once |

Then test it: lock the screen (Super+L), wait for the clock, touch the sensor.

## Uninstall

```sh
./uninstall.sh lockscreen-fingerprint
```

By hand:

```sh
gnome-extensions disable fingerprint-from-clock@maximeallanic.github.io
rm -r ~/.local/share/gnome-shell/extensions/fingerprint-from-clock@maximeallanic.github.io
```

If the lock screen misbehaves and you cannot unlock: switch to a text console (Ctrl+Alt+F3), log in with your
password, then:

```sh
rm -r ~/.local/share/gnome-shell/extensions/fingerprint-from-clock@maximeallanic.github.io
loginctl terminate-user "$USER"     # ends your graphical session: unsaved work is lost
```

## Known limitations

- The first key typed on the clock still goes to the password field, as stock GNOME does.
- A PIN for the lock screen is a separate topic, not part of this kit.
