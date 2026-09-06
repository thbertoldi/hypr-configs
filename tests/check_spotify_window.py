#!/usr/bin/env python3
"""Opt-in regression check: python3 tests/check_spotify_window.py --live.

Requires a running Spotify in a Hyprland session. Exercises the configured close
callback and tray hide command, then restores the starting window/focus state.
Does not start, stop, pause, or seek playback.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
HIDDEN_WORKSPACE = "special:spotify"


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def query(name):
    return json.loads(run("hyprctl", name, "-j"))


def spotify():
    windows = [w for w in query("clients") if w["class"].lower() == "spotify"]
    if len(windows) != 1:
        raise RuntimeError("Open one Spotify window before running this check.")
    return windows[0]


def monitor_state():
    return [(m["id"], m["activeWorkspace"]["id"], m["specialWorkspace"]["id"])
            for m in query("monitors")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", required=True, action="store_true")
    parser.parse_args()
    initial = spotify()
    focused = query("activewindow").get("address")
    playback = run("playerctl", "--player=spotify", "status")
    source = (ROOT / "lua/keybinds.lua").read_text()
    match = re.search(r'hl\.bind\(m \.\. " \+ Q", (function\(\).*?\nend)\)', source, re.S)
    if not match:
        raise RuntimeError("Could not identify the configured Super+Q callback.")
    launcher = str(ROOT / "scripts/music-open.sh")
    try:
        for action in (("hyprctl", "dispatch", match[1]), (launcher, "--hide")):
            run(launcher)
            assert query("activewindow")["address"] == initial["address"]
            before = monitor_state()
            run(*action)
            # Allow workspace animations and delayed focus requests to finish.
            for delay in (0.5, 1.5):
                time.sleep(delay)
                window = spotify()
                assert window["workspace"]["name"] == HIDDEN_WORKSPACE
                # clients.visible describes the surface, not workspace visibility.
                # A hidden special workspace must not be shown on ANY monitor.
                assert all(m["specialWorkspace"]["id"] != window["workspace"]["id"]
                           for m in query("monitors")), "Spotify workspace opened"
                assert monitor_state() == before, "Hide changed the active workspace"
                assert query("activewindow").get("address") != initial["address"]
                assert window["pid"] == initial["pid"]
                assert run("playerctl", "--player=spotify", "status") == playback
            run(launcher)
            time.sleep(0.5)
            window = spotify()
            assert window["workspace"]["name"] != HIDDEN_WORKSPACE
            assert window["acceptsInput"] and window["pid"] == initial["pid"]
            assert query("activewindow")["address"] == initial["address"]
            assert monitor_state() == before
            print(f"PASS: {'Super+Q callback' if action[0] == 'hyprctl' else 'tray Hide'}"
                  " keeps the workspace closed and restores the same player.")
    finally:
        # Restore the original workspace even when an assertion fails.
        window = spotify()
        workspace = initial["workspace"]["name"]
        target = workspace if workspace == HIDDEN_WORKSPACE else initial["workspace"]["id"]
        run("hyprctl", "dispatch", "hl.dsp.window.move({ window = "
            + json.dumps("address:" + window["address"]) + ", workspace = "
            + json.dumps(target) + ", follow = false })")
        if focused and any(w["address"] == focused for w in query("clients")):
            run("hyprctl", "dispatch", "hl.dsp.focus({ window = "
                + json.dumps("address:" + focused) + " })")


if __name__ == "__main__":
    main()
