# Camera colours (`camera`)

Calibrated black level and colours for the internal camera, and 32 unusable raw camera entries hidden from
applications. A USB webcam, when plugged in, becomes the default camera.

## Risk level: low

One libcamera tuning file and one WirePlumber policy file. Installing restarts WirePlumber once if its policy
changed: audio and video streams reconnect, for about a second. Preselected in the checklist.

## Background

The internal camera is a Hynix hi556 (5 MP, Bayer GRBG, 10 bits, ACPI `INT3537`) behind Intel's IPU6. On Debian
testing it works through libcamera 0.7.2: the `simple` pipeline with the software ISP (debayering on the GPU),
1280x720 at 30 frames per second (maximum 2584x1944).

Without a tuning file for the sensor, libcamera falls back to `uncalibrated.yaml` and logs
`Failed to create camera sensor helper for hi556`. The picture is washed out and slightly green: the black level is
estimated from the histogram and leaves the blacks raised, and there is no colour matrix.

The kit's `hi556.yaml` was measured on this camera:

- **Black level.** 40 raw frames with the privacy shutter closed read 64.0 to 64.2 on all four Bayer channels, at 10
  bits. That is `blackLevel: 4096` on the 16-bit scale libcamera expects. This was the main cause of the washed-out
  look.
- **Colour matrix.** A ColorChecker 24-patch chart (X-Rite sRGB values) displayed on a phone screen, captured raw. For
  each patch only the darkest 40 % of pixels are kept (reflections only add light), white balance is taken from the
  four neutral patches, and the matrix is fitted by least squares with rows summing to 1 so neutrals stay neutral.
  Mean error on the fitted patches went from dE 18.8 to 6.8; two separate captures gave the same matrix within 0.05.

The IPU6 input system also exposes 32 raw V4L2 capture nodes that only produce Bayer data. PipeWire lists them all
as cameras. The WirePlumber policy disables those nodes and gives USB webcams a higher priority (1000) than the
internal camera (700 through libcamera), so a plugged-in webcam is picked first.

## What the installer changes

| Path | Content |
|---|---|
| `/etc/libcamera/ipa/simple/hi556.yaml` | tuning file: black level, auto white balance, one colour matrix (6500 K), adjust, auto exposure. Looked up before `/usr/share/libcamera/ipa` |
| `~/.config/wireplumber/wireplumber.conf.d/50-cameras.conf` | disables the V4L2 nodes of device `ipu6`; USB V4L2 nodes get `priority.session = 1000` |

WirePlumber is restarted only when the policy file changed. Applications use the new tuning the next time they open
the camera.

Debian packages: `libcamera-ipa`, `gstreamer1.0-libcamera`, `libspa-0.2-libcamera`, `gstreamer1.0-tools`,
`wireplumber`.

## Requirements

- The hi556 driver loaded (`/sys/bus/i2c/drivers/hi556`); the component is hidden otherwise.
- libcamera with the `simple` pipeline and software ISP (tested with 0.7.2).

## Verify

```sh
./verify.sh camera
```

| Check | Meaning |
|---|---|
| `hi556 tuning installed` | `/etc/libcamera/ipa/simple/hi556.yaml` is the kit's |
| `WirePlumber camera policy installed` | `50-cameras.conf` is the kit's |
| `libcamera loads the hi556 tuning (3 frames captured)` | a 3-frame GStreamer capture from the internal camera logged `Using tuning file /etc/libcamera/ipa/simple/hi556.yaml`. Fails if another application holds the camera |
| `raw IPU6 nodes hidden` | `wpctl status` lists no `ipu6` video node |
| `internal camera available to applications` | `wpctl status` lists the hi556 |

Output on a tested machine:

```
Camera colours (camera)
  [ OK ] hi556 tuning installed
  [ OK ] WirePlumber camera policy installed
  [ OK ] libcamera loads the hi556 tuning (3 frames captured)
  [ OK ] raw IPU6 nodes hidden
  [ OK ] internal camera available to applications
  Camera colours: all 5 checks passed
```

The capture check briefly turns the camera on (its LED lights up).

## Uninstall

```sh
./uninstall.sh camera
```

By hand:

```sh
sudo rm /etc/libcamera/ipa/simple/hi556.yaml
rm ~/.config/wireplumber/wireplumber.conf.d/50-cameras.conf && systemctl --user restart wireplumber
```

## Calibrating your own unit

The scripts used for the measurements are in `tools/camera-calibration/` (Python 3 with NumPy). They read raw
SGRBG10 frames at 2592x1944, captured for instance with libcamera's `cam` tool and a raw stream
(`cam -c 1 -s role=raw,width=2592,height=1944` plus its capture options):

| Script | Use |
|---|---|
| `dark.py FRAMES...` | per-channel mean of raw frames taken with the shutter closed: the black level |
| `chart.py OUT.png` | draws the ColorChecker chart to display on a screen |
| `preview.py RAW OUT.png` | a half-resolution preview, to locate the centres of the corner patches |
| `fit.py JSON` | fits the colour matrix from frames and the four corner coordinates (top-left, top-right, bottom-left, bottom-right, in preview coordinates) |
| `raw.py` | helpers shared by the others (black level 64 is assumed there) |

Unit-to-unit variation of the hi556 has not been measured: the kit's values come from one machine.

## Known limitations

- **Cool (blue-green) cast in warm rooms.** The software ISP's white balance in libcamera 0.7.2 is a plain grey-world
  estimate with no tuning. On the test scene it chose R 1.96 / B 1.43 where the chart measured R 2.20 / B 1.23, and the
  colour matrix amplifies the difference. libcamera changed this after 0.7.2 (the simple pipeline's white balance
  moved to libipa's `AwbAlgorithm`, which a tuning file can configure); the tuning will be revisited with the next
  libcamera release in Debian.
- **No gain model.** libcamera has no `CameraSensorHelper` for the hi556, upstream included, so auto exposure works
  on raw gain codes. Fixing that means adding the helper to libcamera (C++), ideally upstream.
- **No lens shading correction** in the software ISP: corners are darker.
- **One colour matrix**, measured near 6500 K. Under very warm light (tungsten) colours drift.
- The kernel sensor driver is incomplete (no location or rotation properties): libcamera logs warnings about it,
  without visible effect.
