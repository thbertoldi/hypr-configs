#!/usr/bin/env python3
"""Sound/focus popups and a passive volume/brightness display."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys
import time

import audio_backend as audio
from focus_timer import FocusTimer
from tray_popup import Gdk, Gio, GLib, Gtk, GtkLayerShell, Popup, SCRIPTS, button, clear, css, label, serve

BUS = 'org.thbertoldi.DesktopControls'
OBJECT = '/org/thbertoldi/DesktopControls'


class VolumeRow(Gtk.Box):
    def __init__(self, title, kind, target, owner):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.kind, self.target, self.owner = kind, target, owner
        self.updating = self.dragging = False
        self.pending = 0
        heading = Gtk.Box(spacing=8)
        heading.pack_start(label(title, 'body', True), True, True, 0)
        self.value = label('', 'muted')
        heading.pack_start(self.value, False, False, 0)
        self.mute = button('', lambda: owner.change(lambda: audio.toggle_mute(kind, target)),
                           'small', 'audio-volume-high-symbolic', 'Toggle mute · ' + title)
        heading.pack_start(self.mute, False, False, 0)
        self.pack_start(heading, False, False, 0)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.set_draw_value(False)
        self.scale.get_accessible().set_name(title + ' volume')
        self.scale.connect('value-changed', self.changed)
        self.scale.connect('button-press-event', self.drag_start)
        self.scale.connect('button-release-event', self.drag_end)
        self.connect('destroy', self.destroyed)
        self.pack_start(self.scale, False, False, 0)

    def drag_start(self, *_):
        self.dragging = True
        return False

    def drag_end(self, *_):
        self.dragging = False
        return False

    def changed(self, scale):
        if self.updating:
            return
        self.value.set_text(f'{round(scale.get_value())}%')
        if self.pending:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(70, self.write)

    def write(self):
        self.pending = 0
        value = self.scale.get_value()
        self.owner.change(lambda: audio.set_volume(self.kind, self.target, value))
        return GLib.SOURCE_REMOVE

    def destroyed(self, *_):
        if self.pending:
            GLib.source_remove(self.pending)
            self.pending = 0

    def update(self, state):
        self.set_sensitive(state is not None)
        if state is None or self.dragging or self.pending:
            return
        self.updating = True
        self.scale.set_value(state['volume'])
        self.updating = False
        self.value.set_text('Muted' if state['mute'] else f"{state['volume']}%")
        self.mute.set_image(Gtk.Image.new_from_icon_name(
            ('microphone-sensitivity-muted-symbolic' if state['mute'] else 'audio-input-microphone-symbolic')
            if self.kind == 'source' else
            ('audio-volume-muted-symbolic' if state['mute'] else 'audio-volume-high-symbolic'), Gtk.IconSize.MENU))


class SoundPopup(Popup):
    def __init__(self):
        super().__init__('audio', 'Sound', 'audio-card-symbolic', tray=False, poll_interval=2)
        self.writer = ThreadPoolExecutor(max_workers=1)
        self.writes = 0
        self.updating = False
        self.rows = {}
        self.badge.set_text('Live')
        self.body.pack_start(label('Sound & devices', 'heading'), False, False, 0)
        self.outputs = self.selector('OUTPUT', 'sink')
        self.output_volume = VolumeRow('Playback', 'sink', '@DEFAULT_SINK@', self)
        self.body.pack_start(self.output_volume, False, False, 0)
        self.body.pack_start(Gtk.Separator(), False, False, 0)
        self.inputs = self.selector('MICROPHONE', 'source')
        self.input_volume = VolumeRow('Input level', 'source', '@DEFAULT_SOURCE@', self)
        self.body.pack_start(self.input_volume, False, False, 0)
        self.body.pack_start(Gtk.Separator(), False, False, 0)
        self.body.pack_start(label('APPLICATIONS', 'eyebrow'), False, False, 0)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(90)
        scroll.set_max_content_height(170)
        scroll.set_propagate_natural_height(True)
        self.apps = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        scroll.add(self.apps)
        self.body.pack_start(scroll, False, False, 0)
        footer = Gtk.Box(spacing=6)
        footer.pack_start(button('Advanced mixer', self.open_app, 'primary'), True, True, 0)
        footer.pack_start(button('', lambda: self.launch([str(SCRIPTS / 'app-launch.sh'), 'blueman-manager']),
                                 icon='bluetooth-symbolic', tooltip='Pair or manage Bluetooth devices'), False, False, 0)
        self.body.pack_start(footer, False, False, 0)
        self.refresh()

    def selector(self, text, kind):
        self.body.pack_start(label(text, 'eyebrow'), False, False, 0)
        combo = Gtk.ComboBoxText()
        combo.get_accessible().set_name(text.title() + ' device')
        combo.connect('changed', lambda widget: self.select(kind, widget.get_active_id()))
        self.body.pack_start(combo, False, False, 0)
        return combo

    def select(self, kind, key):
        if key and not self.updating:
            self.change(lambda: audio.choose(kind, key))

    def change(self, operation):
        self.writes += 1
        def done(future):
            try:
                future.result()
                error = None
            except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
                error = str(exc)
            GLib.idle_add(finished, error)
        def finished(error):
            self.writes -= 1
            if error:
                self.error.set_text(error)
                self.error.show()
            else:
                self.error.hide()
            self.refresh()
            return GLib.SOURCE_REMOVE
        self.writer.submit(operation).add_done_callback(done)

    def open_app(self):
        self.launch([str(SCRIPTS / 'app-launch.sh'), 'pavucontrol'])

    def refresh(self):
        if not self.writes:
            self.work(audio.snapshot, self.render)

    def render(self, data):
        if self.writes:
            return
        self.updating = True
        for combo, entries in ((self.outputs, data['outputs']), (self.inputs, data['inputs'])):
            signature = [(d['key'], d['label']) for d in entries]
            if getattr(combo, 'signature', None) != signature:
                combo.remove_all()
                for item in entries:
                    combo.append(item['key'], item['label'])
                combo.signature = signature
            combo.set_active_id(next((d['key'] for d in entries if d['selected']), None))
            combo.set_sensitive(bool(entries))
        self.updating = False
        self.output_volume.update(data['sink'])
        self.input_volume.update(data['source'])
        signature = [(app['id'], app['name']) for app in data['apps']]
        if getattr(self, 'app_signature', None) != signature:
            clear(self.apps)
            self.rows = {}
            for app in data['apps']:
                row = VolumeRow(app['name'], 'sink-input', app['id'], self)
                self.rows[app['id']] = row
                self.apps.pack_start(row, False, False, 0)
            if not data['apps']:
                self.apps.pack_start(label('Apps appear here when they play audio.', 'muted'), False, False, 0)
            self.app_signature = signature
        for app in data['apps']:
            self.rows[app['id']].update(app)


class FocusPopup(Popup):
    def __init__(self):
        super().__init__('focus', 'Focus', 'appointment-soon-symbolic', tray=False, poll_interval=1)
        self.timer = FocusTimer()
        self.body.pack_start(label('One thing at a time', 'heading'), False, False, 0)
        self.countdown = label('25:00', 'countdown')
        self.countdown.set_xalign(.5)
        self.body.pack_start(self.countdown, False, False, 0)
        self.progress = Gtk.ProgressBar()
        self.body.pack_start(self.progress, False, False, 0)
        self.description = label('', 'muted')
        self.description.set_xalign(.5)
        self.body.pack_start(self.description, False, False, 0)
        choices = Gtk.Box(spacing=8)
        for duration in (25, 50):
            choices.pack_start(button(f'{duration} minutes', lambda d=duration: self.action('start', str(d)), 'primary'), True, True, 0)
        self.body.pack_start(choices, False, False, 0)
        self.controls = Gtk.Box(spacing=8)
        self.pause = button('Pause', lambda: self.action('pause'))
        self.controls.pack_start(self.pause, True, True, 0)
        self.controls.pack_start(button('Finish session', lambda: self.action('stop')), True, True, 0)
        self.body.pack_start(self.controls, False, False, 0)
        self.controls.set_no_show_all(True)
        self.refresh()

    def action(self, *args):
        self.work(lambda: subprocess.run([sys.executable, str(SCRIPTS / 'focus_timer.py'), *args],
                                         check=True, capture_output=True, timeout=8), lambda _: self.refresh())

    def refresh(self):
        state = self.timer.status()
        self.badge.set_text('Paused' if state['paused'] else 'Focusing' if state['active'] else 'Ready')
        self.countdown.set_text(state['display'] if state['active'] else '25:00')
        self.progress.set_fraction(state['fraction'] if state['active'] else 0)
        self.description.set_text('Notifications wait until you finish.' if state['active'] else 'Choose a session. Make a little space.')
        self.pause.set_label('Resume' if state['paused'] else 'Pause')
        if state['active']:
            self.controls.show()
            for child in self.controls.get_children():
                child.show_all()
        else:
            self.controls.hide()
        self.position()


class OSD:
    def __init__(self):
        self.timeout = 0
        self.generation = 0
        self.names = {}
        self.names_updated = 0
        self.loading_names = False
        self.category = None
        self.window = Gtk.Window()
        self.window.set_name('desktop-osd')
        self.window.set_decorated(False)
        self.window.set_visual(self.window.get_screen().get_rgba_visual())
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, 'desktop-osd')
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.BOTTOM, 64)
        self.window.connect('realize', self.passive)
        card = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10), 'osd-card')
        card.set_size_request(320, -1)
        row = Gtk.Box(spacing=12)
        self.icon = Gtk.Image()
        row.pack_start(self.icon, False, False, 0)
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        self.title = label('', 'title')
        self.detail = label('', 'muted', True)
        text.pack_start(self.title, False, False, 0)
        text.pack_start(self.detail, False, False, 0)
        row.pack_start(text, True, True, 0)
        self.value = label('', 'osd-value')
        row.pack_start(self.value, False, False, 0)
        card.pack_start(row, False, False, 0)
        self.progress = Gtk.ProgressBar()
        card.pack_start(self.progress, False, False, 0)
        self.window.add(card)

    def passive(self, *_):
        import cairo
        self.window.get_window().input_shape_combine_region(cairo.Region(), 0, 0)

    def show(self, category, value, muted, x, y):
        self.generation += 1
        self.category = category
        monitor = Gdk.Display.get_default().get_monitor_at_point(x, y)
        GtkLayerShell.set_monitor(self.window, monitor)
        names = {'volume': ('Volume', 'audio-volume-high-symbolic', 'Audio output'),
                 'mic': ('Microphone', 'audio-input-microphone-symbolic', 'Audio input'),
                 'brightness': ('Brightness', 'display-brightness-symbolic', 'Laptop display')}
        title, icon, detail = names[category]
        self.title.set_text(title)
        self.detail.set_text(self.names.get(category, detail))
        self.value.set_text('Muted' if muted else f'{round(value)}%')
        self.icon.set_from_icon_name('microphone-sensitivity-muted-symbolic' if muted and category == 'mic' else
                                     'audio-volume-muted-symbolic' if muted else icon, Gtk.IconSize.LARGE_TOOLBAR)
        self.progress.set_fraction(0 if muted else max(0, min(1, value / 100)))
        context = self.window.get_style_context()
        for name in names:
            context.remove_class(name)
        context.add_class(category)
        self.window.show_all()
        if self.timeout:
            GLib.source_remove(self.timeout)
        self.timeout = GLib.timeout_add(1700, self.dismiss)
        if category != 'brightness' and not self.loading_names and time.monotonic() - self.names_updated > 2:
            self.loading_names = True
            def load():
                names = {}
                try:
                    data = audio.snapshot()
                    for kind, choices in (('volume', data['outputs']), ('mic', data['inputs'])):
                        selected = next((d['label'] for d in choices if d['selected']), None)
                        if selected:
                            names[kind] = selected
                except (OSError, RuntimeError, subprocess.SubprocessError):
                    pass
                GLib.idle_add(update, names)
            def update(names):
                self.loading_names = False
                self.names_updated = time.monotonic()
                self.names = names
                name = names.get(self.category)
                if name:
                    self.detail.set_text(name)
                    self.detail.set_tooltip_text(name)
                return GLib.SOURCE_REMOVE
            import threading
            threading.Thread(target=load, daemon=True).start()

    def dismiss(self):
        self.timeout = 0
        self.window.hide()
        return GLib.SOURCE_REMOVE


class DesktopControls:
    def __init__(self):
        self.panels = {}
        self.osd = OSD()
        provider = Gtk.CssProvider()
        provider.load_from_path(str(SCRIPTS / 'desktop-controls.css'))
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.node = Gio.DBusNodeInfo.new_for_xml(f'''<node><interface name="{BUS}">
          <method name="Toggle"><arg type="s" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
          <method name="OSD"><arg type="s" direction="in"/><arg type="d" direction="in"/><arg type="b" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
        </interface></node>''')
        self.bus.register_object(OBJECT, self.node.interfaces[0], self.call, None, None)
        self.owner = Gio.bus_own_name_on_connection(self.bus, BUS, Gio.BusNameOwnerFlags.NONE, None, None)

    def call(self, _b, _s, _p, _i, method, args, invocation):
        values = args.unpack()
        if method == 'Toggle' and values[0] in ('audio', 'focus'):
            key, x, y = values
            for name, panel in self.panels.items():
                if name != key:
                    panel.dismiss()
            if key not in self.panels:
                self.panels[key] = SoundPopup() if key == 'audio' else FocusPopup()
            self.panels[key].toggle(x, y)
        elif method == 'OSD' and values[0] in ('volume', 'mic', 'brightness'):
            self.osd.show(*values)
            if 'audio' in self.panels:
                self.panels['audio'].refresh()
        else:
            invocation.return_dbus_error(BUS + '.InvalidAction', 'Unknown desktop control')
            return
        invocation.return_value(None)

    def dismiss(self):
        for panel in self.panels.values():
            panel.dismiss()
        self.osd.dismiss()


def main():
    if sys.argv[1:] == ['--serve']:
        serve(DesktopControls, 'desktop-controls')
        return
    subprocess.run(['systemctl', '--user', 'start', 'desktop-controls.service'], check=True, timeout=5)
    cursor = json.loads(subprocess.check_output(['hyprctl', 'cursorpos', '-j']))
    x, y = cursor['x'], cursor['y']
    action = sys.argv[1] if len(sys.argv) > 1 else 'audio'
    if action == 'osd':
        method, args = 'OSD', GLib.Variant('(sdbii)', (sys.argv[2], float(sys.argv[3]), len(sys.argv) > 4 and sys.argv[4] == 'muted', x, y))
    else:
        monitors = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j']))
        monitor = next((m for m in monitors if m['focused']), monitors[0])
        if y > monitor['y'] + 48:
            x, y = int(monitor['x'] + monitor['width'] / monitor['scale'] / 2), monitor['y'] + 24
        method, args = 'Toggle', GLib.Variant('(sii)', (action, x, y))
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus.call_sync(BUS, OBJECT, BUS, method, args, None, Gio.DBusCallFlags.NONE, 5000, None)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, GLib.Error, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
