#!/usr/bin/env python3
"""Launch once, then show/hide the same Ghostty terminal or quick-note editor."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SCRIPTS = Path(__file__).resolve().parent
APPS = {'terminal': ('com.thbertoldi.QuickTerminal', 'Quick terminal'),
        'notes': ('com.thbertoldi.QuickNotes', 'Quick notes')}


def hypr(*args):
    result = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=3, check=True)
    return result.stdout


def dispatch(expression):
    result = hypr('dispatch', expression).strip()
    if result != 'ok':
        raise RuntimeError(result)


def find_window(appid):
    return next((w for w in json.loads(hypr('clients', '-j'))
                 if w.get('mapped') and w.get('class') == appid), None)


def toggle(kind):
    appid, title = APPS[kind]
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    with (runtime / f'hypr-scratch-{kind}.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        window = find_window(appid)
        workspace = json.loads(hypr('activeworkspace', '-j'))['id']
        if window:
            address = window['address']
            if window['workspace']['id'] == workspace:
                dispatch(f'hl.dsp.window.move({{window="address:{address}",workspace="special:quick-{kind}",follow=false}})')
            else:
                dispatch(f'hl.dsp.window.move({{window="address:{address}",workspace={workspace},follow=false}})')
                dispatch(f'hl.dsp.focus({{window="address:{address}"}})')
            return
        args = [str(SCRIPTS / 'app-launch.sh'), 'ghostty', '--class=' + appid,
                '--title=' + title, '--working-directory=' + str(Path.home())]
        if kind == 'notes':
            notes_dir = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'hypr-notes'
            notes_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
            notes = notes_dir / 'quick-notes.md'
            try:
                fd = os.open(notes, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(fd, 'w') as out:
                    out.write('# Quick notes\n\n')
            except FileExistsError:
                pass
            args += ['-e', 'hx', str(notes)]
        subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Keep the lock through startup so repeated shortcuts cannot spawn duplicates.
        for _ in range(100):
            if find_window(appid):
                return
            time.sleep(.1)
        raise RuntimeError('The scratchpad did not open')


if __name__ == '__main__':
    try:
        toggle(sys.argv[1])
    except (KeyError, IndexError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
