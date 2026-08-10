#!/usr/bin/env python3
"""Small StatusNotifier controller for Spotify's MPRIS interface."""

from __future__ import annotations

import fcntl
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator
except ValueError:
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3 as AppIndicator
from gi.repository import GLib, Gtk


PLAYER = "spotify"
SPOTIFY_ID = "com.spotify.Client"
SCRIPT_DIR = Path(__file__).resolve().parent


def run_quiet(*args: str, capture: bool = False) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            check=False,
            timeout=3,
            text=True,
            stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(args, 127, "" if capture else None)


class SpotifyTray:
    def __init__(self) -> None:
        self.track_uri = ""
        self.playing = False
        self.shuffle_enabled = False
        self.loop_mode = "None"

        self.indicator = AppIndicator.Indicator.new(
            "hypr-spotify-tray",
            SPOTIFY_ID,
            AppIndicator.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_title("Spotify")
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)

        self.menu = Gtk.Menu()
        self.track_item = self._item("Spotify is not running", sensitive=False)
        self.artist_item = self._item("", sensitive=False)
        self.menu.append(Gtk.SeparatorMenuItem())
        self.open_item = self._item("Open Spotify", self.open_spotify)
        self.toggle_item = self._item("Play", self.toggle_playback)
        self.previous_item = self._item("Previous", self.previous)
        self.next_item = self._item("Next", self.next)
        self.menu.append(Gtk.SeparatorMenuItem())
        self.shuffle_item = self._item("Shuffle: Off", self.toggle_shuffle)
        self.repeat_item = self._item("Repeat: Off", self.cycle_repeat)
        self.copy_item = self._item("Copy track link", self.copy_track_link)
        self.menu.append(Gtk.SeparatorMenuItem())
        self.quit_item = self._item("Quit Spotify", self.quit_spotify)
        self.menu.show_all()
        self.indicator.set_menu(self.menu)

        GLib.timeout_add_seconds(2, self.refresh)
        self.refresh()

    def _item(
        self,
        label: str,
        callback=None,
        *,
        sensitive: bool = True,
    ) -> Gtk.MenuItem:
        item = Gtk.MenuItem(label=label)
        item.set_sensitive(sensitive)
        if callback is not None:
            item.connect("activate", callback)
        self.menu.append(item)
        return item

    @staticmethod
    def _clean(value: str, fallback: str = "") -> str:
        value = " ".join(value.replace("\x00", "").split())
        return value or fallback

    def refresh(self) -> bool:
        status = run_quiet("playerctl", f"--player={PLAYER}", "status", capture=True)
        available = status.returncode == 0
        state = self._clean(status.stdout) if available else "Stopped"
        self.playing = state == "Playing"

        title = "Spotify is not running"
        artist = ""
        self.track_uri = ""
        if available:
            metadata = run_quiet(
                "playerctl",
                f"--player={PLAYER}",
                "metadata",
                "--format",
                "{{title}}\x1f{{artist}}\x1f{{xesam:url}}",
                capture=True,
            )
            fields = metadata.stdout.rstrip("\n").split("\x1f", 2)
            fields += [""] * (3 - len(fields))
            title = self._clean(fields[0], "Spotify")
            artist = self._clean(fields[1])
            self.track_uri = self._clean(fields[2])

        self.track_item.set_label(title[:72])
        self.artist_item.set_label(artist[:72])
        self.artist_item.set_visible(bool(artist))
        self.toggle_item.set_label("Pause" if self.playing else "Play")
        for item in (
            self.toggle_item,
            self.previous_item,
            self.next_item,
            self.shuffle_item,
            self.repeat_item,
        ):
            item.set_sensitive(available)
        self.copy_item.set_sensitive(bool(self.track_uri))

        if available:
            shuffle = run_quiet(
                "playerctl", f"--player={PLAYER}", "shuffle", capture=True
            )
            self.shuffle_enabled = self._clean(shuffle.stdout).lower() == "on"
            loop = run_quiet("playerctl", f"--player={PLAYER}", "loop", capture=True)
            self.loop_mode = self._clean(loop.stdout, "None")
        else:
            self.shuffle_enabled = False
            self.loop_mode = "None"
        self.shuffle_item.set_label(
            f"Shuffle: {'On' if self.shuffle_enabled else 'Off'}"
        )
        loop_label = {"None": "Off", "Track": "Track", "Playlist": "Playlist"}
        self.repeat_item.set_label(
            f"Repeat: {loop_label.get(self.loop_mode, self.loop_mode)}"
        )
        return GLib.SOURCE_CONTINUE

    def open_spotify(self, _item=None) -> None:
        if shutil.which("systemd-run"):
            unit = f"hypr-spotify-open-{os.getpid()}-{time.monotonic_ns()}"
            run_quiet(
                "systemd-run",
                "--user",
                "--collect",
                "--quiet",
                f"--unit={unit}",
                str(SCRIPT_DIR / "music-open.sh"),
            )
            return
        subprocess.Popen(
            [str(SCRIPT_DIR / "music-open.sh")],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    def toggle_playback(self, _item=None) -> None:
        if run_quiet("playerctl", f"--player={PLAYER}", "play-pause").returncode != 0:
            self.open_spotify()
        self.refresh()

    def previous(self, _item=None) -> None:
        run_quiet("playerctl", f"--player={PLAYER}", "previous")

    def next(self, _item=None) -> None:
        run_quiet("playerctl", f"--player={PLAYER}", "next")

    def toggle_shuffle(self, _item=None) -> None:
        run_quiet(
            "playerctl",
            f"--player={PLAYER}",
            "shuffle",
            "Off" if self.shuffle_enabled else "On",
        )
        self.refresh()

    def cycle_repeat(self, _item=None) -> None:
        next_mode = {"None": "Playlist", "Playlist": "Track", "Track": "None"}
        run_quiet(
            "playerctl",
            f"--player={PLAYER}",
            "loop",
            next_mode.get(self.loop_mode, "None"),
        )
        self.refresh()

    def copy_track_link(self, _item=None) -> None:
        if not self.track_uri or not shutil.which("wl-copy"):
            return
        link = self.track_uri
        if link.startswith("spotify:"):
            parts = link.split(":")
            if len(parts) >= 3:
                link = f"https://open.spotify.com/{parts[1]}/{parts[2]}"
        subprocess.run(
            ["wl-copy"],
            input=link,
            text=True,
            check=False,
            timeout=3,
        )

    def quit_spotify(self, _item=None) -> None:
        run_quiet(
            "gdbus",
            "call",
            "--session",
            "--dest",
            "org.mpris.MediaPlayer2.spotify",
            "--object-path",
            "/org/mpris/MediaPlayer2",
            "--method",
            "org.mpris.MediaPlayer2.Quit",
        )
        self.refresh()


def main() -> int:
    if not shutil.which("playerctl"):
        print("spotify-tray: playerctl not found", file=sys.stderr)
        return 1

    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/runtime-{os.getuid()}"))
    runtime_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_file = (runtime_dir / "hypr-spotify-tray.lock").open("w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0

    signal.signal(signal.SIGTERM, lambda *_args: Gtk.main_quit())
    signal.signal(signal.SIGINT, lambda *_args: Gtk.main_quit())
    SpotifyTray()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
