"""Exercise Wi-Fi selection and activation without changing the live network."""
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import network_backend as backend
from network_backend import GLib, NM, Network, NetworkManager, available_networks, connection_settings
from network_popup import NetworkPopup


def device():
    return Mock(get_path=Mock(return_value='/device/wifi'), get_iface=Mock(return_value='wlan-test'),
                get_state=Mock(return_value=NM.DeviceState.DISCONNECTED),
                get_active_connection=Mock(return_value=None),
                get_active_access_point=Mock(return_value=None),
                get_access_points=Mock(return_value=[]), get_last_scan=Mock(return_value=10),
                connection_valid=Mock(return_value=True))


def access_point(ssid=b'Cafe: Wi-Fi \\ Guest', path='/ap/one', strength=80, kind='wpa-psk'):
    flags = {'wpa-psk': backend.SEC_FLAGS.KEY_MGMT_PSK, 'sae': backend.SEC_FLAGS.KEY_MGMT_SAE,
             'enterprise': backend.SEC_FLAGS.KEY_MGMT_802_1X, 'owe': backend.SEC_FLAGS.KEY_MGMT_OWE,
             'open': backend.SEC_FLAGS.NONE}[kind]
    point = Mock(get_path=Mock(return_value=path), get_ssid=Mock(return_value=GLib.Bytes.new(ssid)),
                 get_strength=Mock(return_value=strength), get_wpa_flags=Mock(return_value=0),
                 get_rsn_flags=Mock(return_value=flags), get_flags=Mock(return_value=0),
                 get_frequency=Mock(return_value=5180))
    def valid(profile):
        wifi = profile.get_setting_wireless()
        secure = profile.get_setting_wireless_security()
        return (bytes(wifi.get_ssid().get_data()) == ssid
                and (secure.get_key_mgmt() if secure else 'open') == kind)
    point.connection_valid.side_effect = valid
    return point


def profile(ssid, kind='wpa-psk'):
    network = Network(device(), ssid, kind, kind)
    result = connection_settings(network, 'fixture passphrase' if kind in ('wpa-psk', 'sae') else None)
    result.get_setting_connection().props.id = 'A renamed saved profile'
    return result


class NetworkSelectionTests(unittest.TestCase):
    def test_exact_ssid_and_renamed_saved_profile_are_retained(self):
        adapter = device()
        name = '  Café: Wi-Fi \\ Guest  '.encode()
        saved = profile(name)
        ap = access_point(name)
        adapter.get_access_points.return_value = [ap]
        entries = available_networks(adapter, [saved])
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0].ssid, name)
        self.assertEqual(entries[0].name, name.decode())
        self.assertIs(entries[0].profile, saved)

    def test_duplicate_radios_keep_active_ap_and_security_stays_distinct(self):
        adapter = device()
        active = access_point(path='/ap/active', strength=30)
        strong = access_point(path='/ap/strong', strength=95)
        open_ap = access_point(path='/ap/open', kind='open')
        adapter.get_active_access_point.return_value = active
        adapter.get_state.return_value = NM.DeviceState.ACTIVATED
        adapter.get_access_points.return_value = [strong, open_ap, active]
        entries = available_networks(adapter, [])
        self.assertEqual(len(entries), 2)
        self.assertIs(entries[0].ap, active)
        self.assertTrue(entries[0].active)
        self.assertEqual(entries[1].kind, 'open')

    def test_hidden_saved_network_remains_connectable(self):
        saved = profile(b'Hidden: office')
        saved.get_setting_wireless().props.hidden = True
        entry, = available_networks(device(), [saved])
        self.assertIsNone(entry.ap)
        self.assertIs(entry.profile, saved)

    def test_invalid_utf8_and_controls_change_only_the_display(self):
        name = b'Wi-Fi\xff\nGuest'
        adapter = device()
        adapter.get_access_points.return_value = [access_point(name)]
        entry, = available_networks(adapter, [])
        self.assertEqual(entry.ssid, name)
        self.assertNotIn('\n', entry.name)

    def test_new_profile_preserves_ssid_and_uses_private_networkmanager_settings(self):
        name = b' Wi-Fi: \\ Example '
        setting = connection_settings(Network(device(), name, 'wpa-psk', 'WPA2'), 'fixture passphrase')
        self.assertTrue(setting.verify())
        self.assertEqual(bytes(setting.get_setting_wireless().get_ssid().get_data()), name)
        self.assertEqual(setting.get_setting_connection().get_num_permissions(), 1)
        self.assertEqual(setting.get_setting_wireless_security().get_psk(), 'fixture passphrase')
        setting.clear_secrets()
        self.assertIsNone(setting.get_setting_wireless_security().get_psk())

    def test_open_and_enhanced_open_do_not_request_a_password(self):
        for kind in ('open', 'owe'):
            setting = connection_settings(Network(device(), b'Guest', kind, kind))
            self.assertTrue(setting.verify())
            secure = setting.get_setting_wireless_security()
            self.assertIsNone(secure.get_psk() if secure else None)

    def test_wpa3_and_invalid_wpa2_passwords(self):
        setting = connection_settings(Network(device(), b'WPA3', 'sae', 'WPA3'), 'short')
        self.assertEqual(setting.get_setting_wireless_security().get_key_mgmt(), 'sae')
        with self.assertRaises(ValueError):
            connection_settings(Network(device(), b'WPA2', 'wpa-psk', 'WPA2'), 'short')


class ActivationTests(unittest.TestCase):
    def setUp(self):
        self.client = Mock()
        self.manager = NetworkManager(self.client)
        self.adapter = device()
        self.saved = profile(b'Target network')
        self.network = Network(self.adapter, b'Target network', 'wpa-psk', 'WPA2',
                               access_point(b'Target network'), self.saved)
        self.notify = Mock()
        for target, kwargs in [('timeout_add_seconds', {'return_value': 42}), ('source_remove', {})]:
            replacement = patch.object(GLib, target, **kwargs)
            replacement.start()
            self.addCleanup(replacement.stop)

    def begin(self):
        self.manager.connect_network(self.network, notify=self.notify)
        args = self.client.activate_connection_async.call_args.args
        self.assertIs(args[0], self.saved)
        self.assertIs(args[1], self.adapter)
        self.assertEqual(args[2], '/ap/one')
        active = Mock(get_state=Mock(return_value=NM.ActiveConnectionState.ACTIVATING),
                      get_state_reason=Mock(return_value=NM.ActiveConnectionStateReason.NONE),
                      connect=Mock(return_value=7))
        self.client.activate_connection_finish.return_value = active
        args[4](self.client, Mock())
        return active

    def test_saved_profile_uses_object_and_waits_for_actual_activation(self):
        active = self.begin()
        self.assertTrue(self.manager.busy)
        self.notify.assert_called_once_with('connecting', None)
        self.manager.state_changed(active, NM.ActiveConnectionState.ACTIVATED, NM.ActiveConnectionStateReason.NONE)
        self.assertFalse(self.manager.busy)
        self.notify.assert_called_with('connected', None)
        self.client.add_and_activate_connection_async.assert_not_called()

    def test_auth_failure_is_reported_and_allows_retry(self):
        active = self.begin()
        self.manager.state_changed(active, NM.ActiveConnectionState.DEACTIVATED, NM.ActiveConnectionStateReason.NO_SECRETS)
        self.assertFalse(self.manager.busy)
        self.assertEqual(self.notify.call_args.args[0], 'failed')
        self.assertIn('password', self.notify.call_args.args[1])
        self.manager.connect_network(self.network, notify=self.notify)
        self.assertEqual(self.client.activate_connection_async.call_count, 2)

    def test_clicking_current_network_never_disconnects_or_reconnects(self):
        self.adapter.get_active_connection.return_value = Mock(
            get_state=Mock(return_value=NM.ActiveConnectionState.ACTIVATED),
            get_connection=Mock(return_value=self.saved))
        self.manager.connect_network(self.network, notify=self.notify)
        self.notify.assert_called_once_with('connected', None)
        self.client.activate_connection_async.assert_not_called()
        self.client.deactivate_connection_async.assert_not_called()

    def test_repeated_click_does_not_start_parallel_attempts(self):
        self.begin()
        self.manager.connect_network(self.network, notify=Mock())
        self.assertEqual(self.client.activate_connection_async.call_count, 1)

    def test_stale_state_signal_cannot_complete_a_different_attempt(self):
        self.begin()
        self.manager.state_changed(Mock(), NM.ActiveConnectionState.ACTIVATED, NM.ActiveConnectionStateReason.NONE)
        self.assertTrue(self.manager.busy)

    def test_new_password_is_sent_as_settings_and_cleared_after_start(self):
        self.network.profile = None
        self.manager.connect_network(self.network, 'fixture passphrase', self.notify)
        args = self.client.add_and_activate_connection_async.call_args.args
        settings = args[0]
        self.assertEqual(settings.get_setting_wireless_security().get_psk(), 'fixture passphrase')
        active = Mock(get_state=Mock(return_value=NM.ActiveConnectionState.ACTIVATING),
                      get_state_reason=Mock(return_value=NM.ActiveConnectionStateReason.NONE))
        self.client.add_and_activate_connection_finish.return_value = active
        args[4](self.client, Mock())
        self.assertIsNone(settings.get_setting_wireless_security().get_psk())
        self.assertIs(self.network.profile, active.get_connection.return_value)

    def test_password_retry_updates_the_same_profile_before_activation(self):
        remote = Mock()
        self.network.profile = remote
        settings = profile(b'Target network')
        saved_uuid = settings.get_uuid()
        with patch.object(backend, 'connection_settings', return_value=settings):
            self.manager.connect_network(self.network, 'replacement passphrase', self.notify)
        args = remote.update2.call_args.args
        self.assertEqual(args[0].unpack()['connection']['uuid'], saved_uuid)
        self.client.activate_connection_async.assert_not_called()
        args[4](remote, Mock())
        self.assertIs(self.client.activate_connection_async.call_args.args[0], remote)
        self.client.add_and_activate_connection_async.assert_not_called()
        self.assertIsNone(settings.get_setting_wireless_security().get_psk())

    def test_rejected_activation_reports_error_and_clears_busy_state(self):
        self.manager.connect_network(self.network, notify=self.notify)
        self.client.activate_connection_finish.side_effect = GLib.Error('not authorized')
        self.client.activate_connection_async.call_args.args[4](self.client, Mock())
        self.assertFalse(self.manager.busy)
        self.assertEqual(self.notify.call_args.args[0], 'failed')


class NetworkPopupTests(unittest.TestCase):
    def setUp(self):
        self.adapter = device()
        self.manager = Mock(busy=False, devices=Mock(return_value=[self.adapter]))
        self.manager.client.get_connections.return_value = []
        self.manager.client.get_nm_running.return_value = True
        self.manager.client.wireless_get_enabled.return_value = True
        self.manager.client.wireless_hardware_get_enabled.return_value = True
        self.popup = NetworkPopup(self.manager)
        self.addCleanup(self.popup.window.destroy)

    def test_refreshing_radio_never_changes_live_wifi(self):
        self.popup.refresh()
        self.manager.client.wireless_get_enabled.return_value = False
        self.popup.refresh()
        self.manager.set_enabled.assert_not_called()
        self.manager.connect_network.assert_not_called()

    def test_password_cancel_and_popup_close_never_connect(self):
        network = Network(self.adapter, b'Example network', 'wpa-psk', 'WPA2')
        self.popup.choose(network)
        self.assertTrue(self.popup.auth.get_visible())
        self.popup.password.set_text('fixture passphrase')
        self.popup.clear_password()
        self.assertFalse(self.popup.auth.get_visible())
        self.popup.choose(network)
        self.popup.password.set_text('fixture passphrase')
        self.popup.dismiss()
        self.assertEqual(self.popup.password.get_text(), '')
        self.manager.connect_network.assert_not_called()

    def test_connected_row_is_not_a_disconnect_toggle(self):
        self.popup.choose(Network(self.adapter, b'Example', 'wpa-psk', 'WPA2', active=True))
        self.manager.connect_network.assert_not_called()

    def test_open_network_skips_password_prompt(self):
        network = Network(self.adapter, b'Guest: network', 'open', 'Open network')
        self.popup.choose(network)
        self.manager.connect_network.assert_called_once_with(network, None, self.popup.connection_changed)
        self.assertFalse(self.popup.auth.get_visible())

    def test_scan_is_nonblocking_and_repeated_requests_are_throttled(self):
        self.popup.scan()
        self.popup.scan()
        self.assertEqual(self.manager.scan.call_count, 1)
        self.manager.connect_network.assert_not_called()

    def test_enterprise_setup_is_explicit_and_does_not_guess_credentials(self):
        self.popup.choose(Network(self.adapter, b'Company', 'enterprise', 'Enterprise'))
        self.assertTrue(self.popup.error.get_visible())
        self.assertIn('Advanced settings', self.popup.error.get_text())
        self.manager.connect_network.assert_not_called()
