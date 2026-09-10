#!/usr/bin/env python3
"""Read-only checks after installing display fixes or logging back in."""
import json
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, timeout=5).strip()


def main():
    failures = []
    print(run("rpm", "-q", "hyprland", "libaquamarine14", "waybar"))
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    instances = json.loads(run("hyprctl", "instances", "-j"))
    instance = next((i for i in instances if i["instance"] == signature), None)
    if instance is None:
        print("Run this check from a terminal in the current Hyprland session.")
        return 1

    mappings = Path(f"/proc/{instance['pid']}/maps").read_text().splitlines()
    library = [line.split(maxsplit=5) for line in mappings if "libaquamarine.so." in line]
    if not library:
        failures.append("Could not identify the compositor's Aquamarine library.")
    elif any(" (deleted)" in entry[5] or
             int(entry[4]) != Path(entry[5]).stat().st_ino for entry in library):
        failures.append("Hyprland still uses the old Aquamarine library. Log out and back in.")
    else:
        print("PASS: Hyprland has the installed Aquamarine library loaded.")

    monitors = json.loads(run("hyprctl", "monitors", "all", "-j"))
    active = [m for m in monitors if not m["disabled"] and m["name"] != "FALLBACK"]
    layers = json.loads(run("hyprctl", "layers", "-j"))
    if not active:
        failures.append("No physical output is enabled.")
    for monitor in active:
        name = monitor["name"]
        if monitor["width"] <= 0 or monitor["height"] <= 0:
            failures.append(f"{name}: enabled output has an unusable resolution.")
            continue
        if not monitor["dpmsStatus"]:
            failures.append(f"{name}: display is asleep; wake it before checking.")
            continue
        print(f"PASS: {name} is awake at {monitor['width']}x{monitor['height']}.")
        bars = [layer for level in layers.get(name, {}).get("levels", {}).values()
                for layer in level if layer["namespace"] == "waybar"
                and layer["w"] > 0 and layer["h"] > 0]
        if not bars:
            failures.append(f"{name}: Waybar has no mapped surface.")
        else:
            print(f"PASS: {name} has a mapped Waybar surface.")

    for failure in failures:
        print(f"FAIL: {failure}")
    print("This checks current state; verify a real lock/wake cycle separately.")
    return int(bool(failures))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        print(f"Display check could not complete: {error}", file=sys.stderr)
        sys.exit(1)
