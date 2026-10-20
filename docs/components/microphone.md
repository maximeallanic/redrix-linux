# Microphone noise suppression (`microphone`)

Adds "Internal Microphone (noise suppressed)", a filtered version of the internal microphone that removes fan,
keyboard and room noise, and makes it the default input.

## Risk level: low

One PipeWire configuration file in your home directory, no root access. The original microphone stays available
and selectable. Preselected in the checklist.

## Background

Internal audio on this board (SOF, `sof-rt5682`, with MAX98390 speaker amplifiers) needs the Chromebook audio
configuration described under Requirements. Once it is in place, the digital microphone array appears as two
PipeWire sources split by the UCM profile: `HiFi__Mic1__source` (channels 0-1, facing the user) and
`HiFi__Mic2__source` (channels 2-3). On the machine tested, Mic2 returns a saturated constant, so only Mic1 is used.

PipeWire ships WebRTC audio processing as a module (`libpipewire-module-echo-cancel` with `aec/libspa-aec-webrtc`).
The kit loads it on Mic1 with PipeWire's defaults:

- noise suppression on (the plugin fixes its level at high);
- high-pass filter on;
- automatic gain control off: it pumps the level, and most call applications normalise it themselves.

Measured on the tested machine: background noise -57.2 dBFS raw versus -61.7 dBFS filtered in a quiet room, and
-47.7 versus -60.9 dBFS with more ambient noise.

## What the installer changes

| Path or setting | Content |
|---|---|
| `~/.config/pipewire/pipewire.conf.d/60-mic-noise-suppression.conf` | the echo-cancel module: mono, 48 kHz, capture from Mic1, source `mic_noise_suppression` |
| default audio input | `mic_noise_suppression`, set with `wpctl set-default` once the source exists |

The Mic1 node name carries the PCI path of the audio device, so it is read from `wpctl status` at install time and
written into the file, not assumed.

PipeWire reads its configuration at start. The installer does not restart it, because that would cut every stream,
calls included. The filtered source appears at your next login; then run `./install.sh microphone` again to make it
the default input, or pick "Internal Microphone (noise suppressed)" in Settings > Sound.

The capture stream is passive: the microphone is only opened while an application records from the filtered source.

Debian packages: `libspa-0.2-modules` (provides `libspa-aec-webrtc.so`), `pipewire-bin`, `wireplumber`.

## Requirements

**The Chromebook audio configuration.** On a stock Debian install the only output is "Dummy Output". The
community script [WeirdTreeThing/chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
installs the SOF firmware and topology and the Chromebook UCM configuration (from `chromebook-ucm-conf`) into
`/usr/share/alsa/ucm2/conf.d/`. After it, speakers, headphones, HDMI/DisplayPort outputs, the headset microphone and
the internal microphones appear. The kit does not install it; read the script before running it. The component is
hidden until a `HiFi__Mic1__source` node exists.

## Verify

```sh
./verify.sh microphone
```

| Check | Meaning |
|---|---|
| `configuration installed for <Mic1 node>` | the file exists and targets the Mic1 node present now |
| `WebRTC audio processing plugin present` | `libspa-aec-webrtc.so` is installed |
| `mic_noise_suppression is running` | PipeWire created the filtered source (needs a login after installing) |
| `mic_noise_suppression captures from Mic1` | the capture stream is linked to Mic1 and to nothing else |
| `default input: mic_noise_suppression` | the filtered source is the default input |

## Uninstall

```sh
./uninstall.sh microphone
```

Removes the file. The filtered source disappears when PipeWire restarts (next login) and the default input falls
back to the internal microphone by itself.

By hand, immediately:

```sh
rm ~/.config/pipewire/pipewire.conf.d/60-mic-noise-suppression.conf
systemctl --user restart pipewire pipewire-pulse wireplumber   # cuts audio for a second
```

Then choose "Internal Microphone 1" in Settings > Sound if it is not the default.

## Known limitations

- **No echo cancellation of the speakers.** Taking the echo reference from a real output puts the microphone on
  that output's clock. Mic1 is a split node that cannot follow another clock: when tried, the HDMI output and the
  microphone both froze (stuck hardware pointer). The reference sink the module needs is therefore never linked to
  a device. Use headphones in calls, or rely on the call application's own echo cancellation.
- Noise suppression strength is fixed by the plugin; there is no setting for it.
- Mic2 is not used.
- The internal microphone's raw level is low (speech around -55 dBFS before any gain on the machine tested), and no
  ALSA control adjusts the digital microphone gain. Raise the input volume in Settings > Sound if applications find
  it quiet.
