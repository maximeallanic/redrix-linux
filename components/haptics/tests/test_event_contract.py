"""Event contract: events.toml is the registry. Every registered event can be played by the bridge, every event
haptic-events can emit is registered, and every registered event has an emitter in the kit."""
import importlib.machinery
import importlib.util
import re
import tomllib
import unittest
from pathlib import Path

COMPONENT = Path(__file__).resolve().parent.parent
EXTENSION = COMPONENT / 'haptic-events@maximeallanic.github.io'
NAME = re.compile(r'^[a-z]+(-[a-z]+)*$')
# Event names appear in the extension as play('name') calls or as values returned by events.js.
PLAYED = re.compile(r"""\b_?play\(\s*'([^']+)'""")
RETURNED = re.compile(r"""(?:return|\?|:)\s*'([a-z]+(?:-[a-z]+)*)'""")


def bridge():
    loader = importlib.machinery.SourceFileLoader('haptic_bridge', str(COMPONENT / 'haptic-bridge'))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader('haptic_bridge', loader))
    loader.exec_module(module)
    return module


def extension_sources():
    return [p.read_text(encoding='utf-8') for p in sorted(EXTENSION.glob('*.js'))]


class EventContract(unittest.TestCase):
    def setUp(self):
        self.text = (COMPONENT / 'events.toml').read_text(encoding='utf-8')
        self.events = tomllib.loads(self.text)['events']

    def test_names_follow_the_convention(self):
        self.assertEqual([name for name in self.events if not NAME.match(name)], [])

    def test_every_event_is_playable_by_the_bridge(self):
        config = bridge().Config.parse(self.text)
        self.assertEqual(set(config.events), set(self.events))
        wanted = {name for name, spec in self.events.items() if 'wave' in spec}
        self.assertEqual({name for name in wanted if config.events[name][0] is None}, set())
        wanted = {name for name, spec in self.events.items() if 'touchpad' in spec}
        self.assertEqual(wanted - set(config.touchpad), set())
        for name, spec in self.events.items():
            self.assertIsInstance(spec['cooldown_ms'], int, name)

    def test_played_literals_are_registered(self):
        played = {m.group(1) for text in extension_sources() for m in PLAYED.finditer(text)}
        self.assertTrue(played)
        self.assertEqual(played - set(self.events), set())

    def test_every_registered_event_has_an_emitter(self):
        names = set()
        for text in extension_sources():
            names |= {m.group(1) for m in PLAYED.finditer(text)}
            names |= {m.group(1) for m in RETURNED.finditer(text)}
        self.assertEqual(set(self.events) - names, set())

    def test_the_client_uses_the_bridge_bus_name(self):
        client = (EXTENSION / 'hapticClient.js').read_text(encoding='utf-8')
        module = bridge()
        for value in (module.BUS_NAME, module.OBJ_PATH, module.IFACE):
            self.assertIn(f"'{value}'", client)


if __name__ == '__main__':
    unittest.main()
