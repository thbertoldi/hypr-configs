#!/usr/bin/env python3
"""Validate template references against HyperTTS's saved realtime presets."""

import json
import re
import sys
from pathlib import Path


def template_errors(templates, config):
    presets = config.get("realtime_config", {})
    for template, sides in templates.items():
        for side, html in sides.items():
            for match in re.finditer(r"\{\{tts\s+([^:}]+):[^}]+\}\}", html):
                arguments = match[1].split()
                voices = [arg for arg in arguments if arg.startswith("voices=")]
                if not any("HyperTTS" in arg.split("=", 1)[1].split(",") for arg in voices):
                    continue
                references = [arg.split("=", 1)[1] for arg in arguments
                              if arg.startswith("hypertts_preset=")]
                label = f"{template} / {side}"
                if len(references) != 1:
                    yield f"{label}: HyperTTS requer exatamente um hypertts_preset"
                    continue
                preset_side, separator, key = references[0].partition("_")
                if not separator or preset_side not in ("Front", "Back"):
                    yield f"{label}: referência de preset inválida: {references[0]}"
                    continue
                preset = presets.get(key, {}).get(preset_side.lower(), {})
                if not preset.get("side_enabled"):
                    yield f"{label}: preset ausente ou desativado: {references[0]}"
                elif not preset.get("voice_selection"):
                    yield f"{label}: preset sem voz configurada: {references[0]}"


if __name__ == "__main__":
    config = json.loads(Path(sys.argv[1]).read_text())["config"]
    templates = json.load(sys.stdin)["result"]
    errors = list(template_errors(templates, config))
    for error in errors:
        print(f"FALHA: {sys.argv[2]} / {error}", file=sys.stderr)
    sys.exit(bool(errors))
