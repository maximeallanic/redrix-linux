# Keychron Launcher access (`keychron`)

Lets Keychron Launcher (`launcher.keychron.com`, in Chrome or Chromium) reach a Keychron keyboard to remap keys and
update its firmware.

## Risk level: low

One udev rule. Not specific to this laptop and not preselected: install it only if you own a Keychron keyboard.

## Background

Keychron keyboards are configured from a web page that uses WebHID and WebUSB. The browser runs as your user, and
on Debian raw HID nodes (`/dev/hidraw*`) belong to root, so the page sees the keyboard but cannot open it. The rule
tags Keychron devices `uaccess`, which gives the user of the active session read and write access.

## What the installer changes

`/etc/udev/rules.d/70-keychron.rules`:

| Match | Why |
|---|---|
| `SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434"` | Keychron keyboards and their Link 2.4 GHz dongles |
| `SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11"` | the STM32 DFU bootloader used for firmware updates |

udev rules are reloaded and HID and USB devices re-triggered.

Trade-off: any process of your session can read the keyboard's raw HID reports, typing included. Solaar's Logitech
rule makes the same compromise. The `0483:df11` match also covers any other device that enters that generic STM32
bootloader while you are logged in.

## Requirements

- A Keychron keyboard or dongle (USB vendor `3434`).
- A Chromium-based browser (WebHID and WebUSB).

## Verify

```sh
./verify.sh keychron
```

| Check | Meaning |
|---|---|
| `udev rule installed` | the rule is the kit's |
| `Keychron device reachable: /dev/hidrawN` | one line per Keychron HID node: your session can read and write it |

With no Keychron device connected, an INFO line says so.

## Uninstall

```sh
./uninstall.sh keychron
```

By hand:

```sh
sudo rm /etc/udev/rules.d/70-keychron.rules && sudo udevadm control --reload-rules
```

Unplug and replug the keyboard or its dongle afterwards.

## Known limitations

- Only tested with a Keychron K3 Max on a Keychron Link dongle.
