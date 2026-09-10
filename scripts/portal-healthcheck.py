#!/usr/bin/env python3
"""Recover a portal that spins without servicing D-Bus (upstream issue #433)."""
import subprocess
import time


UNIT = "xdg-desktop-portal-hyprland.service"
BUS_NAME = "org.freedesktop.impl.portal.desktop.hyprland"
PROBE_SECONDS = 5
MIN_CPU_FRACTION = 0.5


def snapshot():
    """Return the service invocation and CPU usage, or None if it is not running."""
    result = subprocess.run(
        ["systemctl", "--user", "show", UNIT, "-p", "ActiveState", "-p", "SubState",
         "-p", "InvocationID", "-p", "CPUUsageNSec"],
        capture_output=True, text=True, timeout=5,
    )
    if result.returncode:
        return None
    fields = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if fields.get("ActiveState") != "active" or fields.get("SubState") != "running":
        return None
    try:
        identity = fields["InvocationID"]
        return (identity, int(fields["CPUUsageNSec"])) if identity else None
    except (KeyError, ValueError):
        return None


def responsive():
    # Do not activate a portal that the user or session manager has stopped.
    try:
        result = subprocess.run(
            ["busctl", "--user", "--auto-start=no", f"--timeout={PROBE_SECONDS}s",
             "call", BUS_NAME, "/org/freedesktop/portal/desktop",
             "org.freedesktop.DBus.Peer", "Ping"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=PROBE_SECONDS + 1,
        )
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        return False


def check():
    previous = snapshot()
    if previous is None:
        return 0

    # A picker can legitimately block D-Bus while waiting for user input.
    # Require sustained CPU use as well as two consecutive full probe timeouts.
    for _ in range(2):
        started = time.monotonic()
        if responsive():
            return 0
        elapsed = time.monotonic() - started
        current = snapshot()
        if current is None or current[0] != previous[0]:
            return 0
        if elapsed < PROBE_SECONDS * 0.9:
            return 0  # Immediate bus errors do not establish a hung service.
        cpu_fraction = (current[1] - previous[1]) / (elapsed * 1_000_000_000)
        if cpu_fraction < MIN_CPU_FRACTION:
            return 0
        previous = current

    print("Hyprland portal is unresponsive and spinning; requesting recovery.", flush=True)
    # try-restart also respects a stop that happens after the last snapshot.
    # The portal drop-in limits restarts to three starts per ten minutes.
    return subprocess.run(
        ["systemctl", "--user", "try-restart", UNIT], timeout=45,
    ).returncode


if __name__ == "__main__":
    try:
        raise SystemExit(check())
    except (OSError, subprocess.TimeoutExpired) as error:
        # A failed check must never turn into an unconditional restart.
        raise SystemExit(f"Portal health check could not complete: {error}")
