#!/usr/bin/env bash
set -euo pipefail

readonly endpoint="${ANKICONNECT_URL:-http://127.0.0.1:8765}"
readonly key_file="${ANKICONNECT_KEY_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study/ankiconnect-key}"

usage() {
    cat <<'EOF'
Uso:
  anki-connect.sh ping
  anki-connect.sh wait [segundos]
  anki-connect.sh request AÇÃO [PARAMETROS_JSON]
  anki-connect.sh raw REQUISIÇÃO_JSON

A resposta completa do AnkiConnect é escrita em JSON. O comando falha se o
Anki estiver fechado, a resposta for inválida ou a API retornar um erro.
EOF
}

api_key() {
    [[ -r "$key_file" ]] || {
        printf 'chave do AnkiConnect não encontrada: %s\n' "$key_file" >&2
        return 1
    }
    tr -d '\r\n' <"$key_file"
}

send_request() {
    local request=$1 response error
    response=$(curl --fail --silent --show-error \
        --connect-timeout 1 --max-time 5 \
        --header 'Content-Type: application/json' \
        --data-binary "$request" "$endpoint") || return 1

    jq -e 'type == "object" and has("result") and has("error")' \
        >/dev/null 2>&1 <<<"$response" || {
        printf 'resposta inválida do AnkiConnect\n' >&2
        return 1
    }

    error=$(jq -r '.error // empty' <<<"$response")
    if [[ -n "$error" ]]; then
        printf 'AnkiConnect: %s\n' "$error" >&2
        return 1
    fi

    printf '%s\n' "$response"
}

request_action() {
    local action=$1 params='{}' key request
    (( $# < 2 )) || params=$2
    jq -e 'type == "object"' >/dev/null 2>&1 <<<"$params" || {
        printf 'parâmetros devem ser um objeto JSON\n' >&2
        return 64
    }
    key=$(api_key)
    request=$(jq -cn \
        --arg action "$action" \
        --arg key "$key" \
        --argjson params "$params" \
        '{action:$action, version:6, key:$key, params:$params}')
    send_request "$request"
}

case "${1:-}" in
    ping)
        request_action version
        ;;
    wait)
        timeout=${2:-25}
        [[ "$timeout" =~ ^[0-9]+$ ]] || { usage >&2; exit 64; }
        for (( second=0; second<timeout; second++ )); do
            if request_action version >/dev/null 2>&1; then
                exit 0
            fi
            sleep 1
        done
        printf 'AnkiConnect não respondeu após %s segundos\n' "$timeout" >&2
        exit 1
        ;;
    request)
        (( $# >= 2 && $# <= 3 )) || { usage >&2; exit 64; }
        if (( $# == 3 )); then
            request_action "$2" "$3"
        else
            request_action "$2"
        fi
        ;;
    raw)
        (( $# == 2 )) || { usage >&2; exit 64; }
        key=$(api_key)
        request=$(jq -c --arg key "$key" '. + {version:(.version // 6), key:$key}' <<<"$2")
        send_request "$request"
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
