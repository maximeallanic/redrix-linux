"""haptic-bridge tests: normalization, configuration, mouse bridge and CLI."""
import io
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from bridge_fakes import HB, WITHOUT_WHISPER, FakeDevice

CONF = """
force = 50
[events]
snap = { wave = "SUBTLE_COLLISION", cooldown_ms = 150 }
overview = { wave = "WHISPER_COLLISION", cooldown_ms = 100 }
lock = { wave = "COMPLETED" }
"""


class Normalization(unittest.TestCase):
    def test_spaces_dashes_case(self):
        self.assertEqual(HB.normalize('subtle collision'), 'SUBTLE_COLLISION')
        self.assertEqual(HB.normalize('Sharp-State-Change'), 'SHARP_STATE_CHANGE')

    def test_waveform_table(self):
        self.assertEqual(len(HB.WAVEFORMS), 16)
        self.assertEqual(HB.WAVEFORMS['SUBTLE_COLLISION'], 0x04)
        self.assertEqual(HB.WAVEFORMS['WHISPER_COLLISION'], 0x1B)


class Configuration(unittest.TestCase):
    def test_events_and_default_cooldown(self):
        c = HB.Config.parse(CONF)
        self.assertEqual(c.force, 50)
        self.assertEqual(c.events['snap'], ('SUBTLE_COLLISION', 150))
        self.assertEqual(c.events['lock'], ('COMPLETED', 150))

    def test_unknown_waveform_disables_only_the_mouse_with_message(self):
        err = io.StringIO()
        with redirect_stderr(err):
            c = HB.Config.parse('[events]\nsnap = { wave = "TURBO", touchpad = "SNAP" }\nlock = { wave = "KNOCK" }\n')
        self.assertEqual(c.events['snap'], (None, 150))   # still known: the touchpad side survives
        self.assertEqual(c.touchpad['snap'], 'SNAP')
        self.assertIn('lock', c.events)
        self.assertIn('TURBO', err.getvalue())

    def test_touchpad_only_event_or_event_without_waveform(self):
        err = io.StringIO()
        with redirect_stderr(err):
            c = HB.Config.parse('[events]\nsnap = { touchpad = "SNAP", cooldown_ms = 80 }\nnothing = { cooldown_ms = 80 }\n')
        self.assertEqual(c.events['snap'], (None, 80))
        self.assertEqual(c.touchpad, {'snap': 'SNAP'})
        self.assertEqual(c.events['nothing'], (None, 80))
        self.assertEqual(err.getvalue(), '')               # documented shapes: nothing to warn about

    def test_force_bounded(self):
        self.assertEqual(HB.Config.parse('force = 250\n[events]\n').force, 100)
        self.assertEqual(HB.Config.parse('force = -3\n[events]\n').force, 0)
        self.assertEqual(HB.Config.parse('[events]\n').force, 50)

    def test_waveform_name_with_spaces_accepted(self):
        c = HB.Config.parse('[events]\nsnap = { wave = "subtle collision" }\n')
        self.assertEqual(c.events['snap'][0], 'SUBTLE_COLLISION')

    def test_event_as_plain_string(self):
        c = HB.Config.parse('[events]\nsnap = "KNOCK"\n')
        self.assertEqual(c.events['snap'], ('KNOCK', 150))

    def test_mistyped_values_replaced_with_message(self):
        err = io.StringIO()
        with redirect_stderr(err):
            c = HB.Config.parse('force = "high"\n[events]\nsnap = { wave = "KNOCK", cooldown_ms = "fast" }\n')
        self.assertEqual(c.force, 50)
        self.assertEqual(c.events['snap'], ('KNOCK', 150))
        self.assertIn('fast', err.getvalue())
        self.assertIn('high', err.getvalue())

    def test_missing_or_invalid_file_gives_an_empty_config(self):
        tmp = Path(tempfile.mkdtemp(prefix='haptic-test-'))
        err = io.StringIO()
        with redirect_stderr(err):
            c1 = HB.Config.load(tmp / 'absent.toml')
            (tmp / 'broken.toml').write_text('force = [\n')
            c2 = HB.Config.load(tmp / 'broken.toml')
        self.assertEqual((c1.force, c1.events), (50, {}))
        self.assertEqual((c2.force, c2.events), (50, {}))
        self.assertIn('absent.toml', err.getvalue())
        self.assertIn('broken.toml', err.getvalue())


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.clock = [0.0]
        self.dev = FakeDevice(mask=WITHOUT_WHISPER)
        self.bridge = HB.Bridge(HB.Config.parse(CONF), lambda: self.dev, clock=lambda: self.clock[0])

    def test_connect_reads_the_mask_and_writes_the_force(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertTrue(self.bridge.connect())
        self.assertIn('SUBTLE_COLLISION', self.bridge.supported)
        self.assertNotIn('WHISPER_COLLISION', self.bridge.supported)
        self.assertIn('overview', self.bridge.config.events)        # waveform not advertised: the mouse stays silent, the event stays
        self.assertIn('overview', err.getvalue())
        self.assertIn((0x19B0, 0x20, (b'\x01\x32',), False), self.dev.calls)

    def test_unadvertised_waveform_nothing_sent_to_the_mouse(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(self.bridge.play('overview'))
            self.bridge._last_search = float('-inf')
            self.bridge.connect()
        self.assertNotIn(0x40, [a[1] for a in self.dev.calls])
        self.assertEqual(err.getvalue().count('overview'), 1)    # once, not at every reconnection

    def test_mouse_plugged_later_that_has_the_waveform(self):
        """The event is not deleted by the first mouse: a mouse offering the waveform plays it."""
        small = FakeDevice(mask=WITHOUT_WHISPER)
        full = FakeDevice(mask=WITHOUT_WHISPER | 1 << 0x1B)   # bit = waveform id
        queue = [small, full]
        bridge = HB.Bridge(HB.Config.parse(CONF), lambda: queue.pop(0), clock=lambda: self.clock[0])
        with redirect_stderr(io.StringIO()):
            self.assertTrue(bridge.connect())
            self.assertFalse(bridge.play('overview'))
            small.receiver.kill()                              # the first mouse goes away
            self.clock[0] = 1.0
            self.assertTrue(bridge.play('overview'))
        self.assertEqual(full.calls[-1], (0x19B0, 0x40, (0x1B,), True))

    def test_zero_force_mutes(self):
        bridge = HB.Bridge(HB.Config.parse('force = 0\n[events]\n'), lambda: self.dev)
        bridge.connect()
        self.assertIn((0x19B0, 0x20, (b'\x00\x32',), False), self.dev.calls)

    def test_play_sends_the_frame_without_reply(self):
        self.assertTrue(self.bridge.play('snap'))
        self.assertEqual(self.dev.calls[-1], (0x19B0, 0x40, (0x04,), True))

    def test_cooldown_per_event(self):
        self.assertTrue(self.bridge.play('snap'))
        self.clock[0] = 0.1
        self.assertFalse(self.bridge.play('snap'))
        self.assertTrue(self.bridge.play('lock'))      # other event, not blocked
        self.clock[0] = 0.2
        self.assertTrue(self.bridge.play('snap'))

    def test_unknown_event_single_warning(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(self.bridge.play('teleportation'))
            self.assertFalse(self.bridge.play('teleportation'))
        self.assertEqual(err.getvalue().count('teleportation'), 1)

    def test_mouse_absent(self):
        bridge = HB.Bridge(HB.Config.parse(CONF), lambda: None)
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(bridge.play('snap'))
            self.assertFalse(bridge.play('snap'))
            self.assertFalse(bridge.present())
        self.assertEqual(err.getvalue().count('haptic mouse not found'), 1)

    def test_send_failure_reconnects_once(self):
        """The write raises (NoReceiver): re-enumeration, which returns a fresh object as Solaar does."""
        first = FakeDevice(mask=WITHOUT_WHISPER, failures=1)
        second = FakeDevice(mask=WITHOUT_WHISPER)
        queue = [first, second]
        bridge = HB.Bridge(HB.Config.parse(CONF), lambda: queue.pop(0), clock=lambda: self.clock[0])
        self.assertTrue(bridge.play('snap'))
        self.assertEqual([a[1] for a in first.calls].count(0x40), 1)    # the failure
        self.assertEqual([a[1] for a in second.calls].count(0x40), 1)   # the success, on the fresh object
        self.assertEqual(first.receiver.closed, 1)                      # the old receiver closed

    def test_double_failure_gives_up_without_exception(self):
        self.dev.failures = 2
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(self.bridge.play('snap'))
        self.assertIn('snap', err.getvalue())

    def test_caps_none_counts_as_mouse_absent(self):
        dev = FakeDevice(caps_none=True)
        bridge = HB.Bridge(HB.Config.parse(CONF), lambda: dev)
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(bridge.connect())
            self.assertFalse(bridge.play('snap'))
        self.assertIsNone(bridge.device)
        self.assertNotIn((0x19B0, 0x20), [a[:2] for a in dev.calls])

    def test_connect_without_writing_the_force(self):
        self.bridge.connect(set_force=False)
        self.assertNotIn(0x20, [a[1] for a in self.dev.calls])

    def test_receiver_gone_without_exception_detected_and_reconnected(self):
        """Solaar swallows NoReceiver on read and returns None: we check the descriptor ourselves."""
        dead = FakeDevice(mask=WITHOUT_WHISPER, dies_after_send=True)
        fresh = FakeDevice(mask=WITHOUT_WHISPER)
        devices = [dead, fresh]
        bridge = HB.Bridge(HB.Config.parse(CONF), lambda: devices.pop(0), clock=lambda: self.clock[0])
        self.assertTrue(bridge.play('snap'))
        self.assertIs(bridge.device, fresh)
        self.assertEqual([a[1] for a in fresh.calls].count(0x40), 1)
        self.assertEqual(dead.receiver.closed, 1)       # the old receiver is closed, no descriptor leak

    def test_no_reenumeration_before_the_delay(self):
        calls = []

        def finder():
            calls.append(self.clock[0])
            return None
        bridge = HB.Bridge(HB.Config.parse(CONF), finder, clock=lambda: self.clock[0])
        err = io.StringIO()
        with redirect_stderr(err):
            bridge.play('snap')
            self.clock[0] = 1.0
            bridge.play('snap')
            self.clock[0] = HB.RETRY_S + 1.0
            bridge.play('snap')
        self.assertEqual(calls, [0.0, HB.RETRY_S + 1.0])


class Cli(unittest.TestCase):
    """`haptic-bridge play <event> <device>` reports whether the bridge played: verify-peripheriques relies on it."""
    def setUp(self):
        self.calls = []
        self.real_call = HB.call

    def tearDown(self):
        HB.call = self.real_call

    def answer(self, played):
        from gi.repository import GLib

        def call(method, *args):
            self.calls.append((method, args))
            return GLib.Variant('(b)', (played,))
        HB.call = call

    def test_play_on_a_device_succeeds_when_the_bridge_played(self):
        self.answer(True)
        self.assertEqual(HB.main(['play', 'lock', 'mouse']), 0)
        self.assertEqual(self.calls, [('PlayOn', ('mouse', 'lock'))])

    def test_play_on_a_device_fails_when_nothing_vibrated(self):
        self.answer(False)
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(HB.main(['play', 'lock', 'touchpad']), 1)
        self.assertIn('not played on touchpad', err.getvalue())

    def test_play_on_declares_its_result_and_play_stays_fire_and_forget(self):
        import gi
        gi.require_version('Gio', '2.0')
        from gi.repository import Gio
        iface = Gio.DBusNodeInfo.new_for_xml(HB.NODE_XML).interfaces[0]
        self.assertEqual([(a.name, a.signature) for a in iface.lookup_method('PlayOn').out_args], [('played', 'b')])
        self.assertEqual(list(iface.lookup_method('Play').out_args), [])


if __name__ == '__main__':
    unittest.main()
