#!/usr/bin/env python3
"""A Steam tray launcher using installed games and locally cached cover art."""
import datetime as dt
from pathlib import Path
import subprocess

from tray_data import steam_library
from tray_popup import Gtk, Popup, button, clear, css, label, picture, serve


class SteamTray(Popup):
    def __init__(self):
        super().__init__('steam', 'Steam', 'com.valvesoftware.Steam')
        self.body.pack_start(label('Jump back in', 'heading'), False, False, 0)
        self.summary = label('Your installed games, one click away', 'muted')
        self.body.pack_start(self.summary, False, False, 0)
        self.games = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.games.pack_start(label('Loading your library…', 'muted'), False, False, 0)
        self.body.pack_start(self.games, False, False, 0)
        self.body.pack_start(Gtk.Separator(), False, False, 0)
        footer = Gtk.Box(spacing=6)
        footer.pack_start(button('Library', self.open_app, 'primary', 'view-grid-symbolic'), True, True, 0)
        footer.pack_start(button('', lambda: self.open_uri('steam://open/downloads'), icon='folder-download-symbolic', tooltip='Downloads and updates'), False, False, 0)
        footer.pack_start(button('', lambda: self.open_uri('steam://open/friends'), icon='system-users-symbolic', tooltip='Friends and chat'), False, False, 0)
        footer.pack_start(button('', lambda: self.open_uri('steam://exit'), icon='application-exit-symbolic', tooltip='Quit Steam'), False, False, 0)
        self.body.pack_start(footer, False, False, 0)
        self.refresh()

    def open_uri(self, uri):
        self.launch(['xdg-open', uri])

    def open_app(self):
        self.open_uri('steam://open/games')

    def play(self, game):
        self.open_uri('steam://rungameid/' + game['id'])

    def refresh(self):
        def load():
            data = steam_library(Path.home())
            data['running'] = subprocess.run(['pgrep', '-x', 'steam'], stdout=subprocess.DEVNULL, timeout=2).returncode == 0
            return data
        self.work(load, self.render)

    @staticmethod
    def last_played(game):
        if game['update']:
            return 'Update available'
        if not game['last_played']:
            return 'Ready to play'
        date = dt.datetime.fromtimestamp(game['last_played']).date()
        days = (dt.date.today() - date).days
        if days <= 0:
            return 'Played today'
        if days == 1:
            return 'Played yesterday'
        return 'Last played ' + date.strftime('%d %b')

    def render(self, data):
        games = data['games']
        self.badge.set_text('Running' if data['running'] else 'Ready')
        count = len(games)
        self.summary.set_text(f'{count} installed games' + (f" · {data['updates']} update{'s' if data['updates'] != 1 else ''} pending" if data['updates'] else ''))
        self.notifier.tooltip('Steam', f'{count} installed games\nClick: quick launcher · Middle-click: Library')
        snapshot = (dt.date.today(), [(g['id'], g['name'], g['last_played'], g['update'], g['art'], g['hero']) for g in games])
        if getattr(self, '_snapshot', None) == snapshot:
            return
        self._snapshot = snapshot
        clear(self.games)
        if not games:
            empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            empty.pack_start(picture(None, 354, 100), False, False, 0)
            empty.pack_start(label('Your next game starts here', 'title'), False, False, 0)
            empty.pack_start(label('Open Steam to install a game.', 'muted'), False, False, 0)
            self.games.pack_start(empty, False, False, 0)
            return
        game = games[0]
        hero = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10), 'hero')
        hero.pack_start(picture(game['hero'] or game['art'], 354, 136), False, False, 0)
        info = css(Gtk.Box(spacing=12), 'hero-info')
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        text.pack_start(label(game['name'], 'title', True), False, False, 0)
        text.pack_start(label(self.last_played(game), 'muted'), False, False, 0)
        info.pack_start(text, True, True, 0)
        info.pack_start(button('Play', lambda g=game: self.play(g), 'play-game', 'media-playback-start-symbolic', f"Play {game['name']}"), False, False, 0)
        hero.pack_start(info, False, False, 0)
        self.games.pack_start(hero, False, False, 0)
        for game in games[1:4]:
            row = css(Gtk.Button(), 'game-row')
            describe = game['name'] + ' · ' + self.last_played(game)
            row.set_tooltip_text(describe)
            row.get_accessible().set_name('Play ' + game['name'])
            content = Gtk.Box(spacing=12)
            content.pack_start(picture(game['art'], 86, 44), False, False, 0)
            text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, valign=Gtk.Align.CENTER)
            text.pack_start(label(game['name'], 'body', True), False, False, 0)
            text.pack_start(label(self.last_played(game), 'muted'), False, False, 0)
            content.pack_start(text, True, True, 0)
            content.pack_end(Gtk.Image.new_from_icon_name('media-playback-start-symbolic', Gtk.IconSize.MENU), False, False, 0)
            row.add(content)
            row.connect('clicked', lambda _b, g=game: self.play(g))
            self.games.pack_start(row, False, False, 0)


if __name__ == '__main__':
    serve(SteamTray, 'steam')
