# GitHub metadata

Values to paste into the repository settings when it is created. Nothing here is applied automatically.

## Description (About box, 350 characters maximum)

```
Linux hardware kit for the HP Elite Dragonfly Chromebook (redrix, Brya): haptic touchpad events, pen, lock key, calibrated camera, noise-suppressed mic, speaker DSM files, S3 suspend, fingerprint login, firmware boot logo. One checklist with risk levels, dry-run, verify and per-component uninstall. Tested on Debian testing + GNOME.
```

The model name comes first because it is what owners type into a search box; the board codename and family follow
because that is how the chrultrabook and MrChromebox community names devices.

## Topics (12)

```
chromebook  chrultrabook  mrchromebox  redrix  hp-elite-dragonfly  brya
linux  debian  gnome  haptics  fingerprint  libcamera
```

| Topic | Why |
|---|---|
| `chromebook`, `chrultrabook`, `mrchromebox` | where people who run Linux on Chromebooks browse (`chrultrabook` and `mrchromebox` are the community's own names) |
| `redrix`, `hp-elite-dragonfly`, `brya` | exact-model searches: codename, marketing name, platform family |
| `linux`, `debian`, `gnome` | the tested stack; honest filter for people on other distributions or desktops |
| `haptics`, `fingerprint`, `libcamera` | the three features people search for on their own and rarely find for Chromebooks |

Considered and left out: `coreboot` (the kit does not touch firmware), `pipewire` (one component), `hardware-enablement`
(rarely searched).

## Website field

Leave empty, or point it at `docs/hardware-support.md` on GitHub: it is the page most visitors want after the README.

## Social preview

Upload `docs/marketing/social-preview.png` (1280 x 640) in Settings > General > Social preview. Its source is
`docs/marketing/social-preview.svg`, generated with the README hero by `tools/marketing/render-assets.py`.

## Name check

How people look for this: the chrultrabook forum titles threads "HP Elite Dragonfly Chromebook (Redrix)", MrChromebox's
supported-devices list and the machine's own DMI product name use the codename Redrix, and owners outside that community search for the marketing
name ("dragonfly chromebook linux"). No other GitHub repository named after the board was found on 2026-10-20.

| Candidate | For | Against |
|---|---|---|
| `redrix-linux` (current) | Short, unique, matches the codename the community, MrChromebox and the installer's board check all use; reads as "Linux for redrix" | Means nothing to someone who only knows the marketing name |
| `dragonfly-chromebook-linux` | Matches the words casual owners search for | Long; "Dragonfly" alone also means HP's non-Chromebook Elite Dragonfly laptops and DragonFly BSD |
| `hp-dragonfly-chromebook-linux` | Most explicit for web search | Long, awkward in commands and paths (`~/.local/share/redrix-linux`, issue links, the one-line install) |
| `redrix-enablement` | Says "hardware enablement" | Less obvious than `-linux`; same codename problem |

**Recommendation: keep `redrix-linux`.** GitHub search matches the description and topics as well as the name, and
web search indexes the README, so the marketing name already appears where it counts: in the description, the first
line of the README and the `hp-elite-dragonfly` topic. A rename would also have to touch the installer, release URLs,
data paths and docs. Revisit only if the kit grows to other Brya boards, in which case a family name
(`brya-linux`) would fit better than either.
