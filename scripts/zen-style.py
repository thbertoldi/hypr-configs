#!/usr/bin/env python3
"""Apply the portable Zen theme without copying or editing browsing data."""

import argparse
import configparser
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import tempfile


BUNDLE = Path(__file__).resolve().parent.parent / "portable" / "zen"
MARKER = "hypr-configs: Zen Mocha/Peach"


def default_profiles():
    """Prefer the installation default over an old ProfileN Default=1 entry."""
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    roots = (
        Path.home() / ".var/app/app.zen_browser.zen/.zen",
        Path.home() / ".zen",
        config_home / "zen",
    )
    found = []
    for root in roots:
        parser = configparser.ConfigParser(interpolation=None)
        if not parser.read(root / "profiles.ini"):
            continue
        candidates = [
            root / parser[section]["Default"]
            for section in parser.sections()
            if section.startswith("Install") and parser.has_option(section, "Default")
        ]
        if not candidates:
            installs = configparser.ConfigParser(interpolation=None)
            installs.read(root / "installs.ini")
            candidates = [
                root / installs[section]["Default"]
                for section in installs.sections()
                if installs.has_option(section, "Default")
            ]
        if not candidates:
            profiles = [
                parser[section]
                for section in parser.sections()
                if section.startswith("Profile") and parser.has_option(section, "Path")
            ]
            chosen = [profile for profile in profiles if profile.get("Default") == "1"]
            if not chosen and len(profiles) == 1:
                chosen = profiles
            candidates = [
                root / profile["Path"] if profile.get("IsRelative", "1") == "1"
                else Path(profile["Path"])
                for profile in chosen
            ]
        for candidate in candidates:
            candidate = candidate.resolve()
            if (candidate / "prefs.js").is_file() and candidate not in found:
                found.append(candidate)
    return found


def managed_block(text, content, *, css=False):
    begin = f"/* BEGIN {MARKER} */" if css else f"// BEGIN {MARKER}"
    end = f"/* END {MARKER} */" if css else f"// END {MARKER}"
    if text.count(begin) != text.count(end) or text.count(begin) > 1:
        raise ValueError("incomplete or repeated theme markers; review the file first")
    if begin in text and text.index(begin) > text.index(end):
        raise ValueError("theme markers are out of order; review the file first")
    pattern = re.escape(begin) + r".*?" + re.escape(end) + r"\n?"
    text = re.sub(pattern, "", text, flags=re.DOTALL)
    block = f"{begin}\n{content.rstrip()}\n{end}\n"
    if css:
        # CSS imports must precede style rules, but follow an optional charset.
        charset = re.match(r'\A(?:\ufeff)?@charset\s+"[^"]+";\s*', text)
        prefix = text[:charset.end()] if charset else ""
        rest = text[charset.end():] if charset else text.lstrip("\ufeff")
        return prefix + block + rest
    return text.rstrip("\n") + ("\n" if text else "") + block


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Follow an existing user-managed symlink while preserving the link itself.
    destination = path.resolve() if path.is_symlink() else path
    mode = destination.stat().st_mode & 0o777 if destination.exists() else 0o644
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temp_path = Path(temporary.name)
        try:
            temporary.write(data)
            temporary.flush()
            os.fchmod(temporary.fileno(), mode)
            os.replace(temp_path, destination)
        finally:
            temp_path.unlink(missing_ok=True)


def previous_preferences(profile):
    names = re.findall(r'user_pref\("([^"]+)"', (BUNDLE / "user.js").read_text())
    values = dict.fromkeys(names)
    prefs = profile / "prefs.js"
    if prefs.is_file():
        with prefs.open() as source:
            for line in source:
                match = re.fullmatch(r'user_pref\(("[^"]+"), (.+)\);\s*', line)
                if match and json.loads(match[1]) in values:
                    values[json.loads(match[1])] = json.loads(match[2])
    return values


def apply_theme(profile, dry_run):
    if not profile.is_dir():
        raise ValueError(f"profile directory does not exist: {profile}")
    planned = {
        profile / "chrome" / source.name: source.read_bytes()
        for source in sorted((BUNDLE / "chrome").iterdir()) if source.is_file()
    }
    planned[profile / "chrome/CATPPUCCIN-LICENSE"] = (BUNDLE / "CATPPUCCIN-LICENSE").read_bytes()
    chrome_imports = (
        '@import "catppuccin-mocha-peach.css";\n'
        '@import "hypr-mocha-peach.css";'
    )
    for relative, content, css in (
        ("chrome/userChrome.css", chrome_imports, True),
        ("chrome/userContent.css", '@import "catppuccin-mocha-peach-content.css";', True),
        ("user.js", (BUNDLE / "user.js").read_text(), False),
    ):
        target = profile / relative
        existing = target.read_text() if target.exists() else ""
        planned[target] = managed_block(existing, content, css=css).encode()
    changed = {
        target: data for target, data in planned.items()
        if not target.exists() or target.read_bytes() != data
    }
    print(f"Zen profile: {profile}")
    if not changed:
        print("Theme is already up to date.")
        return
    if dry_run:
        print("Would back up existing user.js and chrome/ before applying:")
        for target in changed:
            print(f"  {target.relative_to(profile)}")
        return

    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = state / "hypr-bootstrap/backups" / f"{stamp}-zen-{os.getpid()}"
    backup.mkdir(parents=True, exist_ok=False)
    for name in ("chrome", "user.js"):
        source = profile / name
        if source.is_dir():
            shutil.copytree(source, backup / name)
        elif source.exists():
            shutil.copy2(source, backup / name)
    manifest = {
        "profile": str(profile),
        "created_files": [str(p.relative_to(profile)) for p in changed if not p.exists()],
        "previous_preferences": previous_preferences(profile),
    }
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for target, data in changed.items():
        atomic_write(target, data)
    print(f"Backup: {backup}")
    print("Theme applied. Restart Zen to load the styles and appearance preferences.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, help="explicit Zen profile directory")
    parser.add_argument("--dry-run", action="store_true", help="show changes without writing")
    args = parser.parse_args()
    profiles = [args.profile.expanduser().resolve()] if args.profile else default_profiles()
    if not profiles:
        print("No initialized Zen profile found. Start Zen once, then run zen-style.py again.")
        return
    for profile in profiles:
        apply_theme(profile, args.dry_run)


if __name__ == "__main__":
    main()
