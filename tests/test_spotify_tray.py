"""Run with NO_AT_BRIDGE=1 python3 -m unittest discover -s tests.

Exercise GTK callbacks against MPRIS fixtures; never control the live player.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "spotify_tray", Path(__file__).resolve().parents[1] / "scripts/spotify-tray.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
GLib = module.GLib


class Player:
    def __init__(self):
        self.owner = ":1.test"
        self.values = {
            "PlaybackStatus": GLib.Variant("s", "Playing"),
            "Shuffle": GLib.Variant("b", False),
            "LoopStatus": GLib.Variant("s", "None"),
            "Volume": GLib.Variant("d", 0.5),
            "CanControl": GLib.Variant("b", True),
            "CanPlay": GLib.Variant("b", True),
            "CanPause": GLib.Variant("b", True),
            "CanGoNext": GLib.Variant("b", True),
            "CanGoPrevious": GLib.Variant("b", True),
            "CanSeek": GLib.Variant("b", True),
            "Metadata": GLib.Variant("a{sv}", {
                "mpris:trackid": GLib.Variant("o", "/track/one"),
                "mpris:length": GLib.Variant("t", 180_000_000),
                "xesam:title": GLib.Variant("s", "A <title> & music"),
                "xesam:artist": GLib.Variant("as", ["Artist"]),
                "xesam:album": GLib.Variant("s", "Album"),
                "xesam:url": GLib.Variant("s", "https://open.spotify.com/track/one"),
            }),
        }

    def get_name_owner(self):
        return self.owner

    def get_cached_property(self, name):
        return self.values.get(name)

    def connect(self, *_args):
        pass


class SpotifyControlsTest(unittest.TestCase):
    def setUp(self):
        self.player = Player()
        self.bus = Mock()
        for replacement in (
            patch.object(module.Gio, "bus_get_sync", return_value=self.bus),
            patch.object(module.Gio.DBusProxy, "new_sync", return_value=self.player),
            patch.object(module, "StatusNotifier"),
            patch.object(module.SpotifyTray, "load_art"),
            patch.object(module.GLib, "timeout_add_seconds"),
        ):
            replacement.start()
            self.addCleanup(replacement.stop)
        self.tray = module.SpotifyTray()
        self.addCleanup(self.tray.window.destroy)

    def sent(self):
        args = self.bus.call.call_args.args
        return args[0], args[2], args[3], args[4].unpack() if args[4] else None

    def test_button_actions_target_only_spotify(self):
        for button, method in ((self.tray.play, "PlayPause"),
                               (self.tray.previous, "Previous"),
                               (self.tray.next, "Next")):
            button.clicked()
            self.assertEqual(self.sent(), (module.MPRIS_NAME, module.PLAYER_IFACE, method, None))
        self.tray.quit.clicked()
        self.assertEqual(self.sent(), (module.MPRIS_NAME, "org.mpris.MediaPlayer2", "Quit", None))

    def test_track_state_and_capabilities(self):
        self.assertEqual(self.tray.title.get_text(), "A <title> & music")
        self.assertEqual(self.tray.total.get_text(), "3:00")
        self.assertEqual(self.tray.play.get_tooltip_text(), "Pause")
        self.player.values["CanGoNext"] = GLib.Variant("b", False)
        self.player.values["CanSeek"] = GLib.Variant("b", False)
        self.player.values["PlaybackStatus"] = GLib.Variant("s", "Paused")
        self.tray.refresh()
        self.assertFalse(self.tray.next.get_sensitive())
        self.assertFalse(self.tray.progress.get_sensitive())
        self.assertTrue(self.tray.previous.get_sensitive())
        self.assertEqual(self.tray.play.get_tooltip_text(), "Play")

    def test_exit_resets_metadata_and_disables_controls(self):
        self.player.owner = None
        self.tray.refresh()
        self.assertEqual(self.tray.status.get_text(), "Ready")
        self.assertEqual(self.tray.metadata, {})
        for button in (self.tray.next, self.tray.previous, self.tray.shuffle,
                       self.tray.repeat, self.tray.copy, self.tray.quit,
                       self.tray.volume, self.tray.progress):
            self.assertFalse(button.get_sensitive())
        self.assertTrue(self.tray.play.get_sensitive())
        with patch.object(module.subprocess, "Popen") as spawn:
            self.tray.play.clicked()
            command = spawn.call_args.args[0]
            self.assertEqual(command[0], "systemd-run")
            self.assertEqual(command[-1], str(module.SCRIPT_DIR / "music-open.sh"))

    def test_shuffle_repeat_and_volume(self):
        self.tray.shuffle.clicked()
        self.assertEqual(self.sent()[2:], ("Set", (module.PLAYER_IFACE, "Shuffle", True)))
        for current, expected in (("None", "Playlist"), ("Playlist", "Track"), ("Track", "None")):
            self.player.values["LoopStatus"] = GLib.Variant("s", current)
            self.tray.repeat.clicked()
            self.assertEqual(self.sent()[3], (module.PLAYER_IFACE, "LoopStatus", expected))
        for volume, expected in ((-1, 0.0), (0.7, 0.7), (2, 1.0)):
            self.tray.set_volume(volume)
            self.assertEqual(self.sent()[3], (module.PLAYER_IFACE, "Volume", expected))

    def test_seek_uses_track_id_and_ignores_track_changes(self):
        self.tray.seek(45, "/track/one")
        self.assertEqual(self.sent()[2:], ("SetPosition", ("/track/one", 45_000_000)))
        self.tray.seek_start()
        self.tray.metadata["mpris:trackid"] = "/track/two"
        self.bus.reset_mock()
        self.tray.seek_end()
        self.bus.call.assert_not_called()
        self.tray.seek(1000, "/track/two")
        self.assertEqual(self.sent()[3], ("/track/two", 180_000_000))

    def test_position_does_not_fight_dragging_or_poll_hidden_popup(self):
        self.tray.show_position(65_000_000)
        self.assertEqual(self.tray.elapsed.get_text(), "1:05")
        self.tray.seeking = True
        self.tray.show_position(80_000_000)
        self.assertEqual(self.tray.progress.get_value(), 65)
        self.bus.reset_mock()
        self.tray.tick()
        self.bus.call.assert_not_called()
        self.tray.seeking = False
        self.bus.call_finish.return_value = GLib.Variant("(v)", (GLib.Variant("x", 90_000_000),))
        self.tray.position_ready(self.bus, None, "/track/old")
        self.assertEqual(self.tray.progress.get_value(), 65)

    def test_no_writes_from_metadata_refresh(self):
        self.bus.reset_mock()
        self.tray.refresh()
        self.bus.call.assert_not_called()

    def test_tray_click_and_scroll_dispatch(self):
        # Use the original implementation without registering another tray icon.
        invocation = Mock()
        controller = Mock()
        controller.prop.return_value = 0.5
        notifier = SimpleNamespace(controller=controller)
        method = ORIGINAL_STATUS_NOTIFIER.method_call
        for action in ("Activate", "ContextMenu"):
            method(notifier, None, None, None, None, action, GLib.Variant("(ii)", (10, 20)), invocation)
            controller.toggle_popup.assert_called_with(10, 20)
        method(notifier, None, None, None, None, "SecondaryActivate", GLib.Variant("(ii)", (10, 20)), invocation)
        controller.play_pause.assert_called_once()
        method(notifier, None, None, None, None, "Scroll", GLib.Variant("(is)", (-1, "vertical")), invocation)
        controller.set_volume.assert_called_with(0.55)


ORIGINAL_STATUS_NOTIFIER = module.StatusNotifier

if __name__ == "__main__":
    unittest.main()
