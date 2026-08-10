#!/usr/bin/env bash
# Repair shared decks that still refer to HyperTTS's former AwesomeTTS name.
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study"
backup_file="$state_dir/tts-templates-before-repair.json"
marker="$state_dir/tts-template-v1.done"

"$connect" ping >/dev/null
install -d -m 0700 "$state_dir"

models=$("$connect" request modelNames)
matching_models=()
backup='{}'
while IFS= read -r model; do
    params=$(jq -cn --arg modelName "$model" '{modelName:$modelName}')
    templates=$("$connect" request modelTemplates "$params")
    if jq -e '.result | tostring | contains("voices=AwesomeTTS")' \
        >/dev/null <<<"$templates"; then
        matching_models+=("$model")
        backup=$(jq -cn \
            --argjson existing "$backup" \
            --arg model "$model" \
            --argjson templates "$(jq '.result' <<<"$templates")" \
            '$existing + {($model):$templates}')
    fi
done < <(jq -r '.result[]' <<<"$models")

if (( ${#matching_models[@]} == 0 )); then
    printf 'verified_at=%s\nmodels_repaired=0\n' \
        "$(date --iso-8601=seconds)" >"$marker"
    chmod 0600 "$marker"
    printf 'Nenhum template com a voz obsoleta AwesomeTTS foi encontrado.\n'
    exit 0
fi

if [[ ! -e "$backup_file" ]]; then
    printf '%s\n' "$backup" >"$backup_file"
    chmod 0600 "$backup_file"
fi

for model in "${matching_models[@]}"; do
    params=$(jq -cn \
        --arg modelName "$model" \
        '{
          modelName:$modelName,
          findText:"voices=AwesomeTTS",
          replaceText:"voices=HyperTTS",
          front:true,
          back:true,
          css:false
        }')
    "$connect" request findAndReplaceInModels "$params" >/dev/null
    printf 'Template reparado: %s\n' "$model"
done

printf 'repaired_at=%s\nmodels_repaired=%s\n' \
    "$(date --iso-8601=seconds)" "${#matching_models[@]}" >"$marker"
chmod 0600 "$marker"
printf 'Backup dos templates originais: %s\n' "$backup_file"
