#!/usr/bin/env python3
"""Spotify StatusNotifier icon with a native Wayland player popup."""

from __future__ import annotations

import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time
from urllib.request import urlopen

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, GtkLayerShell, Pango

SCRIPT_DIR = Path(__file__).resolve().parent
SPOTIFY_ID = "com.spotify.Client"
MPRIS_NAME = "org.mpris.MediaPlayer2.spotify"
MPRIS_PATH = "/org/mpris/MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PROPERTIES_IFACE = "org.freedesktop.DBus.Properties"
TRAY_NAME = "org.kde.StatusNotifierItem.hypr_spotify"
TRAY_PATH = "/StatusNotifierItem"
TRAY_IFACE = "org.kde.StatusNotifierItem"
WATCHER = "org.kde.StatusNotifierWatcher"


def clean(value: str, fallback: str = "") -> str:
    return " ".join(value.replace("\x00", "").split()) or fallback


def timestamp(seconds: float) -> str:
    seconds = max(0, int(seconds))
    return f"{seconds // 60}:{seconds % 60:02d}"


def style(widget: Gtk.Widget, name: str) -> Gtk.Widget:
    widget.get_style_context().add_class(name)
    return widget


def describe(widget: Gtk.Widget, text: str) -> None:
    widget.set_tooltip_text(text)
    widget.get_accessible().set_name(text)


class StatusNotifier:
    """Export Activate directly: AppIndicator can only show a text menu."""

    def __init__(self, bus: Gio.DBusConnection, controller: SpotifyTray) -> None:
        self.bus = bus
        self.controller = controller
        self.properties = {
            "Category": GLib.Variant("s", "ApplicationStatus"),
            "Id": GLib.Variant("s", "hypr-spotify-tray"),
            "Title": GLib.Variant("s", "Spotify"),
            "Status": GLib.Variant("s", "Active"),
            "WindowId": GLib.Variant("u", 0),
            "IconName": GLib.Variant("s", SPOTIFY_ID),
            "IconPixmap": GLib.Variant("a(iiay)", []),
            "OverlayIconName": GLib.Variant("s", ""),
            "OverlayIconPixmap": GLib.Variant("a(iiay)", []),
            "AttentionIconName": GLib.Variant("s", ""),
            "AttentionIconPixmap": GLib.Variant("a(iiay)", []),
            "AttentionMovieName": GLib.Variant("s", ""),
            "ItemIsMenu": GLib.Variant("b", False),
            "ToolTip": GLib.Variant("(sa(iiay)ss)", (SPOTIFY_ID, [], "Spotify", "Open player")),
        }
        properties = "".join(
            f'<property name="{name}" type="{value.get_type_string()}" access="read"/>'
            for name, value in self.properties.items()
        )
        methods = "".join(
            f'<method name="{name}"><arg type="i" direction="in"/>'
            '<arg type="i" direction="in"/></method>'
            for name in ("Activate", "SecondaryActivate", "ContextMenu")
        )
        self.node = Gio.DBusNodeInfo.new_for_xml(
            f'<node><interface name="{TRAY_IFACE}">{properties}{methods}'
            '<method name="Scroll"><arg type="i" direction="in"/>'
            '<arg type="s" direction="in"/></method>'
            '<signal name="NewToolTip"/></interface></node>'
        )
        self.registration = bus.register_object(
            TRAY_PATH, self.node.interfaces[0], self.method_call,
            lambda _bus, _sender, _path, _iface, name: self.properties[name], None,
        )
        self.owner = Gio.bus_own_name_on_connection(
            bus, TRAY_NAME, Gio.BusNameOwnerFlags.NONE, None, None,
        )
        # Re-register automatically when Waybar (and its watcher) restarts.
        self.watch = Gio.bus_watch_name_on_connection(
            bus, WATCHER, Gio.BusNameWatcherFlags.NONE, self.register, None,
        )

    def register(self, _bus, _name, _owner) -> None:
        self.bus.call(
            WATCHER, "/StatusNotifierWatcher", WATCHER, "RegisterStatusNotifierItem",
            GLib.Variant("(s)", (TRAY_PATH,)), None, Gio.DBusCallFlags.NONE,
            3000, None, self.registered,
        )

    @staticmethod
    def registered(bus, result) -> None:
        try:
            bus.call_finish(result)
        except GLib.Error as error:
            print(f"spotify-tray: registration failed: {error.message}", file=sys.stderr)

    def method_call(self, _bus, _sender, _path, _iface, method, args, invocation) -> None:
        if method in ("Activate", "ContextMenu"):
            self.controller.toggle_popup(*args.unpack())
        elif method == "SecondaryActivate":
            self.controller.play_pause()
        elif method == "Scroll":
            delta, orientation = args.unpack()
            if orientation == "vertical" and delta:
                volume = self.controller.prop("Volume", 1.0)
                self.controller.set_volume(volume + (-0.05 if delta > 0 else 0.05))
        else:
            invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)
            return
        invocation.return_value(None)

    def tooltip(self, title: str, description: str) -> None:
        value = GLib.Variant(
            "(sa(iiay)ss)", (SPOTIFY_ID, [], GLib.markup_escape_text(title), description),
        )
        if value == self.properties["ToolTip"]:
            return
        self.properties["ToolTip"] = value
        self.bus.emit_signal(None, TRAY_PATH, TRAY_IFACE, "NewToolTip", None)
        self.bus.emit_signal(
            None, TRAY_PATH, PROPERTIES_IFACE, "PropertiesChanged",
            GLib.Variant("(sa{sv}as)", (TRAY_IFACE, {"ToolTip": value}, [])),
        )


class SpotifyTray:
    def __init__(self) -> None:
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.player = Gio.DBusProxy.new_sync(
            self.bus, Gio.DBusProxyFlags.DO_NOT_AUTO_START, None,
            MPRIS_NAME, MPRIS_PATH, PLAYER_IFACE, None,
        )
        self.art_url = ""
        self.metadata = {}
        self.updating = False
        self.seeking = False
        self.seek_track = ""
        self.position_pending = False
        self.available = False
        self.playing = False
        self.duration = 0.0
        self.build_popup()
        self.notifier = StatusNotifier(self.bus, self)
        self.player.connect("g-properties-changed", lambda *_: self.refresh())
        self.player.connect("notify::g-name-owner", lambda *_: self.refresh())
        self.player.connect("g-signal", self.player_signal)
        GLib.timeout_add_seconds(1, self.tick)
        self.refresh()

    def prop(self, name: str, fallback=None):
        value = self.player.get_cached_property(name)
        return value.unpack() if value is not None else fallback

    @staticmethod
    def label(text: str, css: str, *, ellipsize: bool = False) -> Gtk.Label:
        label = Gtk.Label(label=text, xalign=0)
        style(label, css)
        if ellipsize:
            label.set_ellipsize(Pango.EllipsizeMode.END)
            label.set_max_width_chars(23)
        return label

    @staticmethod
    def button(icon: str, tooltip: str, callback, css: str = "control") -> Gtk.Button:
        button = Gtk.Button()
        button.set_image(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR))
        describe(button, tooltip)
        button.connect("clicked", lambda *_: callback())
        style(button, css)
        return button

    def build_popup(self) -> None:
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_name("spotify-popup")
        self.window.set_title("Spotify controls")
        self.window.set_decorated(False)
        visual = self.window.get_screen().get_rgba_visual()
        if visual:
            self.window.set_visual(visual)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "spotify-controls")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                     GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self.window, edge, True)
        # A transparent input surface dismisses the card on an outside click.
        self.window.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.window.connect("button-press-event", self.outside_click)
        self.window.connect("key-press-event", self.key_press)
        self.window.connect("delete-event", lambda *_: self.dismiss())
        self.layout = Gtk.Fixed()
        self.window.add(self.layout)
        self.card = style(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14), "player-card")
        self.card.set_size_request(368, -1)
        self.layout.put(self.card, 12, 48)

        header = Gtk.Box(spacing=8)
        header.pack_start(Gtk.Image.new_from_icon_name(SPOTIFY_ID, Gtk.IconSize.MENU), False, False, 0)
        header.pack_start(self.label("SPOTIFY", "eyebrow"), False, False, 0)
        self.status = self.label("Ready", "status")
        self.status.set_halign(Gtk.Align.END)
        header.pack_start(self.status, True, True, 0)
        header.pack_start(self.button("window-close-symbolic", "Close controls · Esc", self.dismiss, "dismiss"), False, False, 0)
        self.card.pack_start(header, False, False, 0)

        track = Gtk.Box(spacing=16)
        self.cover = Gtk.Image.new_from_icon_name("audio-x-generic-symbolic", Gtk.IconSize.DIALOG)
        self.cover.set_pixel_size(48)
        self.cover.set_size_request(96, 96)
        style(self.cover, "cover")
        track.pack_start(self.cover, False, False, 0)
        details = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        details.set_valign(Gtk.Align.CENTER)
        self.title = self.label("Your music, one click away", "track-title", ellipsize=True)
        self.artist = self.label("Open Spotify to get started", "artist", ellipsize=True)
        self.album = self.label("", "album", ellipsize=True)
        for label in (self.title, self.artist, self.album):
            details.pack_start(label, False, False, 0)
        track.pack_start(details, True, True, 0)
        self.card.pack_start(track, False, False, 0)

        timeline = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.progress = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1)
        self.progress.set_draw_value(False)
        self.progress.get_accessible().set_name("Track position")
        self.progress.connect("button-press-event", self.seek_start)
        self.progress.connect("button-release-event", self.seek_end)
        self.progress.connect("change-value", self.seek_change)
        timeline.pack_start(self.progress, False, False, 0)
        times = Gtk.Box()
        self.elapsed = self.label("0:00", "time")
        self.total = self.label("0:00", "time")
        times.pack_start(self.elapsed, True, True, 0)
        times.pack_end(self.total, False, False, 0)
        timeline.pack_start(times, False, False, 0)
        self.card.pack_start(timeline, False, False, 0)

        controls = Gtk.Box(spacing=12, halign=Gtk.Align.CENTER)
        self.shuffle = self.button("media-playlist-shuffle-symbolic", "Shuffle: Off", self.toggle_shuffle)
        self.previous = self.button("media-skip-backward-symbolic", "Previous track", lambda: self.call("Previous"))
        self.play = self.button("media-playback-start-symbolic", "Play", self.play_pause, "play")
        self.next = self.button("media-skip-forward-symbolic", "Next track", lambda: self.call("Next"))
        self.repeat = self.button("media-playlist-repeat-symbolic", "Repeat: Off", self.cycle_repeat)
        for button in (self.shuffle, self.previous, self.play, self.next, self.repeat):
            controls.pack_start(button, False, False, 0)
        self.card.pack_start(controls, False, False, 0)

        volume = Gtk.Box(spacing=10)
        volume.pack_start(Gtk.Image.new_from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.MENU), False, False, 0)
        self.volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.volume.set_draw_value(False)
        self.volume.get_accessible().set_name("Spotify volume")
        self.volume.connect("change-value", self.volume_change)
        volume.pack_start(self.volume, True, True, 0)
        self.volume_label = self.label("100%", "time")
        self.volume_label.set_width_chars(4)
        self.volume_label.set_xalign(1)
        volume.pack_start(self.volume_label, False, False, 0)
        self.card.pack_start(volume, False, False, 0)
        self.card.pack_start(Gtk.Separator(), False, False, 0)

        footer = Gtk.Box(spacing=6)
        self.open = Gtk.Button(label="Open Spotify")
        style(self.open, "open")
        self.open.set_tooltip_text("Show Spotify · Super+M")
        self.open.connect("clicked", lambda *_: self.open_spotify())
        footer.pack_start(self.open, True, True, 0)
        self.hide = self.button("window-minimize-symbolic", "Hide Spotify · keep playing", self.hide_spotify, "utility")
        self.copy = self.button("edit-copy-symbolic", "Copy track link", self.copy_track, "utility")
        self.quit = self.button("application-exit-symbolic", "Quit Spotify", self.quit_spotify, "utility")
        for button in (self.hide, self.copy, self.quit):
            footer.pack_start(button, False, False, 0)
        self.card.pack_start(footer, False, False, 0)

        provider = Gtk.CssProvider()
        provider.load_from_path(str(SCRIPT_DIR / "spotify-tray.css"))
        Gtk.StyleContext.add_provider_for_screen(self.window.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def toggle_popup(self, x: int, y: int) -> None:
        if self.window.get_visible():
            self.dismiss()
            return
        display = Gdk.Display.get_default()
        monitor = display.get_monitor_at_point(x, y) or display.get_primary_monitor() or display.get_monitor(0)
        GtkLayerShell.set_monitor(self.window, monitor)
        geometry = monitor.get_geometry()
        self.card.show_all()
        width = self.card.get_preferred_width().natural_width
        height = self.card.get_preferred_height().natural_height
        self.card_x = max(12, min(x - geometry.x - width // 2, geometry.width - width - 12))
        self.card_y = max(12, min(y - geometry.y + 24, geometry.height - height - 12))
        self.layout.move(self.card, self.card_x, self.card_y)
        self.window.show_all()
        self.play.grab_focus()
        self.refresh()
        self.tick()

    def dismiss(self) -> bool:
        self.window.hide()
        self.seeking = False
        return True

    def outside_click(self, _widget, event) -> bool:
        if not (self.card_x <= event.x < self.card_x + self.card.get_allocated_width()
                and self.card_y <= event.y < self.card_y + self.card.get_allocated_height()):
            return self.dismiss()
        return False

    def key_press(self, _widget, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            return self.dismiss()
        return False

    def refresh(self) -> None:
        self.available = bool(self.player.get_name_owner())
        self.playing = self.available and self.prop("PlaybackStatus") == "Playing"
        self.metadata = self.prop("Metadata", {}) if self.available else {}
        title = clean(self.metadata.get("xesam:title", ""), "Spotify" if self.available else "Your music, one click away")
        artist = clean(", ".join(self.metadata.get("xesam:artist", [])))
        album = clean(self.metadata.get("xesam:album", ""))
        self.title.set_text(title)
        self.title.set_tooltip_text(title)
        self.artist.set_text(artist or ("Choose something to play" if self.available else "Open Spotify to get started"))
        self.artist.set_tooltip_text(artist)
        self.album.set_text(album)
        self.album.set_tooltip_text(album)
        state = "Playing" if self.playing else "Paused" if self.available else "Ready"
        self.status.set_text(state)
        context = self.status.get_style_context()
        (context.add_class if self.playing else context.remove_class)("playing")
        icon = "media-playback-pause-symbolic" if self.playing else "media-playback-start-symbolic"
        self.play.set_image(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR))
        describe(self.play, "Pause" if self.playing else "Play")
        shuffle = self.available and self.prop("Shuffle", False)
        repeat = self.prop("LoopStatus", "None") if self.available else "None"
        describe(self.shuffle, f"Shuffle: {'On' if shuffle else 'Off'}")
        describe(self.repeat, "Repeat: " + {"None": "Off", "Playlist": "Playlist", "Track": "Track"}.get(repeat, "Off"))
        icon = "media-playlist-repeat-song-symbolic" if repeat == "Track" else "media-playlist-repeat-symbolic"
        self.repeat.set_image(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR))
        for button, active in ((self.shuffle, shuffle), (self.repeat, repeat != "None")):
            context = button.get_style_context()
            (context.add_class if active else context.remove_class)("enabled")
        control = self.available and self.prop("CanControl", True)
        for button, enabled in (
            (self.play, not self.available or control and self.prop("CanPause" if self.playing else "CanPlay", True)),
            (self.previous, control and self.prop("CanGoPrevious", False)),
            (self.next, control and self.prop("CanGoNext", False)),
            (self.shuffle, control), (self.repeat, control), (self.volume, control),
            (self.hide, self.available), (self.quit, self.available),
            (self.copy, bool(self.metadata.get("xesam:url"))),
        ):
            button.set_sensitive(enabled)
        self.duration = self.metadata.get("mpris:length", 0) / 1_000_000
        self.progress.set_sensitive(control and self.prop("CanSeek", False) and self.duration > 0)
        self.updating = True
        self.progress.set_range(0, max(1, self.duration))
        self.total.set_text(timestamp(self.duration))
        volume = max(0, min(100, self.prop("Volume", 1.0) * 100)) if self.available else 0
        self.volume.set_value(volume)
        self.volume_label.set_text(f"{round(volume)}%")
        self.updating = False
        if not self.available:
            self.show_position(0)
        self.notifier.tooltip(title if self.available else "Spotify", f"{artist}\n{state}\nClick: player · Middle-click: play/pause\nScroll: volume".strip())
        self.load_art(self.metadata.get("mpris:artUrl", ""))

    def load_art(self, url: str) -> None:
        if url == self.art_url:
            return
        self.art_url = url
        self.cover.set_from_icon_name("audio-x-generic-symbolic", Gtk.IconSize.DIALOG)
        self.cover.set_pixel_size(48)
        if not url.startswith("https://"):
            return

        def fetch() -> None:
            try:
                with urlopen(url, timeout=5) as response:
                    data = response.read(2 * 1024 * 1024 + 1)
                if len(data) > 2 * 1024 * 1024:
                    return
                stream = Gio.MemoryInputStream.new_from_bytes(GLib.Bytes.new(data))
                pixbuf = GdkPixbuf.Pixbuf.new_from_stream_at_scale(stream, 96, 96, True, None)
                GLib.idle_add(self.art_ready, url, pixbuf)
            except (OSError, GLib.Error, ValueError):
                pass  # Offline playback retains a styled placeholder.

        threading.Thread(target=fetch, daemon=True).start()

    def art_ready(self, url: str, pixbuf: GdkPixbuf.Pixbuf) -> bool:
        if url == self.art_url:
            self.cover.set_from_pixbuf(pixbuf)
        return GLib.SOURCE_REMOVE

    def call(self, method: str, args=None, interface: str = PLAYER_IFACE) -> None:
        if not self.available:
            return
        self.bus.call(MPRIS_NAME, MPRIS_PATH, interface, method, args, None,
                      Gio.DBusCallFlags.NO_AUTO_START, 3000, None, self.action_finished)

    @staticmethod
    def action_finished(bus, result) -> None:
        try:
            bus.call_finish(result)
        except GLib.Error as error:
            print(f"spotify-tray: {error.message}", file=sys.stderr)

    def set_property(self, name: str, value: GLib.Variant) -> None:
        self.call("Set", GLib.Variant("(ssv)", (PLAYER_IFACE, name, value)), PROPERTIES_IFACE)

    def play_pause(self) -> None:
        if self.available:
            self.call("PlayPause")
        else:
            self.open_spotify()

    def toggle_shuffle(self) -> None:
        self.set_property("Shuffle", GLib.Variant("b", not self.prop("Shuffle", False)))

    def cycle_repeat(self) -> None:
        mode = {"None": "Playlist", "Playlist": "Track", "Track": "None"}.get(self.prop("LoopStatus"), "None")
        self.set_property("LoopStatus", GLib.Variant("s", mode))

    def set_volume(self, volume: float) -> None:
        self.set_property("Volume", GLib.Variant("d", max(0.0, min(1.0, volume))))

    def volume_change(self, _scale, _scroll, value) -> bool:
        if not self.updating:
            self.set_volume(value / 100)
        return False

    def seek_start(self, *_args) -> bool:
        self.seeking = True
        self.seek_track = self.metadata.get("mpris:trackid", "")
        return False

    def seek_end(self, *_args) -> bool:
        if self.seeking:
            self.seeking = False
            self.seek(self.progress.get_value(), self.seek_track)
        return False

    def seek_change(self, _scale, _scroll, value) -> bool:
        if not self.updating and not self.seeking:
            self.seek(value, self.metadata.get("mpris:trackid", ""))
        return False

    def seek(self, seconds: float, track: str) -> None:
        # SetPosition identifies the track, so a drag cannot seek a new song.
        if track.startswith("/") and track == self.metadata.get("mpris:trackid"):
            position = int(max(0, min(self.duration, seconds)) * 1_000_000)
            self.call("SetPosition", GLib.Variant("(ox)", (track, position)))

    def show_position(self, microseconds: int) -> None:
        if self.seeking:
            return
        seconds = max(0, min(self.duration, microseconds / 1_000_000))
        self.updating = True
        self.progress.set_value(seconds)
        self.elapsed.set_text(timestamp(seconds))
        self.updating = False

    def player_signal(self, _proxy, _sender, signal_name, args) -> None:
        if signal_name == "Seeked":
            self.show_position(args.unpack()[0])

    def tick(self) -> bool:
        if self.available and self.window.get_visible() and not self.position_pending:
            self.position_pending = True
            track = self.metadata.get("mpris:trackid")
            self.bus.call(
                MPRIS_NAME, MPRIS_PATH, PROPERTIES_IFACE, "Get",
                GLib.Variant("(ss)", (PLAYER_IFACE, "Position")), GLib.VariantType.new("(v)"),
                Gio.DBusCallFlags.NO_AUTO_START, 2000, None, self.position_ready, track,
            )
        return GLib.SOURCE_CONTINUE

    def position_ready(self, bus, result, track) -> None:
        self.position_pending = False
        try:
            value = bus.call_finish(result).unpack()[0]
            if track == self.metadata.get("mpris:trackid"):
                self.show_position(value)
        except GLib.Error:
            pass

    def open_spotify(self) -> None:
        self.dismiss()
        # Keep Spotify outside the tray's service cgroup when the tray restarts.
        subprocess.Popen(
            ["systemd-run", "--user", "--collect", "--quiet",
             f"--unit=hypr-spotify-open-{os.getpid()}-{time.monotonic_ns()}",
             str(SCRIPT_DIR / "music-open.sh")],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

    def hide_spotify(self) -> None:
        self.dismiss()
        subprocess.Popen([str(SCRIPT_DIR / "music-open.sh"), "--hide"], stdout=subprocess.DEVNULL)

    def copy_track(self) -> None:
        link = self.metadata.get("xesam:url", "")
        if link.startswith("spotify:"):
            parts = link.split(":")
            if len(parts) == 3:
                link = f"https://open.spotify.com/{parts[1]}/{parts[2]}"
        if link:
            Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(link, -1)
            self.copy.set_tooltip_text("Track link copied")

    def quit_spotify(self) -> None:
        self.call("Quit", interface="org.mpris.MediaPlayer2")
        self.dismiss()


def main() -> int:
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/runtime-{os.getuid()}"))
    runtime_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_file = (runtime_dir / "hypr-spotify-tray.lock").open("w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())
    controller = SpotifyTray()
    Gtk.main()
    controller.dismiss()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
