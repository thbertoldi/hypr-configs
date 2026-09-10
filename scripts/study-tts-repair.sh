#!/usr/bin/env bash
# Repair the bare French TTS tags created by the original Study Hub setup.
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study"
marker="$state_dir/tts-template-v2.done"
if command -v flatpak >/dev/null 2>&1 \
    && flatpak info net.ankiweb.Anki >/dev/null 2>&1; then
    addon="$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21/111623432"
else
    addon="${XDG_DATA_HOME:-$HOME/.local/share}/Anki2/addons21/111623432"
fi

"$connect" ping >/dev/null
install -d -m 0700 "$state_dir"

models=$("$connect" request modelNames)
matching_models=()
backup='{}'
updates='{}'
while IFS= read -r model; do
    params=$(jq -cn --arg modelName "$model" '{modelName:$modelName}')
    templates=$("$connect" request modelTemplates "$params")
    repaired=$(jq '.result | with_entries(.value |= with_entries(
      .key as $side | .value |= gsub(
        "\\{\\{tts fr_FR voices=(HyperTTS|AwesomeTTS):(?<field>French|Sentence)\\}\\}";
        "{{tts fr_FR hypertts_preset=" + $side
        + (if .field == "French" then "_hypr_study_french" else "_hypr_study_sentence_fr" end)
        + " voices=HyperTTS:" + .field + "}}"
      )
    ))' <<<"$templates")
    if [[ "$(jq -S -c '.result' <<<"$templates")" != "$(jq -S -c . <<<"$repaired")" ]]; then
        # Check every replacement before updating any model. Renaming a voice
        # alone cannot configure HyperTTS; its preset must already exist.
        python3 "$script_dir/study-tts-validate.py" "$addon/meta.json" "$model" \
            <<<"$(jq -cn --argjson result "$repaired" '{result:$result}')"
        matching_models+=("$model")
        backup=$(jq -cn \
            --argjson existing "$backup" \
            --arg model "$model" \
            --argjson templates "$(jq '.result' <<<"$templates")" \
            '$existing + {($model):$templates}')
        updates=$(jq -cn --argjson existing "$updates" --arg model "$model" \
            --argjson templates "$repaired" '$existing + {($model):$templates}')
    fi
done < <(jq -r '.result[]' <<<"$models")

if (( ${#matching_models[@]} == 0 )); then
    printf 'verified_at=%s\nmodels_repaired=0\n' \
        "$(date --iso-8601=seconds)" >"$marker"
    chmod 0600 "$marker"
    printf 'Nenhum tag francês sem preset precisa de reparo.\n'
    exit 0
fi

backup_file=$(mktemp "$state_dir/tts-templates-before-v2.XXXXXX.json")
printf '%s\n' "$backup" >"$backup_file"

for model in "${matching_models[@]}"; do
    params=$(jq -cn \
        --arg name "$model" --argjson updates "$updates" \
        '{model:{name:$name,templates:$updates[$name]}}')
    "$connect" request updateModelTemplates "$params" >/dev/null
    printf 'Template reparado: %s\n' "$model"
done

printf 'repaired_at=%s\nmodels_repaired=%s\n' \
    "$(date --iso-8601=seconds)" "${#matching_models[@]}" >"$marker"
chmod 0600 "$marker"
printf 'Backup dos templates originais: %s\n' "$backup_file"
