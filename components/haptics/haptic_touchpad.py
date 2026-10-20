"""Haptic touchpad (HID Haptics page 0x0E) driven from userspace through hidraw.

The touchpad keeps its own press/release feedback (device-controlled auto trigger); this module only
plays extra waveforms through the Manual Trigger output report, which leaves the click behaviour alone.
Everything device-specific is read from the report descriptor: report ID, bit layout of the trigger and
intensity fields, and the waveform list (one constant per ordinal). See docs/components/haptics.md.
"""
import os
from dataclasses import dataclass
from pathlib import Path

PAGE_HAPTICS = 0x0E
PAGE_ORDINAL = 0x0A
U_WAVEFORM_LIST = (PAGE_HAPTICS << 16) | 0x10
U_MANUAL_TRIGGER = (PAGE_HAPTICS << 16) | 0x21
U_INTENSITY = (PAGE_HAPTICS << 16) | 0x23
U_VENDOR_PAGE = (PAGE_HAPTICS << 16) | 0x26
U_VENDOR_ID = (PAGE_HAPTICS << 16) | 0x27

# Standard waveforms (HUTRR63b), same values as the kernel's hid-haptic.
STANDARD = {'PRESS': 0x1006, 'RELEASE': 0x1007}
# Google vendor waveforms (vendor 0x18D1, page 1), as ChromeOS plays them:
# chromium ui/events/ozone/evdev/libgestures_glue/haptic_touchpad_handler.cc
GOOGLE_VENDOR = (0x18D1, 0x01)
GOOGLE = {
    'DEEP_PRESS': 0x2001, 'DEEP_RELEASE': 0x2002, 'SNAP': 0x2003, 'SNAP_REVERSE': 0x2004,
    'KNOCK': 0x2005, 'TICK': 0x2006, 'TOGGLE_ON': 0x2007, 'TOGGLE_OFF': 0x2008,
}
WAVEFORMS = {**STANDARD, **GOOGLE}

_KINDS = {8: 'input', 9: 'output', 11: 'feature'}


@dataclass(frozen=True)
class Layout:
    report_id: int
    report_bytes: int
    trigger: tuple          # (bit offset, bit size) inside the report payload
    intensity: tuple        # (bit offset, bit size), or None if the device has no intensity field
    intensity_max: int
    waveforms: dict         # waveform usage -> ordinal
    vendor: tuple           # (vendor id, vendor waveform page), (0, 0) if not declared


@dataclass(frozen=True)
class _Field:
    kind: str
    report_id: int
    offset: int
    size: int
    usage: int
    lmin: int
    lmax: int
    collections: tuple


def _signed(value, size):
    bits = size * 8
    return value - (1 << bits) if size and value >> (bits - 1) else value


def _fields(rdesc):
    """Walk the descriptor items and yield one _Field per report field (usages resolved at the main item)."""
    state = {'page': 0, 'lmin': 0, 'lmax': 0, 'size': 0, 'count': 0, 'rid': 0}
    pushed, usages, collections, offsets = [], [], [], {}
    i = 0
    while i < len(rdesc):
        prefix = rdesc[i]
        if prefix == 0xFE:  # long item: skipped, never used for haptics
            i += 3 + (rdesc[i + 1] if i + 1 < len(rdesc) else 0)
            continue
        size = (0, 1, 2, 4)[prefix & 3]
        kind, tag = (prefix >> 2) & 3, prefix >> 4
        value = int.from_bytes(rdesc[i + 1:i + 1 + size], 'little')
        i += 1 + size
        if kind == 1:  # global
            if tag == 0:
                state['page'] = value
            elif tag == 1:
                state['lmin'] = _signed(value, size)
            elif tag == 2:
                state['lmax'] = _signed(value, size)
            elif tag == 7:
                state['size'] = value
            elif tag == 8:
                state['rid'] = value
            elif tag == 9:
                state['count'] = value
            elif tag == 10:
                pushed.append(dict(state))
            elif tag == 11 and pushed:
                state = pushed.pop()
        elif kind == 2 and tag == 0:  # local usage; 4-byte usages carry their own page
            usages.append(value if size == 4 else (state['page'] << 16) | value)
        elif kind == 0:  # main
            if tag == 10:
                collections.append(usages[0] if usages else 0)
            elif tag == 12 and collections:
                collections.pop()
            elif tag in _KINDS:
                key = (_KINDS[tag], state['rid'])
                start = offsets.get(key, 0)
                for n in range(state['count']):
                    usage = usages[min(n, len(usages) - 1)] if usages else 0
                    yield _Field(key[0], key[1], start + n * state['size'], state['size'], usage,
                                 state['lmin'], state['lmax'], tuple(collections))
                offsets[key] = start + state['count'] * state['size']
            usages = []


def parse(rdesc):
    """Layout of the haptic Manual Trigger, or None if the descriptor declares no usable one."""
    fields = list(_fields(rdesc))
    trigger = next((f for f in fields if f.kind == 'output' and f.usage == U_MANUAL_TRIGGER), None)
    if trigger is None:
        return None
    intensity = next((f for f in fields if f.kind == 'output' and f.report_id == trigger.report_id
                      and f.usage == U_INTENSITY), None)
    waveforms = {f.lmin: f.usage & 0xFFFF for f in fields
                 if f.kind == 'feature' and f.usage >> 16 == PAGE_ORDINAL and f.lmin == f.lmax
                 and f.collections and f.collections[-1] == U_WAVEFORM_LIST}
    if not waveforms:
        return None
    constant = {f.usage: f.lmin for f in fields if f.kind == 'feature' and f.lmin == f.lmax}
    report_bits = max(f.offset + f.size for f in fields
                      if f.kind == 'output' and f.report_id == trigger.report_id)
    return Layout(
        report_id=trigger.report_id,
        report_bytes=(report_bits + 7) // 8,
        trigger=(trigger.offset, trigger.size),
        intensity=(intensity.offset, intensity.size) if intensity else None,
        intensity_max=intensity.lmax if intensity else 0,
        waveforms=waveforms,
        vendor=(constant.get(U_VENDOR_ID, 0), constant.get(U_VENDOR_PAGE, 0)),
    )


def level(layout, percent):
    """Force 0-100 -> device intensity; any non-zero force maps to at least 1 (0 means do not play)."""
    if percent <= 0:
        return 0
    if not layout.intensity:
        return 1  # no intensity field: encode() ignores the value, the waveform plays at its fixed strength
    return max(1, round(percent * layout.intensity_max / 100))


def encode(layout, ordinal, intensity):
    payload = ordinal << layout.trigger[0]
    if layout.intensity:
        payload |= intensity << layout.intensity[0]
    return bytes([layout.report_id]) + payload.to_bytes(layout.report_bytes, 'little')


class Touchpad:
    def __init__(self, path, layout):
        self.path = path
        self.layout = layout
        self._fd = None

    def _usage(self, name):
        usage = WAVEFORMS[name]
        if name in GOOGLE and self.layout.vendor != GOOGLE_VENDOR:
            return None
        return usage if usage in self.layout.waveforms else None

    def names(self):
        return {name for name in WAVEFORMS if self._usage(name) is not None}

    def play(self, name, percent):
        """Raises KeyError for a waveform the device lacks, OSError if the node is gone."""
        usage = self._usage(name)
        if usage is None:
            raise KeyError(name)
        intensity = level(self.layout, percent)
        if intensity == 0:
            return
        if self._fd is None:
            self._fd = os.open(self.path, os.O_WRONLY | os.O_CLOEXEC)
        os.write(self._fd, encode(self.layout, self.layout.waveforms[usage], intensity))

    def close(self):
        if self._fd is not None:
            os.close(self._fd)
            self._fd = None


def find_touchpad(root=Path('/sys/class/hidraw')):
    """First hidraw node whose descriptor exposes a haptic Manual Trigger, or None."""
    for node in sorted(Path(root).glob('hidraw*')):
        try:
            layout = parse((node / 'device' / 'report_descriptor').read_bytes())
        except OSError:
            continue
        if layout is not None:
            return Touchpad(f'/dev/{node.name}', layout)
    return None
