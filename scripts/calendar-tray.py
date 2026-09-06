#!/usr/bin/env python3
"""Month and agenda popup for the existing DankCalendar daemon."""
import calendar
import datetime as dt
import json
import re
import subprocess

from tray_data import events_on, upcoming, visible_events
from tray_popup import Gtk, Popup, SCRIPTS, button, clear, css, label, serve


def ipc(method, **params):
    command = [str(SCRIPTS / 'dcal.sh'), 'ipc', method, *(f'{k}={v}' for k, v in params.items())]
    result = subprocess.run(command, capture_output=True, text=True, timeout=6)
    if result.returncode:
        raise RuntimeError('Calendar is unavailable. Open DankCalendar to reconnect.')
    return json.loads(result.stdout)


class CalendarTray(Popup):
    def __init__(self):
        super().__init__('calendar', 'Dank Calendar', 'com.danklinux.dankcalendar')
        self.month = dt.date.today().replace(day=1)
        self.selected = None
        self.events = []
        self.body.pack_start(label('Make room for your day', 'heading'), False, False, 0)
        nav = Gtk.Box(spacing=4)
        self.month_label = label('', 'title')
        nav.pack_start(self.month_label, True, True, 0)
        nav.pack_start(button('Today', self.today, 'small'), False, False, 0)
        nav.pack_start(button('', lambda: self.change_month(-1), 'small', 'go-previous-symbolic', 'Previous month'), False, False, 0)
        nav.pack_start(button('', lambda: self.change_month(1), 'small', 'go-next-symbolic', 'Next month'), False, False, 0)
        self.body.pack_start(nav, False, False, 0)
        self.grid = Gtk.Grid(column_homogeneous=True, row_spacing=3, column_spacing=3)
        self.body.pack_start(self.grid, False, False, 0)
        self.body.pack_start(Gtk.Separator(), False, False, 0)
        section = Gtk.Box(spacing=8)
        self.agenda_title = label('UP NEXT', 'eyebrow')
        section.pack_start(self.agenda_title, True, True, 0)
        section.pack_end(button('Upcoming', self.show_upcoming, 'small'), False, False, 0)
        self.body.pack_start(section, False, False, 0)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(155)
        scroll.set_max_content_height(155)
        scroll.set_propagate_natural_height(True)
        self.agenda = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        scroll.add(self.agenda)
        self.body.pack_start(scroll, False, False, 0)
        footer = Gtk.Box(spacing=6)
        footer.pack_start(button('Open calendar', self.open_app, 'primary'), True, True, 0)
        footer.pack_start(button('', self.new_event, icon='list-add-symbolic', tooltip='New event · opens a draft'), False, False, 0)
        footer.pack_start(button('', self.sync, icon='view-refresh-symbolic', tooltip='Sync calendars'), False, False, 0)
        self.body.pack_start(footer, False, False, 0)
        self.render_month()
        self.agenda.pack_start(label('Loading your agenda…', 'muted'), False, False, 0)
        self.refresh()

    def open_app(self):
        self.launch([str(SCRIPTS / 'calendar-open.sh'), 'agenda'])

    def new_event(self):
        args = [str(SCRIPTS / 'dcal.sh'), 'ipc', 'ui.newEvent']
        if self.selected and self.selected != dt.date.today():
            start = dt.datetime.combine(self.selected, dt.time(9)).astimezone()
            args.append('start=' + start.isoformat())
        self.launch(args)

    def open_event(self, event):
        self.launch([str(SCRIPTS / 'dcal.sh'), 'ipc', 'ui.openEvent',
                     'uid=' + event['uid'], 'start=' + event['start']])

    def sync(self):
        if not self.busy:
            self.badge.set_text('Syncing…')
            self.work(lambda: ipc('accounts.refresh'), lambda _: self.refresh())

    def today(self):
        self.month = dt.date.today().replace(day=1)
        self.selected = dt.date.today()
        self.render_month()
        self.refresh()

    def show_upcoming(self):
        self.month = dt.date.today().replace(day=1)
        self.selected = None
        self.render_month()
        self.refresh()

    def change_month(self, delta):
        index = self.month.year * 12 + self.month.month - 1 + delta
        self.month = dt.date(index // 12, index % 12 + 1, 1)
        self.selected = self.month
        self.render_month()
        clear(self.agenda)
        self.agenda.pack_start(label('Loading this month…', 'muted'), False, False, 0)
        self.agenda.show_all()
        self.refresh()

    def select_day(self, day):
        self.selected = day
        self.render_month()
        self.render_agenda()

    def refresh(self):
        month = self.month
        weeks = calendar.Calendar(firstweekday=0).monthdatescalendar(month.year, month.month)
        start = dt.datetime.combine(weeks[0][0], dt.time.min).astimezone()
        end_day = max(weeks[-1][-1] + dt.timedelta(days=1), dt.date.today() + dt.timedelta(days=15))
        end = dt.datetime.combine(end_day, dt.time.min).astimezone()

        def load():
            calendars = ipc('calendars.list')
            data = ipc('events.list', **{'from': start.isoformat(), 'to': end.isoformat(), 'limit': 250})
            return calendars, data

        def loaded(data):
            if self.month != month:
                self.refresh()
                return
            calendars, payload = data
            self.events = visible_events(payload.get('events', []), calendars)
            count = sum(not c.get('hidden') and not c.get('syncDisabled') and not c.get('holdsTasks') for c in calendars)
            self.badge.set_text(f'{count} calendars')
            self.notifier.tooltip('Dank Calendar', dt.date.today().strftime('%A, %d %B') + '\nClick: agenda · Middle-click: full calendar')
            self.more = payload.get('total', 0) > len(payload.get('events', []))
            self.render_month()
            self.render_agenda()

        self.work(load, loaded)

    def render_month(self):
        self.month_label.set_text(self.month.strftime('%B %Y'))
        clear(self.grid)
        for col, day in enumerate(('M', 'T', 'W', 'T', 'F', 'S', 'S')):
            header = label(day, 'weekday')
            header.set_xalign(0.5)
            self.grid.attach(header, col, 0, 1, 1)
        weeks = calendar.Calendar(firstweekday=0).monthdatescalendar(self.month.year, self.month.month)
        for row, week in enumerate(weeks, 1):
            for col, day in enumerate(week):
                items = events_on(self.events, day)
                widget = button('', lambda d=day: self.select_day(d), 'day', tooltip=day.strftime('%A, %d %B') + (f' · {len(items)} events' if items else ''))
                if day.month != self.month.month:
                    css(widget, 'other-month')
                if day == dt.date.today():
                    css(widget, 'today')
                if day == self.selected:
                    css(widget, 'selected')
                content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
                number = label(str(day.day), 'day-number')
                number.set_xalign(0.5)
                content.pack_start(number, False, False, 0)
                dot = label('•' if items else ' ', 'event-dot')
                dot.set_xalign(0.5)
                content.pack_start(dot, False, False, 0)
                widget.add(content)
                self.grid.attach(widget, col, row, 1, 1)
        self.grid.show_all()

    def render_agenda(self):
        clear(self.agenda)
        now = dt.datetime.now().astimezone()
        items = events_on(self.events, self.selected) if self.selected else upcoming(self.events, now)
        self.agenda_title.set_text(self.selected.strftime('%a, %d %b').upper() if self.selected else 'UP NEXT')
        if not items:
            empty = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6), 'empty-agenda')
            empty.pack_start(label('A little breathing room', 'title'), False, False, 0)
            empty.pack_start(label('No events on this day.' if self.selected else 'No upcoming events in this view.', 'muted'), False, False, 0)
            self.agenda.pack_start(empty, False, False, 0)
        for event in items[:12]:
            row = css(Gtk.Button(), 'event-row')
            row.get_accessible().set_name('Open ' + (event.get('summary') or 'Untitled event'))
            content = Gtk.Box(spacing=10)
            stripe = css(Gtk.Box(), 'event-stripe')
            color = event['_color']
            if re.fullmatch(r'#[0-9a-fA-F]{6}', color):
                provider = Gtk.CssProvider()
                provider.load_from_data(f'* {{ background-color: {color}; }}'.encode())
                stripe.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            content.pack_start(stripe, False, False, 0)
            text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            start = event['_start']
            when = 'All day' if event.get('allDay') else start.strftime('%H:%M') + '–' + event['_end'].strftime('%H:%M')
            if not self.selected:
                when = ('Today' if start.date() == now.date() else start.strftime('%a, %d %b')) + ' · ' + when
            text.pack_start(label(when, 'event-time'), False, False, 0)
            text.pack_start(label(event.get('summary') or 'Untitled event', 'body', True), False, False, 0)
            text.pack_start(label(event.get('location') or event['_calendar'], 'muted', True), False, False, 0)
            content.pack_start(text, True, True, 0)
            row.add(content)
            row.set_sensitive(bool(event.get('uid')))
            row.connect('clicked', lambda _b, e=event: self.open_event(e))
            self.agenda.pack_start(row, False, False, 0)
        if getattr(self, 'more', False) or len(items) > 12:
            self.agenda.pack_start(button('More in Calendar', self.open_app, 'small'), False, False, 0)
        self.agenda.show_all()


if __name__ == '__main__':
    serve(CalendarTray, 'calendar')
