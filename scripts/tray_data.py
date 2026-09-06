"""Local Steam library and calendar data for the desktop tray popups."""
from __future__ import annotations

import datetime as dt
from pathlib import Path
import re

_TOKEN = re.compile(r'\s+|//[^\n]*|"((?:\\.|[^"\\])*)"|([{}])')


def keyvalues(text: str) -> dict:
    """Parse the quoted KeyValues subset used by Steam's library manifests."""
    tokens = []
    offset = 0
    for match in _TOKEN.finditer(text):
        if match.start() != offset:
            raise ValueError('Invalid Steam manifest')
        offset = match.end()
        if match[1] is not None:
            tokens.append(re.sub(r'\\(["\\])', r'\1', match[1]))
        elif match[2]:
            tokens.append(match[2])
    if offset != len(text):
        raise ValueError('Invalid Steam manifest')
    index = 0

    def parse(nested=False):
        nonlocal index
        result = {}
        while index < len(tokens):
            key = tokens[index]
            index += 1
            if key == '}':
                if not nested:
                    raise ValueError('Unexpected closing brace')
                return result
            if key == '{' or index == len(tokens):
                raise ValueError('Missing key or value')
            value = tokens[index]
            index += 1
            if value == '}':
                raise ValueError('Missing value')
            result[key.lower()] = parse(True) if value == '{' else value
        if nested:
            raise ValueError('Unclosed object')
        return result

    return parse()


def read_keyvalues(path: Path) -> dict:
    try:
        return keyvalues(path.read_text(encoding='utf-8-sig'))
    except (OSError, UnicodeError, ValueError):
        return {}


def steam_roots(home: Path) -> list[Path]:
    candidates = [home / '.var/app/com.valvesoftware.Steam/.local/share/Steam',
                  home / '.local/share/Steam', home / '.steam/steam']
    return list(dict.fromkeys(p.resolve() for p in candidates if (p / 'steamapps').is_dir()))


def number(value) -> int:
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        return 0


def steam_art(root: Path, appid: str, hero=False) -> Path | None:
    cache = root / 'appcache/librarycache'
    names = ('library_hero.jpg', 'library_header.jpg', 'header.jpg') if hero else ('library_header.jpg', 'header.jpg', 'library_hero.jpg')
    for name in names:
        candidates = [cache / appid / name, cache / f'{appid}_{name}']
        candidates += sorted((cache / appid).glob(f'*/{name}'))
        for candidate in candidates:
            if candidate.is_file():
                return candidate
    return None


def steam_library(home: Path) -> dict:
    roots = steam_roots(home)
    games = {}
    updates = 0
    visited = set()
    for root in roots:
        folders = read_keyvalues(root / 'steamapps/libraryfolders.vdf').get('libraryfolders', {})
        libraries = [root]
        for value in folders.values():
            path = value.get('path') if isinstance(value, dict) else value
            if path and Path(path).is_absolute():
                libraries.append(Path(path))
        for library in libraries:
            apps = (library / 'steamapps').resolve()
            if apps in visited:
                continue
            visited.add(apps)
            for manifest in apps.glob('appmanifest_*.acf'):
                app = read_keyvalues(manifest).get('appstate', {})
                appid = app.get('appid', '')
                if not appid.isdecimal():
                    continue
                flags = number(app.get('stateflags'))
                if flags & 2:
                    updates += 1
                name = app.get('name', '')
                if not name or not flags & 4 or flags & 1:
                    continue
                if (name.startswith(('Steam Linux Runtime', 'Steamworks Common Redistributables'))
                        or re.match(r'^Proton(?: \d| Experimental| Hotfix|$)', name)):
                    continue
                install = app.get('installdir', '')
                if not install or not (apps / 'common' / install).is_dir():
                    continue
                games[appid] = {'id': appid, 'name': name,
                                'last_played': number(app.get('lastplayed')),
                                'update': bool(flags & 2),
                                'art': steam_art(root, appid),
                                'hero': steam_art(root, appid, True)}
    return {'games': sorted(games.values(), key=lambda g: (-g['last_played'], g['name'].casefold())),
            'updates': updates, 'found': bool(roots)}


def event_time(value: str, all_day=False) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    # All-day dates are dates, not UTC instants; converting them changes the day.
    return parsed if all_day else parsed.astimezone()


def visible_events(events: list, calendars: list) -> list[dict]:
    by_id = {c['id']: c for c in calendars}
    result = []
    for source in events:
        calendar = by_id.get(source.get('calendarId'), {})
        if source.get('status') == 'cancelled' or calendar.get('hidden') or calendar.get('syncDisabled') or calendar.get('holdsTasks'):
            continue
        try:
            all_day = bool(source.get('allDay'))
            start = event_time(source['start'], all_day)
            end = event_time(source['end'], all_day)
        except (KeyError, TypeError, ValueError):
            continue
        result.append({**source, '_start': start, '_end': end,
                       '_calendar': calendar.get('name', 'Calendar'),
                       '_color': calendar.get('color') or '#b4befe'})
    return sorted(result, key=lambda e: (e['_start'].date(), not e.get('allDay'), e['_start'].strftime('%H:%M')))


def events_on(events: list[dict], day: dt.date) -> list[dict]:
    result = []
    for event in events:
        start, end = event['_start'], event['_end']
        # End is exclusive for all-day and timed events alike.
        last = (end - dt.timedelta(microseconds=1)).date() if end > start else start.date()
        if start.date() <= day <= last:
            result.append(event)
    return result


def upcoming(events: list[dict], now: dt.datetime) -> list[dict]:
    return [e for e in events if (e['_end'].date() > now.date() if e.get('allDay') else e['_end'] > now)]
