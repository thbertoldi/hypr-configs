#!/usr/bin/env python3
"""Persistent focus countdown; releases only the notification pause it owns."""
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

from notification_control import quiet_start, quiet_end, quiet_renew


class FocusTimer:
    def __init__(self, directory=None, clock=time.time, begin=quiet_start, end=quiet_end, renew=quiet_renew):
        self.directory = Path(directory or Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'hypr-focus')
        self.path = self.directory / 'session.json'
        self.clock, self.begin, self.end = clock, begin, end
        self.renewer = renew

    def read(self):
        try:
            state = json.loads(self.path.read_text())
            return state if isinstance(state, dict) else {}
        except (OSError, ValueError):
            return {}

    @contextmanager
    def locked(self):
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (self.directory / 'session.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            yield self.read()

    def save(self, state):
        with tempfile.NamedTemporaryFile(mode='w', dir=self.directory, delete=False) as out:
            json.dump(state, out)
            temporary = Path(out.name)
        temporary.replace(self.path)

    def start(self, minutes):
        if not 1 <= minutes <= 180:
            raise ValueError('Choose a duration between 1 and 180 minutes')
        with self.locked() as state:
            quiet = state.get('quiet') if state.get('active') else self.begin()
            self.save({'active': True, 'minutes': minutes, 'deadline': self.clock() + minutes * 60,
                       'paused': False, 'quiet': quiet})

    def pause(self):
        with self.locked() as state:
            if state.get('active'):
                if state.get('paused'):
                    state['deadline'] = self.clock() + state['remaining']
                    state['paused'] = False
                else:
                    state['remaining'] = max(0, state['deadline'] - self.clock())
                    state['paused'] = True
                self.save(state)

    def stop(self):
        with self.locked() as state:
            if not state.get('active'):
                return False
            self.end(state['quiet'])
            self.save({'active': False})
            return True

    def status(self):
        state = self.read()
        active = bool(state.get('active'))
        paused = bool(state.get('paused'))
        left = math.ceil(max(0, state.get('remaining', 0) if paused else state.get('deadline', 0) - self.clock())) if active else 0
        return {**state, 'active': active, 'paused': paused, 'remaining': left,
                'display': f'{left // 60:02}:{left % 60:02}',
                'fraction': min(1, left / (max(1, state.get('minutes', 25)) * 60))}

    def tick(self):
        # Check and expire under one lock: a simultaneous restart must survive.
        with self.locked() as state:
            if not state.get('active') or state.get('paused') or state['deadline'] > self.clock():
                return False
            self.end(state['quiet'])
            self.save({'active': False})
            return True

    def renew(self):
        # Hold the same lock as cancellation so renewal cannot leave a stale inhibitor.
        with self.locked() as state:
            if state.get('active'):
                self.renewer(state['quiet'])


def bar_status(timer):
    state = timer.status()
    if not state['active']:
        return {'text': '󰥔', 'class': 'idle', 'tooltip': 'Focus session\nClick: choose 25 or 50 minutes'}
    return {'text': ('󰏤 ' if state['paused'] else '󰥔 ') + state['display'],
            'class': 'paused' if state['paused'] else 'active',
            'tooltip': ('Paused' if state['paused'] else 'Focus in progress') +
                       '\nNotifications paused · Click for controls\nRight-click to finish'}


def main():
    timer = FocusTimer()
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'start':
        subprocess.run(['systemctl', '--user', 'start', 'focus-timer.service'], check=True, timeout=5)
        timer.start(int(sys.argv[2]))
    elif action == 'pause':
        timer.pause()
    elif action == 'stop':
        timer.stop()
    elif action == 'status':
        print(json.dumps(timer.status()))
    elif action == 'watch':
        previous = None
        while True:
            payload = json.dumps(bar_status(timer), ensure_ascii=False)
            if payload != previous:
                print(payload, flush=True)
                previous = payload
            time.sleep(1)
    elif action == 'run':
        running = True
        def finish(*_):
            nonlocal running
            running = False
        signal.signal(signal.SIGTERM, finish)
        signal.signal(signal.SIGINT, finish)
        renewed = 0
        while running:
            try:
                if timer.tick():
                    subprocess.run(['notify-send', '-a', 'Focus', '-i', 'appointment-soon',
                                    'Focus session complete', 'Take a breath. Your notifications are back to normal.'], timeout=3)
                if time.monotonic() - renewed >= 15:
                    timer.renew()
                    renewed = time.monotonic()
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                print(error, file=sys.stderr, flush=True)
            time.sleep(1)
        timer.stop()
    else:
        raise ValueError('Usage: focus_timer.py start MINUTES | pause | stop | status | watch | run')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
