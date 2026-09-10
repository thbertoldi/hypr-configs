#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"
if command -v flatpak >/dev/null 2>&1 \
    && flatpak info net.ankiweb.Anki >/dev/null 2>&1; then
    addon="$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21/111623432"
else
    addon="${XDG_DATA_HOME:-$HOME/.local/share}/Anki2/addons21/111623432"
fi

[[ -r "$addon/hypertts_addon/version.py" ]] || {
    printf 'FALHA: HyperTTS não está instalado.\n' >&2
    exit 1
}
version=$(sed -n "s/^ANKI_HYPER_TTS_VERSION='\\([^']*\\)'.*/\\1/p" \
    "$addon/hypertts_addon/version.py")
[[ -n "$version" ]] || version='desconhecida'

"$connect" ping >/dev/null
models=$("$connect" request modelNames)
obsolete=0
hypertts_templates=0
invalid=0
while IFS= read -r model; do
    params=$(jq -cn --arg modelName "$model" '{modelName:$modelName}')
    templates=$("$connect" request modelTemplates "$params")
    jq -e '.result | tostring | contains("voices=AwesomeTTS")' \
        >/dev/null <<<"$templates" && (( obsolete += 1 ))
    jq -e '.result | tostring | contains("voices=HyperTTS")' \
        >/dev/null <<<"$templates" && (( hypertts_templates += 1 ))
    if ! python3 "$script_dir/study-tts-validate.py" "$addon/meta.json" "$model" <<<"$templates"; then
        (( invalid += 1 ))
    fi
done < <(jq -r '.result[]' <<<"$models")

(( invalid == 0 )) || exit 4

audio=$("$script_dir/study-tts-synthesize.sh" \
    'Bonjour, je parle un peu français.')
audio_bytes=$(printf '%s' "$audio" | base64 --decode | wc -c)
header=$(printf '%s' "$audio" | base64 --decode | od -An -N3 -tx1 | tr -d ' \n')
[[ "$header" == '494433' || "$header" == ff* ]] || {
    printf 'FALHA: o provedor não retornou um MP3 válido.\n' >&2
    exit 1
}

printf 'HyperTTS: %s\n' "$version"
printf 'Templates usando HyperTTS: %s\n' "$hypertts_templates"
printf 'Templates ainda usando AwesomeTTS: %s\n' "$obsolete"
printf 'Síntese francesa: OK (%s bytes, cabeçalho %s)\n' "$audio_bytes" "$header"

cached_total=0
cached_ok=0
query='{"query":"deck:\"Study Hub::French Essentials\" tag:hypr-study-seed"}'
seed_notes=$("$connect" request findNotes "$query")
if (( $(jq '.result | length' <<<"$seed_notes") > 0 )); then
    params=$(jq '{notes:.result}' <<<"$seed_notes")
    note_info=$("$connect" request notesInfo "$params")
    mapfile -t cached_files < <(jq -r '
      .result[]
      | .fields.Audio.value
      | capture("^\\[sound:(?<file>hypr-study-fr-[0-9]+\\.mp3)\\]$").file
    ' <<<"$note_info")
    cached_total=$(jq '.result | length' <<<"$note_info")
    for filename in "${cached_files[@]}"; do
        params=$(jq -cn --arg filename "$filename" '{filename:$filename}')
        if "$connect" request retrieveMediaFile "$params" \
            | jq -e '.result != false' >/dev/null; then
            (( cached_ok += 1 ))
        fi
    done
    printf 'Áudio cacheado do Study Hub: %s/%s notas\n' \
        "$cached_ok" "$cached_total"
fi

(( obsolete == 0 )) || exit 2
(( cached_total == 0 || cached_ok == cached_total )) || exit 3
