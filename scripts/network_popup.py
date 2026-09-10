"""A native Wi-Fi picker shared by the bar and dashboard."""
import time

from network_backend import GLib, NM, NetworkManager, available_networks, display_ssid
from tray_popup import Gtk, GtkLayerShell, Popup, SCRIPTS, button, clear, css, label


class NetworkPopup(Popup):
    def __init__(self, manager=None):
        super().__init__('network', 'Network', 'network-wireless-symbolic', tray=False, poll_interval=2)
        self.manager = manager if manager is not None else NetworkManager()
        self.device = None
        self.updating = False
        self.radio_pending = False
        self.scanning_until = 0
        self.scan_stamp = -1
        self.last_scan_request = 0
        self.selected = None
        self.networks = []
        self.signature = None
        self.card.set_size_request(430, -1)
        heading = Gtk.Box(spacing=12)
        heading.pack_start(label('Choose a network', 'heading'), True, True, 0)
        self.radio = Gtk.Switch()
        self.radio.set_valign(Gtk.Align.CENTER)
        self.radio.get_accessible().set_name('Wi-Fi enabled')
        self.radio.connect('state-set', self.radio_changed)
        heading.pack_start(self.radio, False, False, 0)
        self.body.pack_start(heading, False, False, 0)
        self.adapters = Gtk.ComboBoxText()
        self.adapters.get_accessible().set_name('Wi-Fi adapter')
        self.adapters.connect('changed', self.adapter_changed)
        self.adapters.set_no_show_all(True)
        self.body.pack_start(self.adapters, False, False, 0)
        self.summary = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5), 'network-summary')
        self.connection_name = label('', 'title', True)
        self.connection_detail = label('', 'muted')
        self.summary.pack_start(self.connection_name, False, False, 0)
        self.summary.pack_start(self.connection_detail, False, False, 0)
        self.body.pack_start(self.summary, False, False, 0)
        self.auth = css(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8), 'network-auth')
        self.auth.set_no_show_all(True)
        self.auth_title = label('', 'body', True)
        self.auth.pack_start(self.auth_title, False, False, 0)
        entry_row = Gtk.Box(spacing=6)
        self.password = Gtk.Entry()
        self.password.set_visibility(False)
        self.password.set_placeholder_text('Wi-Fi password')
        self.password.get_accessible().set_name('Wi-Fi password')
        self.password.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        self.password.connect('activate', lambda *_: self.submit_password())
        entry_row.pack_start(self.password, True, True, 0)
        self.reveal = button('', self.reveal_password, icon='view-reveal-symbolic', tooltip='Show or hide password')
        entry_row.pack_start(self.reveal, False, False, 0)
        self.auth.pack_start(entry_row, False, False, 0)
        actions = Gtk.Box(spacing=6)
        self.join = button('Connect', self.submit_password, 'primary')
        actions.pack_start(self.join, True, True, 0)
        actions.pack_start(button('Cancel', self.clear_password), False, False, 0)
        self.auth.pack_start(actions, False, False, 0)
        self.body.pack_start(self.auth, False, False, 0)
        self.search = Gtk.SearchEntry()
        self.search.set_placeholder_text('Find a network…')
        self.search.get_accessible().set_name('Find a network')
        self.search.connect('search-changed', lambda *_: self.render_networks())
        self.body.pack_start(self.search, False, False, 0)
        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroll.set_min_content_height(150)
        self.scroll.set_max_content_height(280)
        self.scroll.set_propagate_natural_height(True)
        self.list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.scroll.add(self.list)
        self.body.pack_start(self.scroll, False, False, 0)
        footer = Gtk.Box(spacing=8)
        self.scan_button = button('Refresh', lambda: self.scan(True), icon='view-refresh-symbolic', tooltip='Scan for nearby networks')
        footer.pack_start(self.scan_button, True, True, 0)
        footer.pack_start(button('Advanced settings', self.open_app, 'small'), False, False, 0)
        self.body.pack_start(footer, False, False, 0)
        self.refresh()

    def toggle(self, x, y):
        opening = not self.window.get_visible()
        super().toggle(x, y)
        if opening:
            GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
            self.scan(False)

    def dismiss(self):
        self.clear_password()
        return super().dismiss()

    def show_error(self, text):
        self.error.set_text(text or '')
        self.error.set_visible(bool(text))
        self.position()

    def open_app(self):
        self.launch([str(SCRIPTS / 'app-launch.sh'), 'nm-connection-editor'])

    def radio_changed(self, _widget, enabled):
        if self.updating or self.radio_pending or self.manager.busy:
            return True
        self.radio_pending = True
        self.radio.set_sensitive(False)
        def done(error):
            self.radio_pending = False
            self.show_error(error)
            self.refresh()
            if enabled and not error:
                self.scan(False)
        self.manager.set_enabled(enabled, done)
        return True

    def adapter_changed(self, widget):
        if self.updating:
            return
        self.device = next((d for d in self.manager.devices() if d.get_path() == widget.get_active_id()), None)
        self.clear_password()
        self.refresh()
        self.scan(False)

    def clear_password(self):
        self.password.set_text('')
        self.password.set_visibility(False)
        self.auth.hide()
        if not self.manager.busy:
            self.selected = None
        self.position()

    def reveal_password(self):
        self.password.set_visibility(not self.password.get_visibility())

    def prompt_password(self, network):
        self.selected = network
        self.auth_title.set_text('Password for ' + network.name)
        self.password.set_text('')
        self.password.set_visibility(False)
        for child in self.auth.get_children():
            child.show_all()
        self.auth.show()
        self.password.grab_focus()
        self.position()

    def choose(self, network):
        if self.manager.busy:
            return
        self.show_error(None)
        if network.active:
            self.clear_password()
            return
        if network.profile is not None or network.kind in ('open', 'owe'):
            self.connect_network(network)
        elif network.kind in ('wpa-psk', 'sae'):
            self.prompt_password(network)
        else:
            self.show_error('Set up enterprise or legacy security in Advanced settings, then select the saved network here.')

    def submit_password(self):
        if self.selected is not None and not self.manager.busy:
            self.connect_network(self.selected, self.password.get_text())

    def connect_network(self, network, password=None):
        self.selected = network
        self.show_error(None)
        try:
            self.manager.connect_network(network, password, self.connection_changed)
        except ValueError as error:
            self.show_error(str(error))
            return
        except GLib.Error:
            self.show_error('These connection settings could not be applied. Check Advanced settings.')
            return
        self.password.set_text('')
        self.auth.hide()
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.ON_DEMAND)
        self.refresh()

    def connection_changed(self, state, error):
        self.show_error(error)
        if state == 'failed' and self.selected and self.selected.kind in ('wpa-psk', 'sae'):
            self.prompt_password(self.selected)
        if state != 'connecting':
            GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        self.refresh()

    def scan(self, explicit=False):
        if not self.device or self.manager.busy or not self.manager.client.wireless_get_enabled():
            return
        now = time.monotonic()
        if now < self.scanning_until or (not explicit and now - self.last_scan_request < 15):
            return
        self.scan_stamp = self.device.get_last_scan()
        self.scanning_until = now + 12
        self.last_scan_request = now
        def done(error):
            if error:
                self.scanning_until = 0
                if explicit:
                    self.show_error(error)
            self.refresh()
        self.manager.scan(self.device, done)
        self.refresh()

    def refresh(self):
        client = self.manager.client
        devices = self.manager.devices()
        if self.device not in devices:
            self.device = next((d for d in devices if d.get_state() == NM.DeviceState.ACTIVATED), devices[0] if devices else None)
        self.updating = True
        adapter_signature = [(d.get_path(), d.get_iface()) for d in devices]
        if getattr(self, 'adapter_signature', None) != adapter_signature:
            self.adapters.remove_all()
            for path, name in adapter_signature:
                self.adapters.append(path, name)
            self.adapter_signature = adapter_signature
        self.adapters.set_active_id(self.device.get_path() if self.device else None)
        self.adapters.set_visible(len(devices) > 1)
        self.adapters.set_sensitive(not self.manager.busy)
        enabled = client.wireless_get_enabled()
        blocked = not client.wireless_hardware_get_enabled()
        self.radio.set_state(enabled)
        self.radio.set_active(enabled)
        self.updating = False
        self.radio.set_sensitive(bool(devices) and not blocked and not self.manager.busy and not self.radio_pending)
        connected = next((d for d in devices if d.get_state() == NM.DeviceState.ACTIVATED), None)
        active_ap = connected.get_active_access_point() if connected else None
        if self.manager.busy and self.selected:
            self.connection_name.set_text('Connecting to ' + self.selected.name)
            self.connection_detail.set_text('Waiting for the network and an IP address…')
            self.badge.set_text('Connecting')
            if self.device and self.device.get_state() == NM.DeviceState.NEED_AUTH:
                self.dismiss()
        elif active_ap and active_ap.get_ssid():
            self.connection_name.set_text(display_ssid(bytes(active_ap.get_ssid().get_data())))
            band = '6 GHz' if active_ap.get_frequency() >= 5925 else '5 GHz' if active_ap.get_frequency() >= 4900 else '2.4 GHz'
            self.connection_detail.set_text(f'Connected · {band} · {active_ap.get_strength()}% signal')
            self.badge.set_text('Connected')
        else:
            self.connection_name.set_text('Wi-Fi is off' if not enabled else 'Not connected')
            self.connection_detail.set_text('Turn Wi-Fi on to see nearby networks.' if not enabled else 'Select a network below to connect.')
            self.badge.set_text('Off' if not enabled else 'Ready')
        if self.device and self.device.get_last_scan() != self.scan_stamp:
            self.scanning_until = 0
        scanning = time.monotonic() < self.scanning_until
        self.scan_button.set_label('Scanning…' if scanning else 'Refresh')
        self.scan_button.set_sensitive(bool(self.device) and enabled and not blocked and not scanning and not self.manager.busy)
        self.networks = available_networks(self.device, client.get_connections()) if self.device and enabled else []
        self.empty_text = ('NetworkManager is unavailable.' if not client.get_nm_running() else
                           'No Wi-Fi adapter found.' if not devices else
                           'Wi-Fi is blocked by airplane mode or a hardware switch.' if blocked else
                           'Turn on Wi-Fi to find networks.' if not enabled else
                           'No networks found. Refresh to scan again.')
        self.render_networks()
        self.position()

    def render_networks(self):
        term = self.search.get_text().casefold()
        visible = [item for item in self.networks if term in item.name.casefold()]
        signature = [(item.key, item.strength, item.active, item.profile is not None, self.manager.busy) for item in visible]
        signature.append((term, getattr(self, 'empty_text', 'Looking for networks…')))
        if signature == self.signature:
            return
        self.signature = signature
        self.scroll.set_min_content_height(min(280, max(80, 74 * len(visible))))
        focused_key = next((getattr(row, 'network_key', None) for row in self.list.get_children() if row.has_focus()), None)
        clear(self.list)
        for item in visible:
            row = css(Gtk.Button(), 'network-row', 'connected' if item.active else 'available')
            row.network_key = item.key
            content = Gtk.Box(spacing=12)
            strength = 'excellent' if item.strength >= 75 else 'good' if item.strength >= 50 else 'ok' if item.strength >= 25 else 'weak'
            content.pack_start(Gtk.Image.new_from_icon_name('network-wireless-signal-' + strength + '-symbolic', Gtk.IconSize.LARGE_TOOLBAR), False, False, 0)
            text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            text.pack_start(label(item.name, 'body', True), False, False, 0)
            details = ('Connected' if item.active else 'Saved' if item.profile else item.security)
            details += f' · {item.strength}%' if item.ap else ' · Hidden network'
            text.pack_start(label(details, 'muted'), False, False, 0)
            content.pack_start(text, True, True, 0)
            content.pack_start(label('✓' if item.active else 'Connect' if item.profile or item.kind in ('open', 'owe') else '›', 'network-action'), False, False, 0)
            row.add(content)
            row.get_accessible().set_name(item.name + ' · ' + details)
            row.set_tooltip_text('Already connected' if item.active else 'Connect to ' + item.name)
            row.set_sensitive(not self.manager.busy)
            row.connect('clicked', lambda _row, network=item: self.choose(network))
            self.list.pack_start(row, False, False, 0)
            if row.network_key == focused_key:
                row.grab_focus()
        if not visible:
            self.list.pack_start(label('No matching networks.' if term else self.empty_text, 'muted'), False, False, 0)
        self.list.show_all()
        self.position()
