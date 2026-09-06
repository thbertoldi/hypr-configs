"""PipeWire's PulseAudio interface, normalized for the desktop mixer."""
import json
import subprocess


def pactl(*args):
    result = subprocess.run(['pactl', *map(str, args)], capture_output=True, text=True, timeout=3)
    if result.returncode:
        raise RuntimeError('The audio device changed or is unavailable. Please try again.')
    return result.stdout


def listing(kind):
    return json.loads(pactl('-f', 'json', 'list', kind))


def volume(item):
    channels = list(item.get('volume', {}).values())
    return round(sum(c['value'] for c in channels) / len(channels) / 65536 * 100) if channels else 0


def choices(items, default):
    result = []
    for item in items:
        device = item.get('properties', {}).get('device.description') or item.get('description', item['name'])
        ports = [p for p in item.get('ports', []) if p.get('availability') != 'not available'] or [None]
        for port in ports:
            port_name = port['name'] if port else ''
            key = json.dumps([item['name'], port_name])
            result.append({'key': key, 'label': f"{port['description']} · {device}" if port else device,
                           'selected': item['name'] == default and (not port or item.get('active_port') == port_name)})
    return result


def snapshot():
    info = json.loads(pactl('-f', 'json', 'info'))
    sinks = listing('sinks')
    sources = [s for s in listing('sources') if not s.get('monitor_source')]
    sink = next((s for s in sinks if s['name'] == info['default_sink_name']), None)
    source = next((s for s in sources if s['name'] == info['default_source_name']), None)
    apps = []
    for item in listing('sink-inputs'):
        props = item.get('properties', {})
        apps.append({'id': str(item['index']), 'name': props.get('application.name') or props.get('media.name') or 'Application',
                     'volume': volume(item), 'mute': item.get('mute', False)})
    return {'outputs': choices(sinks, info['default_sink_name']), 'inputs': choices(sources, info['default_source_name']),
            'sink': {'volume': volume(sink), 'mute': sink['mute']} if sink else None,
            'source': {'volume': volume(source), 'mute': source['mute']} if source else None,
            'apps': apps}


def choose(kind, key):
    name, port = json.loads(key)
    if port:
        pactl(f'set-{kind}-port', name, port)
    pactl(f'set-default-{kind}', name)
    # Route existing playback/recording streams as well as newly opened apps.
    stream_type = 'sink-input' if kind == 'sink' else 'source-output'
    for stream in listing(stream_type + 's'):
        try:
            pactl(f'move-{stream_type}', stream['index'], name)
        except RuntimeError:
            # Streams may close while the device is being switched.
            continue


def set_volume(kind, target, percent):
    pactl(f'set-{kind}-volume', target, f'{max(0, min(100, round(percent)))}%')


def toggle_mute(kind, target):
    pactl(f'set-{kind}-mute', target, 'toggle')
