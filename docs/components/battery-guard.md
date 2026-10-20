# Worn battery guard (`battery-guard`)

For an aged battery that dies suddenly at a few percent: GNOME warns at 20 %, and the machine powers off cleanly at
6 % instead of cutting out.

## Risk level: low

One UPower configuration drop-in. It only changes thresholds and the action at the critical level. Not preselected:
install it only if your battery shows the problem.

## Background

UPower decides when GNOME shows the low-battery warning and what happens at the critical level. Its defaults assume
the charge estimate is accurate down to the last few percent. An aged cell's estimate drops abruptly at the end: on
one test machine at about 80 % battery health, the laptop cut out at 2 % with no warning that mattered.

This drop-in raises the thresholds and powers off at 6 %. Power-off rather than suspend: a suspended session is lost
anyway if the battery dies, and hibernation needs a disk swap area that most installs lack.

## What the installer changes

`/etc/UPower/UPower.conf.d/50-worn-battery.conf`:

```ini
[UPower]
PercentageLow=20.0
PercentageCritical=10.0
PercentageAction=6.0
CriticalPowerAction=PowerOff
```

UPower reads its configuration at start only, so it is restarted when the file changes.

Debian package: `upower`.

## Requirements

- UPower with drop-in support (`/etc/UPower/UPower.conf.d/`), as in current Debian testing.

## Verify

```sh
./verify.sh battery-guard
```

| Check | Meaning |
|---|---|
| `UPower thresholds installed` | the drop-in is the kit's |
| `UPower is running` | `upower.service` is active |
| `UPower started after the thresholds were written` | the running UPower has read the file |

Check the battery's health yourself:

```sh
upower -i "$(upower -e | grep -m1 battery)" | grep -E 'capacity|energy-full'
```

## Uninstall

```sh
./uninstall.sh battery-guard
```

By hand:

```sh
sudo rm /etc/UPower/UPower.conf.d/50-worn-battery.conf && sudo systemctl restart upower
```

## Known limitations

- 6 % is a margin chosen for one worn battery. With a battery in worse condition the machine may still cut out
  first; raise `PercentageAction` (and the others, keeping Low > Critical > Action) in the file and restart UPower.
  A reinstall would put the kit's values back.
- The thresholds apply to the charge as the battery gauge estimates it: they cannot be more accurate than that
  estimate.
