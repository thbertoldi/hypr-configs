#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"
topic=${1:-all}

case "$topic" in
    all)    deck='Study Hub' ;;
    k8s)    deck='Study Hub::Kubernetes Core' ;;
    gpu)    deck='Study Hub::NVIDIA GPUs on Kubernetes' ;;
    french) deck='Study Hub::French Essentials' ;;
    browse) deck='' ;;
    *)
        printf 'uso: %s {all|k8s|gpu|french|browse}\n' "${0##*/}" >&2
        exit 64
        ;;
esac

if ! "$connect" ping >/dev/null 2>&1; then
    "$script_dir/anki.sh" >/dev/null 2>&1 &
fi

if ! "$connect" wait 30; then
    notify-send -a Hyprland -u critical \
        'Study Hub' \
        'O Anki abriu, mas o AnkiConnect não respondeu. Reinicie o Anki para carregar o complemento.'
    exit 1
fi

seed_marker="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study/seed-v1.done"
tts_marker="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study/tts-template-v1.done"
if [[ ! -f "$tts_marker" ]]; then
    "$script_dir/study-tts-repair.sh" >/dev/null || {
        notify-send -a Hyprland -u critical \
            'Study Hub' 'Não foi possível validar os templates de áudio.'
        exit 1
    }
fi
if [[ ! -f "$seed_marker" ]]; then
    "$script_dir/study-seed.sh" --quiet || {
        notify-send -a Hyprland -u critical \
            'Study Hub' 'Não foi possível preparar os baralhos iniciais.'
        exit 1
    }
fi

if [[ "$topic" == browse ]]; then
    params='{"query":"tag:hypr-study-seed"}'
    "$connect" request guiBrowse "$params" >/dev/null
else
    params=$(jq -cn --arg name "$deck" '{name:$name}')
    response=$("$connect" request guiDeckReview "$params")
    if [[ $(jq -r '.result' <<<"$response") != true ]]; then
        notify-send -a Hyprland -u critical \
            'Study Hub' "Não foi possível iniciar o baralho: $deck"
        exit 1
    fi
fi

pkill -RTMIN+7 waybar 2>/dev/null || true
