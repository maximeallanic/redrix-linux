"""Generate the README hero SVG and the social preview SVG from the hardware-support matrix data.

The data below mirrors docs/hardware-support.md and the component list: update both together.
Usage (from the repository root):
    python3 tools/marketing/render-assets.py docs/assets/support-at-a-glance.svg docs/marketing/social-preview.svg
    rsvg-convert -w 1280 -h 640 docs/marketing/social-preview.svg -o docs/marketing/social-preview.png
"""
import sys
from xml.sax.saxutils import escape

OUT_HERO, OUT_SOCIAL = sys.argv[1], sys.argv[2]

# (label, note) taken from docs/hardware-support.md, statuses unchanged.
COLUMNS = [
    ("Works out of the box", "#1e8e3e", "#e6f4ea", [
        ("CPU (i7-1265U)", ""), ("GPU (Iris Xe)", ""), ("Touchscreen", ""), ("Keyboard", ""),
        ("Keyboard backlight", ""), ("Haptic touchpad", "+ haptics: event vibrations"),
        ("External display (USB-C)", ""), ("Wi-Fi (AX211)", ""), ("Bluetooth", ""),
        ("Tablet mode", ""), ("Ambient light sensor", ""), ("Battery", "+ battery-guard if worn"),
    ]),
    ("Works with kit or setup step", "#1a73e8", "#e8f0fe", [
        ("Pen (USI)", "pen"), ("Lock + fullscreen keys", "top-row"),
        ("Speakers (4x MAX98390)", "audio setup* + speakers"), ("Headphone jack", "audio setup* only"),
        ("Fingerprint reader", "fingerprint"), ("S3 deep suspend", "suspend (MrChromebox)"),
    ]),
    ("Partial", "#b06000", "#fef7e0", [
        ("Internal display", "no ~150 % scaling"), ("Internal microphones", "Mic1 only; + microphone"),
        ("Camera (hi556)", "+ camera; cool in warm light"), ("USB-C storage", "not re-tested"),
        ("s2idle suspend", "never reaches S0ix"), ("TPM (Cr50)", "must be cleared first"),
    ]),
    ("Not working / untested", "#5f6368", "#f1f3f4", [
        ("Widevine L1 (DRM)", "not working"), ("ChromeOS features", "not working"),
        ("Screen rotation", "untested"), ("LTE modem", "untested"),
    ]),
]

FONT = "-apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"


def hero():
    col_w, gap, pad = 222, 12, 20
    width = pad * 2 + col_w * 4 + gap * 3
    row_h, head_h, top = 40, 44, 74
    def col_height(items):
        return sum(40 if note else 27 for _, note in items)
    body = max(col_height(items) for _, _, _, items in COLUMNS)
    height = top + head_h + body + 70
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
           f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="t d">',
           '<title id="t">HP Elite Dragonfly Chromebook (redrix) under Linux: hardware support at a glance</title>',
           '<desc id="d">12 items work out of the box, 6 work with this kit or a documented setup step, 6 are '
           'partial, 2 do not work and 2 are untested. Source: docs/hardware-support.md.</desc>',
           f'<rect width="{width}" height="{height}" rx="16" fill="#ffffff" stroke="#dadce0"/>',
           f'<text x="{pad}" y="38" font-family="{FONT}" font-size="20" font-weight="700" fill="#202124">'
           'HP Elite Dragonfly Chromebook (redrix) on Linux</text>',
           f'<text x="{pad}" y="60" font-family="{FONT}" font-size="13" fill="#5f6368">'
           'Hardware support at a glance. One machine tested: Debian testing, GNOME 51, kernel 7.2, '
           'MrChromebox UEFI 2609.1</text>']
    for i, (title, fg, bg, items) in enumerate(COLUMNS):
        x = pad + i * (col_w + gap)
        out.append(f'<rect x="{x}" y="{top}" width="{col_w}" height="{head_h + body + 8}" rx="12" fill="{bg}"/>')
        out.append(f'<text x="{x + 14}" y="{top + 28}" font-family="{FONT}" font-size="14" font-weight="700" '
                   f'fill="{fg}">{escape(title)} ({len(items)})</text>')
        y = top + head_h
        for label, note in items:
            out.append(f'<circle cx="{x + 19}" cy="{y + 11}" r="4" fill="{fg}"/>')
            out.append(f'<text x="{x + 31}" y="{y + 15}" font-family="{FONT}" font-size="13" '
                       f'fill="#202124">{escape(label)}</text>')
            if note:
                out.append(f'<text x="{x + 31}" y="{y + 31}" font-family="{FONT}" font-size="11" '
                           f'fill="#5f6368">{escape(note)}</text>')
            y += 40 if note else 27
    foot = top + head_h + body + 40
    out.append(f'<text x="{pad}" y="{foot}" font-family="{FONT}" font-size="12" fill="#5f6368">'
               'Grey lines: the kit component involved, or the limitation. * audio setup = chromebook-linux-audio '
               '(WeirdTreeThing), done first. Full matrix: docs/hardware-support.md</text>')
    out.append('</svg>')
    return "\n".join(out) + "\n"


COMPONENTS = [
    ("haptics", "low"), ("pen", "low"), ("top-row", "low"), ("camera", "low"), ("microphone", "low"),
    ("battery-guard", "low"), ("keychron", "low"), ("speakers", "medium"), ("suspend", "medium"),
    ("fingerprint", "medium"), ("shutdown-splash", "medium"), ("lockscreen-fingerprint", "medium"),
    ("fingerprint-login", "high"), ("boot-splash", "high"),
]
RISK = {"low": "#81c995", "medium": "#fdd663", "high": "#f28b82"}
SANS = "'Google Sans Flex', 'Adwaita Sans', 'Noto Sans', sans-serif"
MONO = "'Adwaita Mono', 'Noto Sans Mono', monospace"


def social():
    w, h = 1280, 640
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
           f'<rect width="{w}" height="{h}" fill="#131314"/>',
           f'<rect x="0" y="0" width="12" height="{h}" fill="#8ab4f8"/>',
           f'<text x="80" y="150" font-family="{SANS}" font-size="104" font-weight="700" fill="#e8eaed">'
           'redrix-linux</text>',
           f'<text x="82" y="222" font-family="{SANS}" font-size="42" fill="#c4c7c5">'
           'The last mile of Linux on the HP Elite Dragonfly Chromebook</text>',
           f'<text x="82" y="290" font-family="{SANS}" font-size="30" fill="#8ab4f8">'
           'Haptics · pen · camera · mic · speakers · S3 suspend · fingerprint</text>']
    # Component chips, wrapped.
    x, y, chip_h = 82, 350, 46
    char_w = 12.2
    for name, risk in COMPONENTS:
        cw = int(len(name) * char_w + 44)
        if x + cw > w - 80:
            x, y = 82, y + chip_h + 14
        out.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{chip_h}" rx="23" fill="#1e1f20" '
                   f'stroke="{RISK[risk]}" stroke-width="2"/>')
        out.append(f'<circle cx="{x + 20}" cy="{y + 23}" r="6" fill="{RISK[risk]}"/>')
        out.append(f'<text x="{x + 34}" y="{y + 30}" font-family="{MONO}" font-size="20" fill="#e8eaed">'
                   f'{escape(name)}</text>')
        x += cw + 12
    out.append(f'<text x="82" y="{h - 52}" font-family="{SANS}" font-size="26" fill="#9aa0a6">'
               'One checklist · risk levels · --dry-run · verify · uninstall</text>')
    lx = 900
    for label, risk in (("low", "low"), ("medium", "medium"), ("high", "high")):
        out.append(f'<circle cx="{lx}" cy="{h - 61}" r="8" fill="{RISK[risk]}"/>')
        out.append(f'<text x="{lx + 16}" y="{h - 52}" font-family="{SANS}" font-size="26" fill="#9aa0a6">'
                   f'{label}</text>')
        lx += 40 + len(label) * 15
    out.append('</svg>')
    return "\n".join(out) + "\n"


with open(OUT_HERO, "w", encoding="utf-8") as f:
    f.write(hero())
with open(OUT_SOCIAL, "w", encoding="utf-8") as f:
    f.write(social())
