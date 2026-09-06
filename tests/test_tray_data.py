import datetime as dt
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from tray_data import event_time, events_on, keyvalues, steam_library, upcoming, visible_events


class SteamLibraryTest(unittest.TestCase):
    def test_quoted_keyvalues_and_comments(self):
        data = keyvalues('// comment\n"AppState" { "name" "A \\"quoted\\" game" "Nested" { "id" "42" } }')
        self.assertEqual(data['appstate']['name'], 'A "quoted" game')
        self.assertEqual(data['appstate']['nested']['id'], '42')
        for text in ('"key" {', '"key"', '}', 'garbage'):
            with self.assertRaises(ValueError):
                keyvalues(text)

    def test_installed_games_across_libraries_and_runtime_filter(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            root = home / '.local/share/Steam'
            apps = root / 'steamapps'
            extra = home / 'Games on disk'
            apps.mkdir(parents=True)
            (extra / 'steamapps').mkdir(parents=True)
            (apps / 'libraryfolders.vdf').write_text(f'"libraryfolders" {{ "0" {{ "path" "{root}" }} "1" {{ "path" "{extra}" }} }}')
            records = [(apps, '1', 'First game', '4', '10'),
                       (extra / 'steamapps', '2', 'Recent game', '6', '20'),
                       (apps, '3', 'Proton Experimental', '6', '30'),
                       (apps, '4', 'Not installed', '1', '40')]
            for path, appid, name, flags, played in records:
                (path / 'common' / name).mkdir(parents=True)
                (path / f'appmanifest_{appid}.acf').write_text(f'"AppState" {{ "appid" "{appid}" "name" "{name}" "installdir" "{name}" "StateFlags" "{flags}" "LastPlayed" "{played}" }}')
            (apps / 'appmanifest_broken.acf').write_text('"AppState" {')
            data = steam_library(home)
            self.assertEqual([g['id'] for g in data['games']], ['2', '1'])
            self.assertEqual(data['updates'], 2)
            self.assertTrue(data['games'][0]['update'])
            self.assertFalse(data['games'][1]['update'])

    def test_missing_library_is_an_empty_state(self):
        with tempfile.TemporaryDirectory() as path:
            self.assertEqual(steam_library(Path(path)), {'games': [], 'updates': 0, 'found': False})


class CalendarDatesTest(unittest.TestCase):
    def event(self, start='2026-09-07T00:00:00Z', end='2026-09-08T00:00:00Z', **fields):
        return {'uid': 'example', 'calendarId': 'one', 'start': start, 'end': end, 'allDay': True, **fields}

    def test_all_day_dates_do_not_shift_to_the_previous_day(self):
        self.assertEqual(event_time('2026-09-07T00:00:00Z', True).date(), dt.date(2026, 9, 7))
        events = visible_events([self.event()], [{'id': 'one'}])
        self.assertFalse(events_on(events, dt.date(2026, 9, 6)))
        self.assertEqual(len(events_on(events, dt.date(2026, 9, 7))), 1)
        self.assertFalse(events_on(events, dt.date(2026, 9, 8)))

    def test_hidden_cancelled_and_malformed_events_are_excluded(self):
        events = [self.event(), self.event(status='cancelled'), self.event(calendarId='hidden'),
                  self.event(calendarId='disabled'), self.event(start='bad date')]
        calendars = [{'id': 'one'}, {'id': 'hidden', 'hidden': True}, {'id': 'disabled', 'syncDisabled': True}]
        self.assertEqual(len(visible_events(events, calendars)), 1)

    def test_ongoing_events_are_in_upcoming_but_finished_ones_are_not(self):
        now = dt.datetime(2026, 9, 7, 12, tzinfo=dt.timezone.utc)
        events = visible_events([self.event(),
            self.event('2026-09-07T11:00:00Z', '2026-09-07T13:00:00Z', allDay=False),
            self.event('2026-09-07T09:00:00Z', '2026-09-07T10:00:00Z', allDay=False)], [])
        self.assertEqual(len(upcoming(events, now)), 2)
        self.assertFalse(upcoming(events, now + dt.timedelta(days=1)))

    def test_multiday_events_end_exclusively(self):
        events = visible_events([self.event(end='2026-09-10T00:00:00Z')], [])
        self.assertEqual(len(events_on(events, dt.date(2026, 9, 9))), 1)
        self.assertFalse(events_on(events, dt.date(2026, 9, 10)))


if __name__ == '__main__':
    unittest.main()
