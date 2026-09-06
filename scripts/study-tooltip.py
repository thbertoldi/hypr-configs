#!/usr/bin/env python3
"""Dress the existing Study Hub status for Waybar without changing its data."""
from html import escape
import json
import sys

TEXT = '#cdd6f4'
MUTED = '#a6adc8'
MAUVE = '#cba6f7'
BLUE = '#89b4fa'
PEACH = '#fab387'
GREEN = '#a6e3a1'


def span(text, color=TEXT, **attributes):
    attrs = {'foreground': color, **attributes}
    style = ' '.join(f'{key}="{escape(str(value), quote=True)}"' for key, value in attrs.items())
    return f'<span {style}>{escape(str(text))}</span>'


def count(data, key):
    try:
        return max(0, int(data.get(key, 0)))
    except (TypeError, ValueError):
        return 0


def tooltip(data):
    heading = span('ANKI  /  STUDY HUB', MAUVE, size='small', weight='bold', letter_spacing=1600)
    divider = span('────────────────────────────', '#45475a', font_family='monospace', size='small')
    footer = span('Click to study  ·  Middle-click for French\nRight-click for the study agent', MUTED, size='small')
    lines = [heading, '']
    if not data.get('available'):
        setup = 'preparar' in str(data.get('tooltip', ''))
        lines += [
            span('A place to keep learning', TEXT, size='x-large', weight='bold'),
            span('Open Study Hub to prepare your decks.' if setup else 'Open Anki to see today’s queue.', MUTED),
            '',
            span('Kubernetes  ·  NVIDIA GPUs  ·  Français', MAUVE, size='small'),
        ]
    else:
        total = count(data, 'total')
        if total:
            lines += [span(total, TEXT, size=30000, weight='bold') + '  ' + span('cards ready for today', MUTED)]
        else:
            lines += [span('Today’s queue is clear', GREEN, size='x-large', weight='bold')]
        lines += ['']
        chips = []
        for key, title, color in (('new', 'New', BLUE), ('learn', 'Learn', PEACH), ('review', 'Review', GREEN)):
            value = count(data, key)
            chips.append(span(f' {value} {title} ', color if value else MUTED,
                              background='#313244', weight='bold', size='small'))
        lines += ['  '.join(chips), divider, span('DECK QUEUES', MUTED, size='small', weight='bold', letter_spacing=1200)]
        for key, name, color in (('k8s', 'Kubernetes', BLUE),
                                 ('gpu', 'NVIDIA / Kubernetes', GREEN),
                                 ('french', 'Français', MAUVE)):
            lines.append(span('● ', color) + span(f'{name:<21}{count(data, key):>4}',
                                                  font_family='monospace', size='small'))
        lines += [span('Deck queues share the Study Hub daily limit.', MUTED, size='small'), '']
        reviewed = count(data, 'reviewed_today')
        lines += [span(f'{reviewed} reviews today', GREEN if reviewed else MUTED, weight='bold')
                  + span('  ·  all decks', MUTED, size='small')]
    lines += [divider, footer]
    return '<span font_family="Noto Sans" line_height="1.3">' + '\n'.join(lines) + '</span>'


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            raise ValueError('Expected a status object')
    except (ValueError, OSError):
        data = {'available': False, 'text': '󰓎', 'class': 'offline'}
    data['tooltip'] = tooltip(data)
    print(json.dumps(data, ensure_ascii=False))


if __name__ == '__main__':
    main()
