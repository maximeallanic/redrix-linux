"""Tests for haptic_touchpad: descriptor parsing against the real ELAN2703 dump, report encoding, discovery."""
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import haptic_touchpad as HT  # noqa: E402

ELAN = (HERE / 'elan2703.rdesc').read_bytes()


class Parsing(unittest.TestCase):
    def setUp(self):
        self.layout = HT.parse(ELAN)

    def test_manual_trigger_report(self):
        self.assertEqual(self.layout.report_id, 0x08)
        self.assertEqual(self.layout.report_bytes, 1)
        self.assertEqual(self.layout.trigger, (0, 4))
        self.assertEqual(self.layout.intensity, (4, 4))
        self.assertEqual(self.layout.intensity_max, 15)

    def test_waveform_list_ordinals(self):
        self.assertEqual(self.layout.waveforms[0x1006], 3)   # PRESS
        self.assertEqual(self.layout.waveforms[0x1007], 4)   # RELEASE
        self.assertEqual(self.layout.waveforms[0x2001], 5)   # Google DEEP_PRESS
        self.assertEqual(self.layout.waveforms[0x2008], 12)  # Google TOGGLE_OFF
        self.assertEqual(len(self.layout.waveforms), 10)

    def test_vendor(self):
        self.assertEqual(self.layout.vendor, (0x18D1, 0x01))

    def test_descriptor_without_haptics(self):
        # Generic mouse: usage page 1, usage 2, collection, end collection.
        self.assertIsNone(HT.parse(bytes([0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0xC0])))


class Encoding(unittest.TestCase):
    def setUp(self):
        self.layout = HT.parse(ELAN)

    def test_report_bytes(self):
        # Ordinal in the low nibble, intensity in the high nibble: matches the manual test on the device.
        self.assertEqual(HT.encode(self.layout, 9, 8), bytes([0x08, 0x89]))
        self.assertEqual(HT.encode(self.layout, 3, 15), bytes([0x08, 0xF3]))

    def test_level_scaling(self):
        self.assertEqual(HT.level(self.layout, 100), 15)
        self.assertEqual(HT.level(self.layout, 50), 8)
        self.assertEqual(HT.level(self.layout, 1), 1)     # any non-zero force stays perceptible
        self.assertEqual(HT.level(self.layout, 0), 0)

    def test_device_without_intensity_field_still_plays(self):
        bare = HT.Layout(**{**self.layout.__dict__, 'intensity': None, 'intensity_max': 0})
        self.assertEqual(HT.level(bare, 40), 1)
        self.assertEqual(HT.level(bare, 0), 0)
        self.assertEqual(HT.encode(bare, 9, 1), bytes([0x08, 0x09]))

    def test_supported_names(self):
        tp = HT.Touchpad('/dev/null', self.layout)
        self.assertEqual(tp.names(), set(HT.WAVEFORMS))

    def test_google_waveforms_require_google_vendor(self):
        other = HT.Layout(**{**self.layout.__dict__, 'vendor': (0x1234, 0x01)})
        tp = HT.Touchpad('/dev/null', other)
        self.assertEqual(tp.names(), {'PRESS', 'RELEASE'})


class Playing(unittest.TestCase):
    def test_play_writes_report_and_reuses_descriptor(self):
        fd, path = tempfile.mkstemp(prefix='hidraw-test-')
        os.close(fd)
        tp = HT.Touchpad(path, HT.parse(ELAN))
        tp.play('KNOCK', 50)
        tp.play('PRESS', 100)
        tp.close()
        self.assertEqual(Path(path).read_bytes(), bytes([0x08, 0x89, 0x08, 0xF3]))

    def test_zero_force_writes_nothing(self):
        fd, path = tempfile.mkstemp(prefix='hidraw-test-')
        os.close(fd)
        tp = HT.Touchpad(path, HT.parse(ELAN))
        tp.play('KNOCK', 0)
        tp.close()
        self.assertEqual(Path(path).read_bytes(), b'')

    def test_unsupported_waveform_raises(self):
        tp = HT.Touchpad('/dev/null', HT.Layout(**{**HT.parse(ELAN).__dict__, 'vendor': (0, 0)}))
        with self.assertRaises(KeyError):
            tp.play('SNAP', 50)


class Discovery(unittest.TestCase):
    def test_find_picks_the_haptic_node(self):
        root = Path(tempfile.mkdtemp(prefix='sysfs-test-'))
        for name, rdesc in (('hidraw0', bytes([0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0xC0])), ('hidraw3', ELAN)):
            (root / name / 'device').mkdir(parents=True)
            (root / name / 'device' / 'report_descriptor').write_bytes(rdesc)
        tp = HT.find_touchpad(root)
        self.assertEqual(tp.path, '/dev/hidraw3')

    def test_find_returns_none_without_haptic_device(self):
        self.assertIsNone(HT.find_touchpad(Path(tempfile.mkdtemp(prefix='sysfs-empty-'))))


if __name__ == '__main__':
    unittest.main()
