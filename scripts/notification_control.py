#!/usr/bin/env python3
"""One notification interface for Waybar, Eww and focus sessions."""
import json
import os
import shutil
import subprocess
import sys
import time

FOCUS_ID = 'hypr-focus-timer'


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=4)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'Notification service is unavailable')
    return result.stdout.strip()


def backend():
    if shutil.which('swaync-client') and subprocess.run(
        ['pgrep', '-u', str(os.getuid()), '-x', 'swaync'], stdout=subprocess.DEVNULL,
    ).returncode == 0:
        return 'swaync'
    return 'mako'


def get_dnd():
    if backend() == 'swaync':
        return run('swaync-client', '--get-dnd', '--skip-wait').lower() == 'true'
    return 'do-not-disturb' in run('makoctl', 'mode').splitlines()


def set_dnd(value):
    if backend() == 'swaync':
        run('swaync-client', '--dnd-on' if value else '--dnd-off', '--skip-wait')
    else:
        run('makoctl', 'mode', '-a' if value else '-r', 'do-not-disturb')


def quiet_start():
    previous = {'backend': backend(), 'previous_dnd': get_dnd()}
    if previous['backend'] == 'swaync':
        # A separate inhibitor leaves the user's DND setting untouched.
        run('swaync-client', '--inhibitor-add', FOCUS_ID, '--skip-wait')
    else:
        set_dnd(True)
    return previous


def quiet_end(previous):
    if previous.get('backend') == 'swaync':
        run('swaync-client', '--inhibitor-remove', FOCUS_ID, '--skip-wait')
    else:
        set_dnd(bool(previous.get('previous_dnd')))


def quiet_renew(previous):
    if previous.get('backend') == 'swaync':
        # Idempotent; re-establish quiet after a notification daemon restart.
        run('swaync-client', '--inhibitor-add', FOCUS_ID, '--skip-wait')


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'toggle'
    if action == 'dnd':
        print('on' if get_dnd() else 'off')
    elif action in ('dnd-on', 'dnd-off', 'dnd-toggle'):
        set_dnd(not get_dnd() if action == 'dnd-toggle' else action == 'dnd-on')
    elif action == 'watch':
        while True:
            if backend() == 'swaync':
                with subprocess.Popen(['swaync-client', '--subscribe-waybar'], stdout=subprocess.PIPE, text=True) as stream:
                    for line in stream.stdout:
                        try:
                            data = json.loads(line)
                            count = int(data.get('text', 0))
                        except (ValueError, TypeError):
                            continue
                        alt = data.get('alt', '')
                        title = 'Do Not Disturb' if 'dnd' in alt else 'Notifications paused' if 'inhibited' in alt else 'Notifications'
                        data['tooltip'] = title + f'\n{count} waiting in the center\nClick: open · Right-click: Do Not Disturb'
                        print(json.dumps(data, ensure_ascii=False), flush=True)
                return
            dnd = get_dnd()
            print(json.dumps({'text': 0, 'alt': 'dnd-none' if dnd else 'none',
                              'tooltip': 'Do Not Disturb' if dnd else 'Notifications'}), flush=True)
            time.sleep(2)
    elif backend() == 'swaync':
        commands = {'toggle': '--toggle-panel', 'dismiss': '--hide-latest',
                    'clear': '--hide-all', 'history': '--open-panel'}
        run('swaync-client', commands[action], '--skip-wait')
    else:
        commands = {'toggle': ['restore'], 'history': ['restore'],
                    'dismiss': ['dismiss'], 'clear': ['dismiss', '-a']}
        run('makoctl', *commands[action])


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
