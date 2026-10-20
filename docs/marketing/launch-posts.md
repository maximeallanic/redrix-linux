# Launch post drafts

Drafts only: nothing has been posted. Rewrite them in your own words before posting; several of these communities
remove posts that read as generated or as self-promotion, and you need to be there to answer questions.

## Before posting

- **Publish the release first.** `install.sh` has an empty `RELEASE_SHA256` until `scripts/release.sh` fills it, and
  the one-line install refuses to run without it. Every post below leads with that command.
- **Where this audience actually is (checked 2026-10-20).**
  - The chrultrabook forum (forum.chrultrabook.com) is where Redrix owners post; r/chrultrabook moved there and only
    keeps AMD Stoney Ridge questions.
  - r/chromeos has removed posts about putting another OS on a Chromebook since March 2024, and since February 2026
    also removes AI-generated posts and bot self-promotion. A post there is likely to be removed; read the current
    rules or ask the moderators first.
  - No active subreddit named r/linux_on_chromebook was found. The Reddit draft below fits r/linuxhardware, or any
    Linux-on-Chromebook subreddit you know is alive.
- **Lead with limits.** The Redrix reference thread on the forum drew pushback for unverified "100 %" ratings and
  missing logs. Say "one machine tested", link the full matrix, and invite reports.
- **One post per place, no cross-posting the same day, and do not ask anyone to upvote.**

## chrultrabook forum (Linux Support, or a reply in the Redrix reference thread)

**Title:** Redrix (HP Elite Dragonfly Chromebook): a reversible kit for haptics, pen, camera, mic, speakers, S3 and
fingerprint

> I have been running Debian testing + GNOME 51 on my Redrix with MrChromebox UEFI (2609.1) and packaged the fixes I
> needed into a kit: https://github.com/maximeallanic/redrix-linux
>
> It assumes Linux already boots and WeirdTreeThing's audio script is installed. On top of that:
>
> - **haptics**: touchpad vibrations on GNOME events (window, workspace, lock), not only on click
> - **pen**: stays on the built-in screen when a monitor is plugged in
> - **top-row**: lock key locks instead of suspending, fullscreen key works
> - **camera**: hi556 tuning measured on this unit (black level 64 raw, colour matrix from a chart); no more green tint
> - **microphone**: WebRTC noise suppression on Mic1 (Mic2 returns a saturated constant here)
> - **speakers**: the MAX98390 `dsm_param_*_Google_Redrix.bin` files, extracted from the official recovery image on
>   your machine and checked against pinned hashes
> - **suspend**: S3 deep instead of s2idle (which never reaches S0ix on UEFI), touchpad wake disabled
> - **fingerprint**: builds Marco Trevisan's crfpmoc libfprint driver; login by finger is a separate, high-risk opt-in
>
> Everything is one checklist with risk levels, `--dry-run`, `verify.sh` and per-component `uninstall.sh`. It never
> flashes firmware.
>
> Limits: one machine tested, Debian only (Ubuntu should work, nothing else tried), GNOME on Wayland. The full
> works / partial / broken matrix is in `docs/hardware-support.md`.
>
> If you have a Redrix, the output of `./verify.sh --all` (hardware report template on the repo) would tell me whether
> my unit is typical. Thanks to MrChromebox, WeirdTreeThing and everyone in the Redrix thread: most of this started
> from what was posted there.

## Reddit (r/linuxhardware, or a live Linux-on-Chromebook subreddit)

**Title:** Linux on the HP Elite Dragonfly Chromebook: I packaged the last-mile fixes (haptics, pen, camera colours,
mic noise suppression, S3, fingerprint)

> After moving my Dragonfly Chromebook (board "redrix") to Debian testing + GNOME, booting and audio were solved by
> MrChromebox and chromebook-linux-audio, but a dozen small things were not: the lock key suspended the laptop, the
> camera was green, the mic picked up the fan, s2idle drained the battery, and Debian's libfprint has no driver for
> the fingerprint sensor.
>
> The kit is a checklist installer. Low-risk items are preselected; medium-risk ones explain what they change before
> asking; PAM and boot changes make you type their name. `--dry-run` shows every command, and every component has a
> verify and an uninstall.
>
> Measured on my unit: camera colour error from dE 18.8 to 6.8 on a test chart; mic noise floor from -47.7 to
> -60.9 dBFS in a noisy room; S3 resumes in 0.43 s.
>
> Honest limits: one machine, Debian testing, GNOME 51. Widevine L1 is gone, s2idle never reaches S0ix, the camera is
> still cool in warm light.
>
> Repo (MIT): https://github.com/maximeallanic/redrix-linux. Hardware reports from other units are the most useful
> feedback.

## Mastodon / Fediverse (under 500 characters)

> Released redrix-linux: a reversible kit that finishes Linux on the HP Elite Dragonfly Chromebook. Haptic touchpad
> events, pen on the right screen, a lock key that locks, calibrated camera, noise-suppressed mic, speaker DSM files,
> S3 suspend, fingerprint. One checklist with risk levels and --dry-run; never flashes firmware. Tested on one
> machine, Debian testing + GNOME 51.
>
> https://github.com/maximeallanic/redrix-linux
>
> #Linux #Chromebook #Debian #GNOME #coreboot

## Hacker News

**Title (77 characters; HN allows 80):** Show HN: Redrix-linux – hardware kit for Linux on the HP Dragonfly Chromebook

**URL:** https://github.com/maximeallanic/redrix-linux

**First comment** (Show HN expects the author to explain how and why):

> [One or two sentences in your own words: why you run Linux on this machine.] MrChromebox's firmware and the community audio script get you a booting system; this repo is everything
> after that, written as small components that each document what they change, how to check it and how to undo it.
>
> A few parts were fun to work out: the touchpad is a standard HID haptic device whose waveforms nothing on the
> desktop uses, so a small session service plays them from GNOME Shell events; the speaker amplifier tuning files are
> Google's, so instead of shipping them the kit pulls the official recovery image, reads four files out of its root
> partition with debugfs and checks them against pinned hashes; the camera tuning came from 40 dark frames and a
> colour chart shown on a phone.
>
> It is tested on exactly one machine, so I would love to hear from other owners.

Alternative title (78 characters): "Show HN: Haptics, pen and fingerprint for Linux on the HP Dragonfly
Chromebook".
