"""Asynchronous Wi-Fi actions using exact SSID bytes and saved profile objects.

Credentials travel through libnm/D-Bus, never command arguments or repo files.
"""
from dataclasses import dataclass
import getpass
import re
import uuid

import gi

gi.require_version('NM', '1.0')
from gi.repository import GLib, NM

AP_FLAGS = getattr(NM, '80211ApFlags')
SEC_FLAGS = getattr(NM, '80211ApSecurityFlags')


def ssid_bytes(ap):
    value = ap.get_ssid()
    return bytes(value.get_data()) if value else b''


def display_ssid(value):
    return ''.join(char if char.isprintable() else '\ufffd'
                   for char in value.decode('utf-8', errors='replace'))


def security(ap):
    flags = ap.get_wpa_flags() | ap.get_rsn_flags()
    if flags & (SEC_FLAGS.KEY_MGMT_802_1X | SEC_FLAGS.KEY_MGMT_EAP_SUITE_B_192):
        return 'enterprise', 'Enterprise'
    if flags & SEC_FLAGS.KEY_MGMT_PSK:
        return 'wpa-psk', 'WPA2 / WPA3' if flags & SEC_FLAGS.KEY_MGMT_SAE else 'WPA / WPA2'
    if flags & SEC_FLAGS.KEY_MGMT_SAE:
        return 'sae', 'WPA3'
    if flags & (SEC_FLAGS.KEY_MGMT_OWE | SEC_FLAGS.KEY_MGMT_OWE_TM):
        return 'owe', 'Enhanced open'
    if ap.get_flags() & AP_FLAGS.PRIVACY:
        return 'wep', 'WEP'
    return 'open', 'Open network'


@dataclass
class Network:
    device: object
    ssid: bytes
    kind: str
    security: str
    ap: object = None
    profile: object = None
    active: bool = False
    strength: int = 0

    @property
    def name(self):
        return display_ssid(self.ssid)

    @property
    def key(self):
        return self.device.get_path(), self.ssid, self.kind


def available_networks(device, profiles):
    """Group duplicate radios; prefer the active AP and compatible saved profile."""
    active = device.get_active_access_point()
    active_path = active.get_path() if active else None
    current = device.get_active_connection()
    current_uuid = current.get_uuid() if current else None
    compatible = [p for p in profiles if p.get_setting_wireless() and device.connection_valid(p)]
    compatible.sort(key=lambda p: (p.get_uuid() != current_uuid,
                                   -p.get_setting_connection().get_timestamp()))
    groups = {}
    for ap in device.get_access_points():
        ssid = ssid_bytes(ap)
        if not ssid:
            continue
        kind, description = security(ap)
        item = Network(device, ssid, kind, description, ap,
                       next((p for p in compatible if ap.connection_valid(p)), None),
                       ap.get_path() == active_path and device.get_state() == NM.DeviceState.ACTIVATED,
                       ap.get_strength())
        previous = groups.get(item.key)
        if previous is None or (item.active, item.strength) > (previous.active, previous.strength):
            groups[item.key] = item
    # Saved hidden networks can be activated even without a broadcast AP.
    for profile in compatible:
        wifi = profile.get_setting_wireless()
        if not wifi.get_hidden() or not wifi.get_ssid():
            continue
        ssid = bytes(wifi.get_ssid().get_data())
        if any(item.ssid == ssid for item in groups.values()):
            continue
        secure = profile.get_setting_wireless_security()
        kind = secure.get_key_mgmt() if secure else 'open'
        item = Network(device, ssid, kind, 'Hidden network', profile=profile)
        groups[item.key] = item
    return sorted(groups.values(), key=lambda n: (not n.active, n.profile is None, -n.strength, n.name.casefold()))


def validate_password(kind, password):
    if kind == 'wpa-psk' and not (8 <= len(password.encode('utf-8')) <= 63
                                 or re.fullmatch(r'[0-9a-fA-F]{64}', password)):
        raise ValueError('Use 8–63 bytes, or a 64-digit hexadecimal Wi-Fi key.')
    if kind == 'sae' and not password:
        raise ValueError('Enter the password for this network.')


def connection_settings(network, password=None):
    if network.profile:
        result = NM.SimpleConnection.new_clone(network.profile)
    else:
        result = NM.SimpleConnection.new()
        connection = NM.SettingConnection.new()
        connection.props.id = network.name
        connection.props.uuid = str(uuid.uuid4())
        connection.props.type = '802-11-wireless'
        connection.add_permission('user', getpass.getuser(), None)
        result.add_setting(connection)
        wifi = NM.SettingWireless.new()
        wifi.props.ssid = GLib.Bytes.new(network.ssid)
        wifi.props.mode = 'infrastructure'
        result.add_setting(wifi)
        for cls in (NM.SettingIP4Config, NM.SettingIP6Config):
            setting = cls.new()
            setting.props.method = 'auto'
            result.add_setting(setting)
    if network.kind in ('wpa-psk', 'sae', 'owe'):
        secure = result.get_setting_wireless_security()
        if secure is None:
            secure = NM.SettingWirelessSecurity.new()
            secure.props.key_mgmt = network.kind
            result.add_setting(secure)
        if network.kind != 'owe':
            validate_password(secure.get_key_mgmt(), password or '')
            secure.props.psk = password
            secure.props.psk_flags = NM.SettingSecretFlags.NONE
    elif network.kind != 'open':
        raise ValueError('Set up this network in Advanced settings, then select it here.')
    result.normalize()
    result.verify()
    return result


def failure_message(reason):
    if reason in (NM.ActiveConnectionStateReason.NO_SECRETS, NM.ActiveConnectionStateReason.LOGIN_FAILED):
        return 'Authentication failed. Check the Wi-Fi password and try again.'
    if reason in (NM.ActiveConnectionStateReason.CONNECT_TIMEOUT, NM.ActiveConnectionStateReason.SERVICE_START_TIMEOUT):
        return 'The connection timed out. Check the signal and try again.'
    if reason == NM.ActiveConnectionStateReason.IP_CONFIG_INVALID:
        return 'The network did not assign an IP address. Try again or check the router.'
    return 'Could not connect. Check the password and signal, then try again.'


class NetworkManager:
    def __init__(self, client=None):
        self.client = client if client is not None else NM.Client.new(None)
        self.busy = False
        self.active = None
        self.handler = None
        self.watchdog = 0
        self.notify = lambda *_: None

    def devices(self):
        return [device for device in self.client.get_devices() if isinstance(device, NM.DeviceWifi)]

    def scan(self, device, done):
        def complete(source, result, *_):
            try:
                source.request_scan_finish(result)
                done(None)
            except GLib.Error:
                done('Scan is temporarily unavailable. Try again in a few seconds.')
        device.request_scan_async(None, complete, None)

    def set_enabled(self, enabled, done):
        def complete(client, result, *_):
            try:
                client.dbus_set_property_finish(result)
                done(None)
            except GLib.Error:
                done('Could not change Wi-Fi. Check airplane mode or your permissions.')
        self.client.dbus_set_property('/org/freedesktop/NetworkManager',
            'org.freedesktop.NetworkManager', 'WirelessEnabled', GLib.Variant('b', enabled),
            10000, None, complete, None)

    def connect_network(self, network, password=None, notify=None):
        if self.busy:
            return
        self.notify = notify or (lambda *_: None)
        current = network.device.get_active_connection()
        if current and current.get_state() == NM.ActiveConnectionState.ACTIVATED:
            current_profile = current.get_connection()
            wifi = current_profile.get_setting_wireless() if current_profile else None
            if wifi and wifi.get_ssid() and bytes(wifi.get_ssid().get_data()) == network.ssid:
                if network.ap is None or network.ap.connection_valid(current_profile):
                    self.notify('connected', None)
                    return
        settings = None
        if network.profile is None or password is not None:
            settings = connection_settings(network, password)
        self.busy = True
        self.notify('connecting', None)
        path = network.ap.get_path() if network.ap else None

        def started(client, result, *_):
            try:
                self.active = (client.activate_connection_finish(result) if network.profile else
                               client.add_and_activate_connection_finish(result))
                if network.profile is None:
                    network.profile = self.active.get_connection()
                self.handler = self.active.connect('state-changed', self.state_changed)
                self.watchdog = GLib.timeout_add_seconds(100, self.timed_out)
                self.state_changed(self.active, self.active.get_state(), self.active.get_state_reason())
            except GLib.Error:
                self.finish('failed', 'Could not start the connection. Check permissions or try Advanced settings.')
            finally:
                if settings is not None:
                    settings.clear_secrets()

        def activate():
            self.client.activate_connection_async(network.profile, network.device, path, None, started, None)

        def updated(profile, result, *_):
            try:
                profile.update2_finish(result)
                activate()
            except GLib.Error:
                self.finish('failed', 'Could not save the new password. Check this profile in Advanced settings.')
            finally:
                settings.clear_secrets()

        if network.profile and settings is not None:
            network.profile.update2(settings.to_dbus(NM.ConnectionSerializationFlags.ALL),
                NM.SettingsUpdate2Flags.TO_DISK, None, None, updated, None)
        elif network.profile:
            activate()
        else:
            self.client.add_and_activate_connection_async(settings, network.device, path, None, started, None)

    def state_changed(self, active, state, reason):
        if not self.busy or active != self.active:
            return
        if state == NM.ActiveConnectionState.ACTIVATED:
            self.finish('connected', None)
        elif state == NM.ActiveConnectionState.DEACTIVATED:
            self.finish('failed', failure_message(reason))

    def timed_out(self):
        self.watchdog = 0
        # End only our attempt, never a connection selected elsewhere.
        if self.active and self.active.get_state() == NM.ActiveConnectionState.ACTIVATING:
            def complete(client, result, *_):
                try:
                    client.deactivate_connection_finish(result)
                except GLib.Error:
                    pass
            self.client.deactivate_connection_async(self.active, None, complete, None)
        self.finish('failed', 'The connection timed out. Check the password and try again.')
        return GLib.SOURCE_REMOVE

    def finish(self, state, message):
        if self.handler is not None:
            self.active.disconnect(self.handler)
            self.handler = None
        if self.watchdog:
            GLib.source_remove(self.watchdog)
            self.watchdog = 0
        self.active = None
        self.busy = False
        self.notify(state, message)
