"""haptic-bridge tests: touchpad configuration and routing between mouse and touchpad."""
import io
import unittest
from contextlib import redirect_stderr

from bridge_fakes import HB, WITHOUT_WHISPER, FakeDevice


class FakeTouchpad:
    """Same surface as haptic_touchpad.Touchpad: names(), play(name, percent), close()."""
    def __init__(self, names=('SNAP', 'KNOCK', 'TICK', 'PRESS'), fail=False):
        self._names = set(names)
        self.fail = fail
        self.played = []
        self.closed = 0

    def names(self):
        return set(self._names)

    def play(self, name, percent):
        if name not in self._names:
            raise KeyError(name)
        if self.fail:
            raise OSError('hidraw gone')
        self.played.append((name, percent))

    def close(self):
        self.closed += 1


CONF_TP = """
force = 50
touchpad_force = 70
[events]
snap = { wave = "SUBTLE_COLLISION", touchpad = "snap", cooldown_ms = 150 }
edge = { wave = "SHARP_COLLISION", touchpad = "knock" }
lock = { wave = "COMPLETED" }
toggle = { wave = "KNOCK", touchpad = "TOGGLE_ON" }
"""


class TouchpadConfig(unittest.TestCase):
    def test_touchpad_waveforms_normalized(self):
        c = HB.Config.parse(CONF_TP)
        self.assertEqual(c.touchpad, {'snap': 'SNAP', 'edge': 'KNOCK', 'toggle': 'TOGGLE_ON'})
        self.assertEqual(c.events['snap'], ('SUBTLE_COLLISION', 150))   # mouse side unchanged

    def test_touchpad_force_defaults_to_force_and_is_bounded(self):
        self.assertEqual(HB.Config.parse('force = 40\n[events]\n').touchpad_force, 40)
        self.assertEqual(HB.Config.parse('touchpad_force = 300\n[events]\n').touchpad_force, 100)
        self.assertEqual(HB.Config.parse(CONF_TP).touchpad_force, 70)

    def test_unknown_touchpad_waveform_dropped_with_message(self):
        err = io.StringIO()
        with redirect_stderr(err):
            c = HB.Config.parse('[events]\nsnap = { wave = "KNOCK", touchpad = "WOBBLE" }\n')
        self.assertIn('snap', c.events)
        self.assertNotIn('snap', c.touchpad)
        self.assertIn('WOBBLE', err.getvalue())


class TouchpadRouting(unittest.TestCase):
    def setUp(self):
        self.clock = [0.0]
        self.mouse = FakeDevice(mask=WITHOUT_WHISPER)
        self.tp = FakeTouchpad()
        self.found = []

        def touchpad_finder():
            self.found.append(self.clock[0])
            return self.tp
        self.bridge = HB.Bridge(HB.Config.parse(CONF_TP), lambda: self.mouse,
                                clock=lambda: self.clock[0], touchpad_finder=touchpad_finder)

    def mouse_plays(self):
        return [a for a in self.mouse.calls if a[1] == 0x40]

    def test_mouse_is_the_default_target(self):
        self.assertTrue(self.bridge.play('snap'))
        self.assertEqual(len(self.mouse_plays()), 1)
        self.assertEqual(self.tp.played, [])

    def test_active_touchpad_receives_the_event(self):
        self.bridge.set_active('touchpad')
        self.assertTrue(self.bridge.play('snap'))
        self.assertEqual(self.tp.played, [('SNAP', 70)])
        self.assertEqual(self.mouse_plays(), [])

    def test_explicit_target_overrides_active(self):
        self.assertTrue(self.bridge.play('edge', target='touchpad'))
        self.assertEqual(self.tp.played, [('KNOCK', 70)])
        self.assertEqual(self.bridge.active, 'mouse')

    def test_unknown_target_ignored(self):
        self.bridge.set_active('tablet')
        self.assertEqual(self.bridge.active, 'mouse')

    def test_mouse_waveform_unsupported_touchpad_still_plays(self):
        """MX Master 4 lacks WHISPER_COLLISION: the touchpad vibration of that event must not be lost."""
        config = HB.Config.parse(CONF_TP + 'whisper = { wave = "WHISPER_COLLISION", touchpad = "TICK" }\n')
        bridge = HB.Bridge(config, lambda: self.mouse, clock=lambda: self.clock[0], touchpad_finder=lambda: self.tp)
        with redirect_stderr(io.StringIO()):
            self.assertTrue(bridge.connect())
            self.assertFalse(bridge.play('whisper'))
            bridge.set_active('touchpad')
            self.clock[0] = 1.0
            self.assertTrue(bridge.play('whisper'))
        self.assertEqual(self.tp.played, [('TICK', 70)])
        self.assertEqual(self.mouse_plays(), [])

    def test_unknown_mouse_waveform_touchpad_still_plays(self):
        with redirect_stderr(io.StringIO()):
            config = HB.Config.parse(CONF_TP + 'odd = { wave = "TURBO", touchpad = "KNOCK" }\n'
                                     'tp_only = { touchpad = "SNAP" }\n')
        bridge = HB.Bridge(config, lambda: self.mouse, clock=lambda: self.clock[0], touchpad_finder=lambda: self.tp)
        self.assertFalse(bridge.play('odd'))
        self.assertFalse(bridge.play('tp_only'))
        self.assertEqual(self.mouse.calls, [])                   # no mouse waveform: the mouse is not even looked up
        bridge.set_active('touchpad')
        self.clock[0] = 1.0
        self.assertTrue(bridge.play('odd'))
        self.assertTrue(bridge.play('tp_only'))
        self.assertEqual(self.tp.played, [('KNOCK', 70), ('SNAP', 70)])

    def test_event_without_touchpad_waveform_plays_nothing(self):
        self.bridge.set_active('touchpad')
        self.assertFalse(self.bridge.play('lock'))
        self.assertEqual(self.tp.played, [])
        self.assertEqual(self.mouse_plays(), [])

    def test_a_muted_event_plays_on_no_device_and_is_not_unknown(self):
        """force = 0 on the line of an event: the documented way to silence that one event (events.toml)."""
        err = io.StringIO()
        with redirect_stderr(err):
            config = HB.Config.parse(CONF_TP.replace('snap = {', 'snap = { force = 0,', 1))
            bridge = HB.Bridge(config, lambda: self.mouse, clock=lambda: self.clock[0],
                               touchpad_finder=lambda: self.tp)
            self.assertFalse(bridge.play('snap'))
            bridge.set_active('touchpad')
            self.assertFalse(bridge.play('snap'))
            self.assertTrue(bridge.play('edge'))                    # the others still play
        self.assertEqual(config.muted, {'snap'})
        self.assertEqual(self.mouse_plays(), [])
        self.assertEqual(self.tp.played, [('KNOCK', 70)])
        self.assertEqual(err.getvalue(), '')                        # known and muted: nothing to warn about

    def test_a_force_other_than_zero_on_an_event_is_refused_with_a_message(self):
        err = io.StringIO()
        with redirect_stderr(err):
            config = HB.Config.parse(CONF_TP.replace('snap = {', 'snap = { force = 30,', 1))
        self.assertEqual(config.muted, set())
        self.assertIn('snap', config.events)
        self.assertIn('force', err.getvalue())

    def test_cooldown_is_shared_between_devices(self):
        self.assertTrue(self.bridge.play('snap'))
        self.bridge.set_active('touchpad')
        self.clock[0] = 0.1
        self.assertFalse(self.bridge.play('snap'))

    def test_waveform_missing_on_device_warns_once(self):
        self.bridge.set_active('touchpad')
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(self.bridge.play('toggle'))
            self.clock[0] = 1.0
            self.assertFalse(self.bridge.play('toggle'))
        self.assertEqual(err.getvalue().count('TOGGLE_ON'), 1)

    def test_absent_touchpad_warns_once(self):
        bridge = HB.Bridge(HB.Config.parse(CONF_TP), lambda: self.mouse, clock=lambda: self.clock[0],
                           touchpad_finder=lambda: None)
        bridge.set_active('touchpad')
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(bridge.play('snap'))
            self.clock[0] = 1.0
            self.assertFalse(bridge.play('snap'))
        self.assertEqual(err.getvalue().count('no haptic touchpad'), 1)

    def test_write_failure_drops_the_node_and_rediscovers_next_time(self):
        self.tp.fail = True
        self.bridge.set_active('touchpad')
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertFalse(self.bridge.play('snap'))
        self.assertEqual(self.tp.closed, 1)
        self.tp.fail = False
        self.clock[0] = 1.0
        self.assertTrue(self.bridge.play('snap'))
        self.assertEqual(len(self.found), 2)

    def test_touchpad_found_once_while_it_works(self):
        self.bridge.set_active('touchpad')
        self.bridge.play('snap')
        self.clock[0] = 1.0
        self.bridge.play('edge')
        self.assertEqual(len(self.found), 1)


if __name__ == '__main__':
    unittest.main()
