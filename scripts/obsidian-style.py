#!/usr/bin/env python3
"""Apply the portable Mocha/Peach theme to an existing Obsidian vault."""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import tempfile


BUNDLE = Path(__file__).resolve().parent.parent / "portable" / "obsidian"
PLUGIN = "obsidian-style-settings"


def read_json(path, default):
    return json.loads(path.read_text()) if path.exists() else default


def active_vaults():
    """Read only Obsidian's registry; never search or read vault notes."""
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    registries = (
        config_home / "obsidian/obsidian.json",
        Path.home() / ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json",
    )
    found = []
    for registry in registries:
        for entry in read_json(registry, {}).get("vaults", {}).values():
            if entry.get("open") and entry.get("path"):
                vault = Path(entry["path"]).expanduser().resolve()
                if vault.is_dir() and vault not in found:
                    found.append(vault)
    return found


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
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


def apply_theme(vault, config_folder, dry_run):
    config = vault / config_folder
    if not config.is_dir():
        raise ValueError(f"Obsidian settings directory does not exist: {config}")
    planned = {}
    for directory in ("themes", "plugins"):
        for source in sorted((BUNDLE / directory).rglob("*")):
            if source.is_file():
                planned[config / source.relative_to(BUNDLE)] = source.read_bytes()
    planned[config / "themes/Catppuccin/CATPPUCCIN-LICENSE"] = (
        BUNDLE / "CATPPUCCIN-LICENSE"
    ).read_bytes()

    for name, overrides in (
        ("appearance.json", read_json(BUNDLE / "appearance.json", {})),
        (f"plugins/{PLUGIN}/data.json", read_json(BUNDLE / "style-settings.json", {})),
    ):
        existing = read_json(config / name, {})
        if not isinstance(existing, dict):
            raise ValueError(f"Expected a JSON object in {config / name}")
        existing.update(overrides)
        planned[config / name] = (json.dumps(existing, indent=2) + "\n").encode()

    plugins_path = config / "community-plugins.json"
    enabled = read_json(plugins_path, [])
    if not isinstance(enabled, list) or not all(isinstance(p, str) for p in enabled):
        raise ValueError(f"Expected a list of plugin IDs in {plugins_path}")
    if PLUGIN not in enabled:
        enabled.append(PLUGIN)
    planned[plugins_path] = (json.dumps(enabled, indent=2) + "\n").encode()

    changed = {
        path: data for path, data in planned.items()
        if not path.exists() or path.read_bytes() != data
    }
    print(f"Obsidian vault: {vault}")
    if not changed:
        print("Theme is already up to date.")
        return
    for path in changed:
        print(f"  {'Would apply' if dry_run else 'Apply'} {path.relative_to(config)}")
    if dry_run:
        return

    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = state / "hypr-bootstrap/backups" / f"{stamp}-obsidian-{os.getpid()}"
    backup.mkdir(parents=True, exist_ok=False)
    manifest = {
        "vault": str(vault),
        "config_folder": config_folder,
        "files": [str(p.relative_to(config)) for p in changed],
        "created_files": [str(p.relative_to(config)) for p in changed if not p.exists()],
    }
    for path in changed:
        if path.exists():
            destination = backup / path.relative_to(config)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for path, data in changed.items():
        atomic_write(path, data)
    print(f"Backup: {backup}")
    print("Theme applied. Reload Obsidian to load the theme and Style Settings.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", type=Path, help="explicit existing vault directory")
    parser.add_argument("--config-folder", default=".obsidian", help="vault settings folder")
    parser.add_argument("--dry-run", action="store_true", help="show changes without writing")
    args = parser.parse_args()
    folder = Path(args.config_folder)
    if folder.is_absolute() or len(folder.parts) != 1 or folder.name in (".", ".."):
        parser.error("--config-folder must be a single folder name inside the vault")
    vaults = [args.vault.expanduser().resolve()] if args.vault else active_vaults()
    if not vaults:
        print("No open vault found. Open Obsidian once or pass --vault PATH.")
        return
    for vault in vaults:
        apply_theme(vault, args.config_folder, args.dry_run)


if __name__ == "__main__":
    main()
