"""merge_events.py: the installer adds the events the user's file lacks and never changes what is there."""
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

COMPONENT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(COMPONENT))
import merge_events  # noqa: E402

USER = '''# my settings
force = 30   # quieter
[events]
snap = { wave = "KNOCK", cooldown_ms = 10 }   # mine
'''
PROJECT = '''force = 50
[events]
snap  = { wave = "SUBTLE_COLLISION", touchpad = "SNAP", cooldown_ms = 150 }
failure = { wave = "ANGRY_ALERT", touchpad = "KNOCK", cooldown_ms = 500 }
'''


class MergeEvents(unittest.TestCase):
    def test_adds_missing_events_only(self):
        text, added = merge_events.merge(USER, PROJECT)
        data = tomllib.loads(text)
        self.assertEqual(added, ['failure'])
        self.assertEqual(data['force'], 30)
        self.assertEqual(data['events']['snap'], {'wave': 'KNOCK', 'cooldown_ms': 10})
        self.assertEqual(data['events']['failure'], {'wave': 'ANGRY_ALERT', 'touchpad': 'KNOCK', 'cooldown_ms': 500})
        for comment in ('# my settings', '# quieter', '# mine'):
            self.assertIn(comment, text)

    def test_is_idempotent(self):
        text, _ = merge_events.merge(USER, PROJECT)
        again, added = merge_events.merge(text, PROJECT)
        self.assertEqual((again, added), (text, []))

    def test_file_without_events_table(self):
        text, added = merge_events.merge('force = 10\n', PROJECT)
        self.assertEqual(sorted(added), ['failure', 'snap'])
        self.assertEqual(tomllib.loads(text)['force'], 10)

    def test_main_leaves_a_broken_file_untouched(self):
        with tempfile.TemporaryDirectory() as folder:
            user, project = Path(folder, 'events.toml'), Path(folder, 'project.toml')
            user.write_text('[events\n', encoding='utf-8')
            project.write_text(PROJECT, encoding='utf-8')
            with self.assertRaises(Exception):
                merge_events.main([str(user), str(project)])
            self.assertEqual(user.read_text(encoding='utf-8'), '[events\n')

    def test_a_muted_event_stays_muted_across_a_merge(self):
        """The documented way to silence one event: its line kept, with force = 0. The merge adds what is missing
        and leaves that line alone, install after install; a removed line would come back with its vibration."""
        muted = USER + 'failure = { wave = "ANGRY_ALERT", touchpad = "KNOCK", cooldown_ms = 500, force = 0 }   # no\n'
        project = PROJECT + 'copie = { wave = "SUBTLE_COLLISION", touchpad = "TICK", cooldown_ms = 300 }\n'
        text, added = merge_events.merge(muted, project)
        self.assertEqual(added, ['copie'])
        self.assertEqual(tomllib.loads(text)['events']['failure']['force'], 0)
        self.assertIn('force = 0 }   # no', text)
        again, added = merge_events.merge(text, project)
        self.assertEqual((again, added), (text, []))
        # The other way round, which the old comment of events.toml promised: a removed line does not silence.
        text, added = merge_events.merge(USER, PROJECT)
        self.assertEqual(added, ['failure'])
        self.assertNotIn('force', tomllib.loads(text)['events']['failure'])

    def test_the_project_file_says_how_to_mute(self):
        text = (COMPONENT / 'events.toml').read_text(encoding='utf-8')
        self.assertNotIn('removed here silences', text)
        self.assertIn('force = 0', text.split('[events]')[1])

    def test_main_keeps_a_dated_copy_of_the_file_it_rewrites(self):
        with tempfile.TemporaryDirectory() as folder:
            user, project = Path(folder, 'events.toml'), Path(folder, 'project.toml')
            user.write_text(USER, encoding='utf-8')
            project.write_text(PROJECT, encoding='utf-8')
            self.assertEqual(merge_events.main([str(user), str(project)], now=lambda: '20261011-120000'), 0)
            copy = Path(folder, 'events.toml.20261011-120000')
            self.assertEqual(copy.read_text(encoding='utf-8'), USER)
            self.assertEqual(copy.stat().st_mode & 0o777, user.stat().st_mode & 0o777)
            # Nothing to add: nothing rewritten, no new copy.
            self.assertEqual(merge_events.main([str(user), str(project)], now=lambda: '20261011-120001'), 0)
            self.assertEqual(sorted(p.name for p in Path(folder).iterdir()),
                             ['events.toml', 'events.toml.20261011-120000', 'project.toml'])

    def test_main_never_overwrites_a_copy(self):
        with tempfile.TemporaryDirectory() as folder:
            user, project = Path(folder, 'events.toml'), Path(folder, 'project.toml')
            user.write_text(USER, encoding='utf-8')
            project.write_text(PROJECT, encoding='utf-8')
            Path(folder, 'events.toml.20261011-120000').write_text('older copy', encoding='utf-8')
            with self.assertRaises(FileExistsError):
                merge_events.main([str(user), str(project)], now=lambda: '20261011-120000')
            self.assertEqual(user.read_text(encoding='utf-8'), USER)
            self.assertEqual(Path(folder, 'events.toml.20261011-120000').read_text(encoding='utf-8'), 'older copy')

    def test_main_writes_the_merged_file(self):
        with tempfile.TemporaryDirectory() as folder:
            user, project = Path(folder, 'events.toml'), Path(folder, 'project.toml')
            user.write_text(USER, encoding='utf-8')
            project.write_text(PROJECT, encoding='utf-8')
            self.assertEqual(merge_events.main([str(user), str(project)]), 0)
            self.assertIn('failure', tomllib.loads(user.read_text(encoding='utf-8'))['events'])


if __name__ == '__main__':
    unittest.main()
