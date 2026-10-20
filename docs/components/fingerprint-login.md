# Log in with a fingerprint (`fingerprint-login`)

Unlock the screen, log in at the login screen and approve administrator prompts with a finger. The password keeps
working everywhere.

## Risk level: high

This changes PAM, the system that decides who may log in. A broken PAM configuration can lock you out of the
graphical login, `sudo` and administrator prompts. The kit uses Debian's own mechanism (`pam-auth-update`), backs up
`/etc/pam.d` first, and checks that the password module is still there afterwards; it still needs care. The
installer asks you to type the component's name back; with `--yes` it also needs `--accept-risk`.

Before installing, keep a way back: make sure you know your password, and keep a second terminal open with
`sudo -s` while you test.

## Background

Debian's `libpam-fprintd` package ships a `pam-auth-update` profile named `fprintd`. It is `Default: no`, so
installing the package changes nothing. Enabling it adds `pam_fprintd` (one try, 10-second timeout) to
`/etc/pam.d/common-auth`, before `pam_unix`: if the finger is not recognised or nothing touches the sensor, PAM falls
back to the password.

Everything that includes `common-auth` is affected: the GDM login screen, the lock screen, polkit administrator
prompts, `su`, and `sudo`. If your `sudoers` has a `NOPASSWD` rule for you, `sudo` asks for nothing either way.

GDM also has its own switch: the login screen only offers the fingerprint when `enable-fingerprint-authentication`
is true in the greeter's dconf defaults and in your session settings.

## What the installer changes

1. **Refuses to start if no finger is enrolled for you** (`fprintd-list`): enroll and test with `fprintd-enroll` and
   `fprintd-verify` first (see [fingerprint](fingerprint.md)).
2. **Backup:** `/etc/pam.d` is copied to `/var/backups/redrix-linux/pam.d-<YYYYMMDD-HHMMSS>`.
3. `pam-auth-update --package --enable fprintd`.
4. **Safety check:** if `pam_unix.so` is no longer in `common-auth`, the fprintd profile is disabled again, the
   `common-*` files are put back from the backup and the install stops. If `pam_fprintd.so` was not added (local edits to `common-auth` can prevent it), the install stops.
5. `/etc/gdm3/greeter.dconf-defaults`: `enable-fingerprint-authentication=true`, then Debian's GDM generator
   (`/usr/share/gdm/generate-config`) recompiles the greeter's settings.
6. Your session: `org.gnome.login-screen enable-fingerprint-authentication` set to true (previous value kept for
   uninstall).

Debian package: `libpam-fprintd`.

Test immediately, in a **second** terminal, before closing the first one:

```sh
sudo -k; sudo true      # touch the sensor; or wait 10 s and type the password
```

Then lock the screen (Super+L) and unlock with a finger.

## Requirements

- The [fingerprint](fingerprint.md) component, with at least one finger enrolled and tested.
- Debian-style PAM (`pam-auth-update`, `/etc/pam.d/common-auth`) and GDM (`gdm3`). The component is hidden otherwise.

## Verify

```sh
./verify.sh fingerprint-login
```

| Check | Meaning |
|---|---|
| `fingerprint enabled in common-auth` | `pam_fprintd.so` is in `/etc/pam.d/common-auth` |
| `password fallback (pam_unix) present` | `pam_unix.so` is still there. If this fails, password login is broken: restore a backup now (below) |
| `login screen offers the fingerprint` | the greeter defaults have `enable-fingerprint-authentication=true` |
| `finger(s) enrolled for <you>` | fprintd has at least one finger for you |

## Uninstall

```sh
./uninstall.sh fingerprint-login
```

Runs `pam-auth-update --package --disable fprintd`, sets the greeter key back to false and restores your session
setting. `libpam-fprintd` stays installed (inactive). Backups of `/etc/pam.d` stay in `/var/backups/redrix-linux/`.

### Manual rollback

If the graphical login no longer works, switch to a text console with **Ctrl+Alt+F3**, log in with your user name and
**password** (the text login also goes through `common-auth`; the password still works there), then either:

```sh
sudo pam-auth-update --package --disable fprintd
```

or put the backup back as it was:

```sh
ls /var/backups/redrix-linux/                                   # pick the pam.d-<date> taken before the install
sudo cp -a /var/backups/redrix-linux/pam.d-<date>/. /etc/pam.d/
```

Return to the graphical session with Ctrl+Alt+F1 or Ctrl+Alt+F2. If no console login works at all, boot an older
kernel entry or a live USB, mount the root filesystem and copy the backup back into its `/etc/pam.d/`.

## Known limitations

- **Logging in at the GDM login screen with a finger does not unlock the GNOME keyring.** The keyring is encrypted
  with your password; GNOME asks for it later, the first time an application needs a stored secret. Unlocking the
  lock screen is not affected (the keyring is already open). Use the password at the login screen if that bothers
  you.
- On the stock lock screen you must press a key or click before the sensor is armed. To unlock with a finger as soon
  as the clock shows, add [lockscreen-fingerprint](lockscreen-fingerprint.md).
- One try per prompt (`max-tries=1`): after a failed read, the prompt falls back to the password.
- `sudo` and polkit wait up to 10 seconds for the finger before asking for the password.
