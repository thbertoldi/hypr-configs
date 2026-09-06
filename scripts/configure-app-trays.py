#!/usr/bin/env python3
"""Replace native Steam/DankCalendar icons after installing the custom trays."""
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

home = Path.home()
state = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
backup = state / 'hypr-trays/backups' / dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f')


def save(path, name):
    backup.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, backup / name)
    else:
        (backup / (name + '.absent')).touch()


def flatpak_installed(appid):
    return shutil.which('flatpak') and subprocess.run(
        ['flatpak', 'info', appid], stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, timeout=5,
    ).returncode == 0


if flatpak_installed('com.valvesoftware.Steam'):
    overrides = home / '.local/share/flatpak/overrides/com.valvesoftware.Steam'
    current = overrides.read_text() if overrides.exists() else ''
    if 'org.kde.StatusNotifierWatcher=none' not in current.splitlines():
        save(overrides, 'steam-flatpak-override')
        subprocess.run(['flatpak', 'override', '--user',
                        '--no-talk-name=org.kde.StatusNotifierWatcher',
                        'com.valvesoftware.Steam'], check=True, timeout=5)
        print('Steam native tray disabled for its next launch.')

for path, installed in (
    (home / '.var/app/com.danklinux.dankcalendar/config/dankcal/ui-settings.json',
     flatpak_installed('com.danklinux.dankcalendar')),
    (home / '.config/dankcal/ui-settings.json', shutil.which('dcal')),
):
    if not installed and not path.parent.is_dir():
        continue
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError(f'Expected a settings object in {path}')
    if settings.get('showTrayIcon') is False:
        continue
    save(path, 'calendar-flatpak-settings.json' if '.var' in path.parts else 'calendar-native-settings.json')
    settings['showTrayIcon'] = False
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.tray-settings-', delete=False) as out:
        json.dump(settings, out, ensure_ascii=False, indent=2)
        out.write('\n')
        temporary = Path(out.name)
    os.chmod(temporary, path.stat().st_mode & 0o777 if path.exists() else 0o600)
    temporary.replace(path)
    print('DankCalendar native icon hidden; sync and reminders stay enabled.')

if backup.exists():
    print(f'Previous settings saved in {backup}')
