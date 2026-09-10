#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"
seed_file="${HYPR_STUDY_SEED_FILE:-$script_dir/../portable/anki/starter-decks.json}"
quiet=0
[[ "${1:-}" != '--quiet' ]] || quiet=1

[[ -r "$seed_file" ]] || {
    printf 'arquivo de estudo não encontrado: %s\n' "$seed_file" >&2
    exit 1
}
jq -e '.version == 1 and (.decks | type == "array")' "$seed_file" >/dev/null
"$connect" ping >/dev/null

concept_model='Hypr Study — Concept'
french_model='Hypr Study — French'

concept_request=$(jq -cn '{
  modelName:"Hypr Study — Concept",
  inOrderFields:["Source ID","Question","Answer","Context","Source"],
  css:".card { font-family: Inter, Noto Sans, sans-serif; font-size: 20px; text-align: left; color: #cdd6f4; background: #1e1e2e; padding: 28px; line-height: 1.45; } .topic { color: #89b4fa; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; margin-bottom: 18px; } .question { color: #f5e0dc; font-size: 25px; font-weight: 700; } .answer { color: #a6e3a1; font-size: 22px; } .context { color: #bac2de; margin-top: 18px; padding: 14px; background: #313244; border-radius: 10px; } .source { font-size: 12px; margin-top: 18px; } a { color: #89b4fa; } code { color: #fab387; background: #181825; border-radius: 5px; padding: 2px 5px; } hr { border: 0; border-top: 1px solid #45475a; margin: 24px 0; }",
  isCloze:false,
  cardTemplates:[{
    Name:"Recall",
    Front:"<div class=topic>{{Deck}}</div><div class=question>{{Question}}</div>",
    Back:"{{FrontSide}}<hr id=answer><div class=answer>{{Answer}}</div>{{#Context}}<div class=context>{{Context}}</div>{{/Context}}{{#Source}}<div class=source><a href=\"{{Source}}\">Fonte oficial</a></div>{{/Source}}"
  }]
}')

french_request=$(jq -cn '{
  modelName:"Hypr Study — French",
  inOrderFields:["Source ID","French","Portuguese","Hint","Example","Audio"],
  css:".card { font-family: Inter, Noto Sans, sans-serif; font-size: 21px; text-align: center; color: #cdd6f4; background: #1e1e2e; padding: 30px; line-height: 1.5; } .topic { color: #cba6f7; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; margin-bottom: 20px; } .prompt { color: #a6adc8; font-size: 14px; margin-bottom: 12px; } .phrase { color: #f5e0dc; font-size: 30px; font-weight: 700; } .meaning { color: #a6e3a1; font-size: 24px; } .hint { color: #f9e2af; font-size: 14px; margin-top: 16px; } .example { color: #bac2de; margin-top: 20px; padding: 14px; background: #313244; border-radius: 10px; } code { color: #fab387; } hr { border: 0; border-top: 1px solid #45475a; margin: 24px 0; } #typeans { color: #cdd6f4; background: #181825; border: 1px solid #45475a; border-radius: 8px; padding: 8px; }",
  isCloze:false,
  cardTemplates:[
    {
      Name:"Reconnaissance",
      Front:"<div class=topic>Français · reconnaissance</div><div class=phrase>{{French}}</div>{{#Audio}}<div class=audio>{{Audio}}</div>{{/Audio}}{{^Audio}}{{tts fr_FR hypertts_preset=Front_hypr_study_french voices=HyperTTS:French}}{{/Audio}}",
      Back:"{{FrontSide}}<hr id=answer><div class=meaning>{{Portuguese}}</div>{{#Hint}}<div class=hint>{{Hint}}</div>{{/Hint}}{{#Example}}<div class=example>{{Example}}</div>{{/Example}}"
    },
    {
      Name:"Production",
      Front:"<div class=topic>Français · production</div><div class=prompt>Como se diz em francês?</div><div class=meaning>{{Portuguese}}</div>{{#Hint}}<div class=hint>{{Hint}}</div>{{/Hint}}<div>{{type:French}}</div>",
      Back:"{{FrontSide}}<hr id=answer><div class=phrase>{{French}}</div>{{#Audio}}<div class=audio>{{Audio}}</div>{{/Audio}}{{^Audio}}{{tts fr_FR hypertts_preset=Back_hypr_study_french voices=HyperTTS:French}}{{/Audio}}{{#Example}}<div class=example>{{Example}}</div>{{/Example}}"
    }
  ]
}')

models=$("$connect" request modelNames)
for model in "$concept_model" "$french_model"; do
    if jq -e --arg model "$model" '.result | index($model) != null' >/dev/null <<<"$models"; then
        continue
    fi
    if [[ "$model" == "$concept_model" ]]; then
        "$connect" request createModel "$concept_request" >/dev/null
    else
        "$connect" request createModel "$french_request" >/dev/null
    fi
done

while IFS= read -r deck; do
    params=$(jq -cn --arg deck "$deck" '{deck:$deck}')
    "$connect" request createDeck "$params" >/dev/null
done < <(jq -r '.decks[].name' "$seed_file")

media_map='{}'
while IFS=$'\t' read -r source_id phrase; do
    filename="hypr-study-${source_id}.mp3"
    params=$(jq -cn --arg filename "$filename" '{filename:$filename}')
    if ! "$connect" request retrieveMediaFile "$params" \
        | jq -e '.result != false' >/dev/null 2>&1; then
        audio=$("$script_dir/study-tts-synthesize.sh" "$phrase")
        params=$(jq -cn \
            --arg filename "$filename" \
            --arg data "$audio" \
            '{filename:$filename,data:$data}')
        "$connect" request storeMediaFile "$params" >/dev/null
    fi
    media_map=$(jq -cn \
        --argjson existing "$media_map" \
        --arg id "$source_id" \
        --arg audio "[sound:$filename]" \
        '$existing + {($id):$audio}')
done < <(jq -r '
  .decks[]
  | select(.model == "Hypr Study — French")
  | .notes[]
  | [.fields["Source ID"], .fields.French]
  | @tsv
' "$seed_file")

notes=$(jq -c --argjson media "$media_map" '{notes:[
  .decks[] as $deck
  | $deck.notes[]
  | {
      deckName:$deck.name,
      modelName:$deck.model,
      fields:(
        .fields
        + if $deck.model == "Hypr Study — French"
          then {Audio:($media[.fields["Source ID"]] // "")}
          else {}
          end
      ),
      tags:($deck.tags + ["hypr-study-seed","hypr-study-v1"]),
      options:{allowDuplicate:false, duplicateScope:"deck"}
    }
]}' "$seed_file")

can_add=$("$connect" request canAddNotes "$notes")
pending=$(jq -c \
    --argjson allowed "$(jq '.result' <<<"$can_add")" '
      .notes as $notes
      | {notes:[range(0; $notes|length) as $i | select($allowed[$i]) | $notes[$i]]}
    ' <<<"$notes")
pending_count=$(jq '.notes | length' <<<"$pending")

added_count=0
if (( pending_count > 0 )); then
    added=$("$connect" request addNotes "$pending")
    added_count=$(jq '[.result[] | select(. != null)] | length' <<<"$added")
    (( added_count == pending_count )) || {
        printf 'foram adicionadas %s de %s notas\n' "$added_count" "$pending_count" >&2
        exit 1
    }
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study"
install -d -m 0700 "$state_dir"
printf 'seed=1\nnotes_added=%s\ncompleted_at=%s\n' \
    "$added_count" "$(date --iso-8601=seconds)" >"$state_dir/seed-v1.done"
chmod 0600 "$state_dir/seed-v1.done"

if (( ! quiet )); then
    total=$(jq '[.decks[].notes[]] | length' "$seed_file")
    printf 'Study Hub pronto: %s novas notas; %s notas curadas no bundle.\n' \
        "$added_count" "$total"
fi

pkill -RTMIN+7 waybar 2>/dev/null || true
