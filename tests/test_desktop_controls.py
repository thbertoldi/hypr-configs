"""Exercise state/routing/clipboard behavior without touching real audio or history."""
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import audio_backend as audio
import clipboard_picker as clipboard
import notification_control as notifications
from focus_timer import FocusTimer
from desktop_controls import VolumeRow, SoundPopup


class FocusTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.now = 1000
        self.begin = Mock(return_value={'backend': 'swaync', 'previous_dnd': True})
        self.end = Mock()
        self.timer = FocusTimer(directory.name, lambda: self.now, self.begin, self.end)

    def test_pause_resume_and_expiry_release_once(self):
        self.timer.start(25)
        self.now += 40
        self.timer.pause()
        self.now += 10000
        self.assertFalse(self.timer.tick())
        self.assertEqual(self.timer.status()['remaining'], 1460)
        self.timer.pause()
        self.now += 1460
        self.assertTrue(self.timer.tick())
        self.assertFalse(self.timer.tick())
        self.end.assert_called_once_with(self.begin.return_value)

    def test_restart_reuses_quiet_state_and_cancel_restores_it(self):
        self.timer.start(25)
        self.timer.start(50)
        self.begin.assert_called_once()
        self.assertEqual(self.timer.status()['remaining'], 3000)
        self.assertTrue(self.timer.stop())
        self.assertFalse(self.timer.stop())
        self.end.assert_called_once_with(self.begin.return_value)

    def test_reloaded_session_keeps_deadline(self):
        self.timer.start(25)
        self.now += 80
        reloaded = FocusTimer(self.timer.directory, lambda: self.now, self.begin, self.end)
        self.assertEqual(reloaded.status()['remaining'], 1420)
        reloaded.stop()
        self.assertFalse(self.timer.status()['active'])

    def test_failed_restoration_retains_state_for_retry(self):
        self.timer.start(25)
        self.end.side_effect = RuntimeError('temporarily unavailable')
        with self.assertRaises(RuntimeError):
            self.timer.stop()
        self.assertTrue(self.timer.status()['active'])

    def test_renewal_keeps_original_token_and_stops_after_cancel(self):
        self.timer.renewer = Mock()
        self.timer.start(25)
        self.timer.renew()
        self.timer.renewer.assert_called_once_with(self.begin.return_value)
        self.timer.stop()
        self.timer.renew()
        self.timer.renewer.assert_called_once()
        self.end.assert_called_once_with(self.begin.return_value)

    def test_swaync_focus_owns_only_its_inhibitor(self):
        with patch.object(notifications, 'backend', return_value='swaync'), \
             patch.object(notifications, 'get_dnd', return_value=True), \
             patch.object(notifications, 'run') as run, \
             patch.object(notifications, 'set_dnd') as set_dnd:
            token = notifications.quiet_start()
            notifications.quiet_end(token)
            self.assertEqual([call.args[1:3] for call in run.call_args_list], [
                ('--inhibitor-add', notifications.FOCUS_ID),
                ('--inhibitor-remove', notifications.FOCUS_ID)])
            set_dnd.assert_not_called()


class AudioTests(unittest.TestCase):
    def test_refreshing_slider_does_not_write_volume(self):
        owner = Mock()
        row = VolumeRow('Playback', 'sink', '@DEFAULT_SINK@', owner)
        self.addCleanup(row.destroy)
        row.update({'volume': 43, 'mute': False})
        row.update({'volume': 68, 'mute': True})
        self.assertEqual(row.scale.get_value(), 68)
        self.assertEqual(row.pending, 0)
        owner.change.assert_not_called()

    def test_programmatic_device_refresh_does_not_route(self):
        owner = Mock(updating=True)
        SoundPopup.select(owner, 'sink', '["device", "headphones"]')
        owner.change.assert_not_called()
        owner.updating = False
        SoundPopup.select(owner, 'sink', '["device", "headphones"]')
        owner.change.assert_called_once()

    def test_device_switch_routes_existing_streams(self):
        with patch.object(audio, 'pactl') as pactl, \
             patch.object(audio, 'listing', return_value=[{'index': 8}, {'index': 9}]):
            audio.choose('source', json.dumps(['microphone', 'front']))
        self.assertEqual([c.args for c in pactl.call_args_list], [
            ('set-source-port', 'microphone', 'front'), ('set-default-source', 'microphone'),
            ('move-source-output', 8, 'microphone'), ('move-source-output', 9, 'microphone')])

    def test_switch_survives_stream_disappearing(self):
        with patch.object(audio, 'pactl', side_effect=['', RuntimeError('gone'), '']) as pactl, \
             patch.object(audio, 'listing', return_value=[{'index': 8}, {'index': 9}]):
            audio.choose('sink', '["headphones", ""]')
        self.assertEqual(pactl.call_args.args, ('move-sink-input', 9, 'headphones'))


class ClipboardTests(unittest.TestCase):
    def test_preview_removes_metadata_controls(self):
        items = clipboard.entries('3\tHello\0icon\x1f/tmp/unsafe\nnot an entry\n2\tSecond')
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0][2], 'Helloicon/tmp/unsafe')
        self.assertIn('\0', items[0][0])  # Original decode key remains intact.

    def test_cancel_never_decodes_or_copies_text(self):
        with patch.object(clipboard.subprocess, 'check_output', return_value='9\tHello\n'), \
             patch.object(clipboard.subprocess, 'run', return_value=Mock(returncode=1, stdout=b'')) as run, \
             patch.object(clipboard, 'decode') as decode:
            clipboard.pick()
        decode.assert_not_called()
        self.assertEqual(len(run.call_args_list), 1)
        self.assertEqual(run.call_args.args[0][0], 'fuzzel')

    def test_copy_preserves_binary_and_mime(self):
        content = b'\x89PNG\r\n\x1a\n\x00\xff\n'
        copied = []
        def decode(_entry, target):
            target.write_bytes(content)
            return True
        def run(command, **kwargs):
            if command[0] == 'fuzzel':
                return Mock(returncode=0, stdout=b'0\n')
            copied.append((command, kwargs['stdin'].read()))
            return Mock(returncode=0)
        with patch.object(clipboard.subprocess, 'check_output', side_effect=['5\t[[ binary data 2 KiB png 80x80 ]]\n', 'image/png\n']), \
             patch.object(clipboard.subprocess, 'run', side_effect=run), \
             patch.object(clipboard, 'decode', side_effect=decode):
            clipboard.pick()
        self.assertEqual(copied, [(['wl-copy', '--type', 'image/png'], content)])


if __name__ == '__main__':
    unittest.main()
