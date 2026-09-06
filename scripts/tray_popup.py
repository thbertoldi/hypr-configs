"""GTK/StatusNotifier building blocks for the Steam and calendar popups."""
from __future__ import annotations

import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('GdkPixbuf', '2.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, GtkLayerShell, Pango

SCRIPTS = Path(__file__).resolve().parent
ITEM_IFACE = 'org.kde.StatusNotifierItem'
WATCHER = 'org.kde.StatusNotifierWatcher'


def css(widget, *classes):
    for name in classes:
        widget.get_style_context().add_class(name)
    return widget


def label(text='', style='body', truncate=False):
    widget = css(Gtk.Label(label=text, xalign=0), style)
    if truncate:
        widget.set_ellipsize(Pango.EllipsizeMode.END)
        widget.set_max_width_chars(28)
        widget.set_tooltip_text(text)
    return widget


def button(text, callback, style='control', icon=None, tooltip=None):
    widget = css(Gtk.Button(label=text or None), style)
    if icon:
        widget.set_image(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.MENU))
        widget.set_always_show_image(True)
    if tooltip:
        widget.set_tooltip_text(tooltip)
    widget.get_accessible().set_name(tooltip or text)
    widget.connect('clicked', lambda *_: callback())
    return widget


def picture(path, width, height):
    image = css(Gtk.Image(), 'artwork')
    image.set_size_request(width, height)
    if path:
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file(str(path))
            factor = max(width / pixbuf.get_width(), height / pixbuf.get_height())
            scaled = pixbuf.scale_simple(max(width, round(pixbuf.get_width() * factor)),
                                        max(height, round(pixbuf.get_height() * factor)),
                                        GdkPixbuf.InterpType.BILINEAR)
            image.set_from_pixbuf(scaled.new_subpixbuf((scaled.get_width() - width) // 2,
                                                      (scaled.get_height() - height) // 2, width, height))
            return image
        except GLib.Error:
            pass
    image.set_from_icon_name('applications-games-symbolic', Gtk.IconSize.DIALOG)
    return image


def clear(container):
    for child in container.get_children():
        child.destroy()


class StatusNotifier:
    def __init__(self, app, key, title, icon):
        self.app = app
        self.icon = icon
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.props = {
            'Category': GLib.Variant('s', 'ApplicationStatus'),
            'Id': GLib.Variant('s', f'hypr-{key}-tray'),
            'Title': GLib.Variant('s', title),
            'Status': GLib.Variant('s', 'Active'),
            'WindowId': GLib.Variant('u', 0),
            'IconName': GLib.Variant('s', icon),
            'IconPixmap': GLib.Variant('a(iiay)', []),
            'ItemIsMenu': GLib.Variant('b', False),
            'ToolTip': GLib.Variant('(sa(iiay)ss)', (icon, [], title, 'Click to open')),
        }
        props = ''.join(f'<property name="{k}" type="{v.get_type_string()}" access="read"/>' for k, v in self.props.items())
        methods = ''.join(f'<method name="{m}"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>' for m in ('Activate', 'ContextMenu', 'SecondaryActivate'))
        self.node = Gio.DBusNodeInfo.new_for_xml(f'<node><interface name="{ITEM_IFACE}">{props}{methods}<method name="Scroll"><arg type="i" direction="in"/><arg type="s" direction="in"/></method><signal name="NewToolTip"/></interface></node>')
        self.object_id = self.bus.register_object('/StatusNotifierItem', self.node.interfaces[0], self.call,
            lambda _b, _s, _p, _i, name: self.props[name], None)
        self.owner = Gio.bus_own_name_on_connection(self.bus, f'{ITEM_IFACE}.hypr_{key}', Gio.BusNameOwnerFlags.NONE, None, None)
        self.watch = Gio.bus_watch_name_on_connection(self.bus, WATCHER, Gio.BusNameWatcherFlags.NONE, self.register, None)

    def register(self, *_args):
        self.bus.call(WATCHER, '/StatusNotifierWatcher', WATCHER, 'RegisterStatusNotifierItem',
                      GLib.Variant('(s)', ('/StatusNotifierItem',)), None,
                      Gio.DBusCallFlags.NONE, 3000, None, self.finished)

    @staticmethod
    def finished(bus, result):
        try:
            bus.call_finish(result)
        except GLib.Error as error:
            print(f'tray: {error.message}', file=sys.stderr)

    def call(self, _b, _s, _p, _i, method, args, invocation):
        if method in ('Activate', 'ContextMenu'):
            self.app.toggle(*args.unpack())
        elif method == 'SecondaryActivate':
            self.app.open_app()
        elif method != 'Scroll':
            invocation.return_dbus_error('org.freedesktop.DBus.Error.UnknownMethod', method)
            return
        invocation.return_value(None)

    def tooltip(self, title, description):
        value = GLib.Variant('(sa(iiay)ss)', (self.icon, [], GLib.markup_escape_text(title), description))
        if value != self.props['ToolTip']:
            self.props['ToolTip'] = value
            self.bus.emit_signal(None, '/StatusNotifierItem', ITEM_IFACE, 'NewToolTip', None)


class Popup:
    def __init__(self, key, title, icon, *, tray=True, poll_interval=30):
        self.key = key
        self.busy = False
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_name('desktop-popup')
        self.window.set_title(title + ' controls')
        self.window.set_decorated(False)
        visual = self.window.get_screen().get_rgba_visual()
        if visual:
            self.window.set_visual(visual)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, f'{key}-controls')
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self.window, edge, True)
        self.window.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.window.connect('button-press-event', self.outside)
        self.window.connect('key-press-event', lambda _w, e: self.dismiss() if e.keyval == Gdk.KEY_Escape else False)
        self.window.connect('delete-event', lambda *_: self.dismiss())
        self.layout = Gtk.Fixed()
        self.window.add(self.layout)
        self.card = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14), 'popup-card', key)
        self.card.set_size_request(390, -1)
        self.layout.put(self.card, 12, 48)
        self.header = Gtk.Box(spacing=8)
        self.header.pack_start(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.MENU), False, False, 0)
        self.header.pack_start(label(title.upper(), 'eyebrow'), True, True, 0)
        self.badge = label('', 'badge')
        self.header.pack_start(self.badge, False, False, 0)
        self.close = button('', self.dismiss, 'dismiss', 'window-close-symbolic', 'Close popup · Esc')
        self.header.pack_start(self.close, False, False, 0)
        self.card.pack_start(self.header, False, False, 0)
        self.body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.card.pack_start(self.body, False, False, 0)
        self.error = label('', 'error')
        self.error.set_line_wrap(True)
        self.error.set_max_width_chars(40)
        self.card.pack_start(self.error, False, False, 0)
        self.error.set_no_show_all(True)
        self.notifier = StatusNotifier(self, key, title, icon) if tray else None
        provider = Gtk.CssProvider()
        provider.load_from_path(str(SCRIPTS / 'tray-popups.css'))
        Gtk.StyleContext.add_provider_for_screen(self.window.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        GLib.timeout_add_seconds(poll_interval, self.poll)

    def toggle(self, x, y):
        if self.window.get_visible():
            self.dismiss()
            return
        display = Gdk.Display.get_default()
        monitor = display.get_monitor_at_point(x, y) or display.get_monitor(0)
        GtkLayerShell.set_monitor(self.window, monitor)
        self.geometry = monitor.get_geometry()
        self.anchor = (x - self.geometry.x, y - self.geometry.y)
        self.card.show_all()
        self.position()
        self.window.show_all()
        self.close.grab_focus()
        self.refresh()

    def position(self):
        if not hasattr(self, 'anchor'):
            return
        width = self.card.get_preferred_width().natural_width
        height = self.card.get_preferred_height().natural_height
        self.x = max(12, min(self.anchor[0] - width // 2, self.geometry.width - width - 12))
        self.y = max(12, min(self.anchor[1] + 24, self.geometry.height - height - 12))
        self.layout.move(self.card, self.x, self.y)

    def outside(self, _w, event):
        if not (self.x <= event.x < self.x + self.card.get_allocated_width() and self.y <= event.y < self.y + self.card.get_allocated_height()):
            return self.dismiss()
        return False

    def dismiss(self):
        self.window.hide()
        return True

    def poll(self):
        if self.window.get_visible():
            self.refresh()
        return GLib.SOURCE_CONTINUE

    def work(self, task, done):
        if self.busy:
            return
        self.busy = True

        def fetch():
            try:
                result, error = task(), None
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
                result, error = None, str(exc)
            GLib.idle_add(finish, result, error)

        def finish(result, error):
            self.busy = False
            if error:
                self.error.set_text(error)
                self.error.show()
            else:
                self.error.hide()
                done(result)
            self.body.show_all()
            self.position()
            return GLib.SOURCE_REMOVE

        threading.Thread(target=fetch, daemon=True).start()

    def launch(self, argv):
        self.dismiss()
        subprocess.Popen(['systemd-run', '--user', '--collect', '--quiet',
                          f'--unit=hypr-{self.key}-action-{os.getpid()}-{time.monotonic_ns()}', *argv],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def serve(factory, key):
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/runtime-{os.getuid()}'))
    runtime.mkdir(mode=0o700, exist_ok=True, parents=True)
    lock = (runtime / f'hypr-{key}-tray.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())
    app = factory()
    Gtk.main()
    app.dismiss()
