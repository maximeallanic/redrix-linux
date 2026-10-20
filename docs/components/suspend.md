# Working suspend (`suspend`)

Closing the lid really suspends: S3 ("deep") sleep, which lasts, instead of s2idle, which keeps drawing power on this
board. The touchpad no longer wakes the machine a second after it suspends.

## Risk level: medium

Two small configuration files, no kernel option. A suspend that does not work properly costs battery or a session,
so you are asked to confirm. Not preselected.

## Background

**Stock ChromeOS firmware.** With the stock firmware (and a ChromeOS-style boot such as Submarine), suspend on Linux
crashed the machine: the EC reported `reset: ap hang detected`. A forum report also tied KDE Plasma to broken suspend
on that setup. This component is only offered on MrChromebox's UEFI firmware; see [firmware](../firmware.md).

**MrChromebox UEFI firmware.** After the flash, `/sys/power/mem_sleep` offers `[s2idle] deep`:

- **s2idle** suspends without crashing, but `slp_s0_residency_usec` stays at 0: the package never reaches S0ix, so
  the battery drains almost as if the machine were idle. (An earlier test on the stock firmware did reach S0ix, 83 %
  residency over 4 seconds; with the UEFI firmware it does not.)
- **deep (S3)** works: 60 seconds of real sleep, resume in 0.43 s, lid close and open fine, Wi-Fi reassociated within
  4 seconds. In daily use over two days, five suspends resumed correctly.

**The touchpad wakes the machine.** With S3, the machine woke immediately after every suspend. The wake source is
the ELAN2703 haptic touchpad's interrupt (`\_SB.PCI0.I2C5.H015`, GPE `0x4E`): its counter rises on a real S3 entry
but not with `pm_test=core`, which suggests the touchpad loses power when entering S3 and fires its interrupt on the
way down. It cannot wake the machine usefully from S3 anyway. Disabling it as a wake source fixes the immediate
wake; the lid, the keyboard and the power button still wake the machine.

## What the installer changes

| Path | Content |
|---|---|
| `/etc/systemd/sleep.conf.d/90-redrix-deep.conf` | `[Sleep] MemorySleepMode=deep` |
| `/etc/udev/rules.d/90-redrix-touchpad-no-wakeup.rules` | `ATTR{power/wakeup}="disabled"` on `i2c-ELAN2703:00` |
| `/sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup` | set to `disabled` now, so no reboot is needed |

systemd reads `sleep.conf.d` at each suspend: nothing needs restarting.

## Requirements

- **MrChromebox UEFI Full ROM firmware.** On the stock firmware the component is hidden: suspend crashes there.
  Tested with MrChromebox 2609.1.
- The kernel must offer `deep` in `/sys/power/mem_sleep`.

## Verify

```sh
./verify.sh suspend
```

| Check | Meaning |
|---|---|
| `deep sleep configured` | the `sleep.conf.d` file is the kit's |
| `touchpad wake-up rule installed` | the udev rule is the kit's |
| `the kernel offers S3 (deep)` | `deep` is listed in `/sys/power/mem_sleep` |
| `the touchpad cannot wake the machine` | `power/wakeup` of the touchpad reads `disabled` |
| `last suspend of this boot used S3` | the kernel log's last `PM: suspend entry` line says `(deep)`. Before the first suspend of a boot, an INFO line says so instead |

To check the battery side yourself after a night:

```sh
journalctl -k -b | grep -E 'PM: suspend (entry|exit)'
```

## Uninstall

```sh
./uninstall.sh suspend
```

By hand:

```sh
sudo rm /etc/systemd/sleep.conf.d/90-redrix-deep.conf /etc/udev/rules.d/90-redrix-touchpad-no-wakeup.rules
echo enabled | sudo tee /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup
```

## Known limitations

- The touchpad cannot wake the machine. Open the lid, press a key or the power button.
- An ACPI error is logged at each S3 entry: `\_SB.PCI0.RP06.RTD3._STA` not found in `_PTS`. It is a firmware table
  bug with no visible effect.
- Resume with a USB-C dock attached is slower (USB resets, DisplayPort link training).
- With an external monitor connected, closing the lid does not suspend: that is systemd-logind's default
  (`HandleLidSwitchDocked=ignore`), not something this component changes.
- Long-term battery drain in S3 has not been measured precisely on this board.
