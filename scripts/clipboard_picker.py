#!/usr/bin/env python3
"""Fuzzel clipboard picker with temporary image previews and exact-byte paste."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import re
import subprocess
import tempfile

IMAGE = re.compile(r'^\[\[ binary data .*?\b(png|jpe?g|gif|bmp|webp)\b', re.IGNORECASE)


def decode(entry, target):
    with target.open('wb') as out:
        result = subprocess.run(['cliphist', 'decode'], input=(entry + '\n').encode(),
                                stdout=out, stderr=subprocess.DEVNULL, timeout=5)
    return result.returncode == 0 and target.stat().st_size > 0


def entries(raw):
    result = []
    for line in raw.splitlines():
        identifier, sep, preview = line.partition('\t')
        if sep and identifier.isdecimal():
            # History text is data: strip dmenu's metadata delimiters from labels.
            clean = ''.join(c for c in preview if c >= ' ' and c != '\x7f')
            result.append((line, identifier, clean[:200] + ('…' if len(clean) > 200 else '')))
    return result


def pick():
    history = subprocess.check_output(['cliphist', 'list'], text=True, timeout=5)
    items = entries(history)
    base = ['fuzzel', '--dmenu', '--index', '--counter', '--no-sort', '--with-nth', '2', '--minimal-lines',
            '--namespace', 'hypr-clipboard',
            '--lines', '10', '--width', '60', '--font', 'Noto Sans:size=12', '--line-height', '48',
            '--border-radius', '18', '--selection-radius', '10', '--prompt', '󰅍  ',
            '--placeholder', 'Search clipboard…', '--only-match']
    if not items:
        subprocess.run(['fuzzel', '--dmenu', '--prompt-only', 'Clipboard is empty'], input=b'')
        return
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    with tempfile.TemporaryDirectory(prefix='hypr-clipboard-', dir=runtime) as directory:
        root = Path(directory)
        thumbnails = {}
        images = [(raw, identifier, preview) for raw, identifier, preview in items if IMAGE.match(preview)][:40]
        def thumbnail(item):
            raw, identifier, preview = item
            path = root / (identifier + '.' + IMAGE.match(preview)[1].lower())
            # Thumbnails are temporary; the persistent clipboard stays in Cliphist.
            try:
                return identifier, path if decode(raw, path) else None
            except (OSError, subprocess.SubprocessError):
                return identifier, None
        with ThreadPoolExecutor(max_workers=4) as pool:
            thumbnails.update(pool.map(thumbnail, images))
        lines = []
        for raw, identifier, preview in items:
            icon = str(thumbnails.get(identifier) or ('text-html' if preview.startswith(('https://', 'http://')) else 'text-x-generic'))
            if IMAGE.match(preview):
                preview = 'Image  ·  ' + re.sub(r'^\[\[ binary data\s+', '', preview).removesuffix(' ]]')
            lines.append(f'{identifier}\t{preview}\0icon\x1f{icon}')
        result = subprocess.run(base, input=('\n'.join(lines) + '\n').encode(), stdout=subprocess.PIPE)
        if result.returncode or not result.stdout.strip().isdigit():
            return
        index = int(result.stdout)
        if not 0 <= index < len(items):
            return
        selected = root / 'selected'
        if not decode(items[index][0], selected):
            return
        command = ['wl-copy']
        if IMAGE.match(items[index][2]):
            mime = subprocess.check_output(['file', '--brief', '--mime-type', str(selected)], text=True).strip()
            if mime.startswith('image/'):
                command += ['--type', mime]
        with selected.open('rb') as content:
            subprocess.run(command, stdin=content, check=True, timeout=5)


if __name__ == '__main__':
    try:
        pick()
    except (OSError, subprocess.SubprocessError) as error:
        subprocess.run(['notify-send', '-a', 'Clipboard', 'Clipboard unavailable', str(error)], timeout=3)
