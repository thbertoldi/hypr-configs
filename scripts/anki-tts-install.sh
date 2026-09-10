#!/usr/bin/env bash
# Install the reviewed HyperTTS release used by French card templates.
set -Eeuo pipefail
IFS=$'\n\t'

readonly addon_id='111623432'
readonly addon_version='3.3.0'
readonly archive_url="https://github.com/Vocab-Apps/anki-hyper-tts/releases/download/v${addon_version}/anki-hyper-tts-${addon_version}.ankiaddon"
readonly archive_sha256='fb8b6851bf19b6930032b43304751c522b829e6cd89c8ebb4c3237ce48c7d046'
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
realtime_defaults="$script_dir/../portable/anki/hypertts-realtime.json"

temp_dir=''
cleanup() {
    [[ -z "$temp_dir" || ! -d "$temp_dir" ]] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info net.ankiweb.Anki >/dev/null 2>&1; then
    addon_root="$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21"
else
    addon_root="${XDG_DATA_HOME:-$HOME/.local/share}/Anki2/addons21"
fi
addon_dir="$addon_root/$addon_id"

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/hypertts-install.XXXXXX")
installed_version=''
if [[ -r "$addon_dir/hypertts_addon/version.py" ]]; then
    installed_version=$(sed -n "s/^ANKI_HYPER_TTS_VERSION='\([^']*\)'.*/\1/p" \
        "$addon_dir/hypertts_addon/version.py")
fi
# Preserve updates installed through Anki, including their newer config schema.
if [[ -n "$installed_version" ]] \
    && [[ $(printf '%s\n' "$addon_version" "$installed_version" | sort -V | head -n1) == "$addon_version" ]]; then
    printf 'HyperTTS %s já está instalado em %s; validando configuração\n' \
        "$installed_version" "$addon_dir"
else
    curl --fail --location --silent --show-error --retry 3 \
        --proto '=https' --tlsv1.2 \
        "$archive_url" --output "$temp_dir/hypertts.ankiaddon"
    printf '%s  %s\n' "$archive_sha256" "$temp_dir/hypertts.ankiaddon" \
        | sha256sum --check --status || {
            printf 'checksum inválido para %s\n' "$archive_url" >&2
            exit 1
        }

    install -d -m 0700 "$addon_dir"
    unzip -oq "$temp_dir/hypertts.ankiaddon" -d "$addon_dir"
    installed_version=$addon_version
fi

meta_file="$addon_dir/meta.json"
if [[ -s "$meta_file" ]] && jq -e 'type == "object"' "$meta_file" >/dev/null 2>&1; then
    meta=$(<"$meta_file")
else
    meta='{}'
fi
jq -n --argjson existing "$meta" --arg version "${installed_version:-$addon_version}" \
  --slurpfile realtime "$realtime_defaults" '
  $existing
  | .name = "HyperTTS - Add speech to your flashcards"
  | .disabled = false
  | .update_enabled = true
  | .conflicts = (.conflicts // [])
  | .config = ((.config // {}) + {
      configuration: ((.config.configuration // {}) + {
        service_enabled: ((.config.configuration.service_enabled // {}) + {
          GoogleTranslate: true,
          ESpeakNg: true
        })
      }),
      preferences: (.config.preferences // {}),
      presets: (.config.presets // {}),
      mapping_rules: (.config.mapping_rules // {}),
      batch_config: (.config.batch_config // {}),
      config_schema: (.config.config_schema // 3),
      realtime_config: ($realtime[0] + (.config.realtime_config // {})),
      default_presets: (.config.default_presets // {})
    })
  | .hyprStudyVersion = $version
' >"$temp_dir/meta.json"
install -m 0600 "$temp_dir/meta.json" "$meta_file"

printf 'HyperTTS %s instalado em %s\n' "$installed_version" "$addon_dir"
printf 'Reinicie o Anki para carregar ou atualizar o complemento.\n'
