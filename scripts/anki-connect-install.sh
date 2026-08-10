#!/usr/bin/env bash
# Install a reviewed, pinned AnkiConnect build and protect it with a local key.
set -Eeuo pipefail
IFS=$'\n\t'

readonly addon_id='2055492159'
readonly addon_version='25.11.9.0'
readonly archive_url="https://git.sr.ht/~foosoft/anki-connect/archive/${addon_version}.tar.gz"
readonly archive_sha256='1a88bbfa2a0fc5d0e78bc6a9850f1834bc95297702082a5b51177f7ee47e027c'
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-study"
readonly key_file="$state_dir/ankiconnect-key"

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

umask 077
install -d -m 0700 "$state_dir"
if [[ ! -s "$key_file" ]]; then
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n' >"$key_file"
fi
chmod 0600 "$key_file"
api_key=$(tr -d '\r\n' <"$key_file")
[[ "$api_key" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'chave inválida em %s; preserve o arquivo ou substitua-o por 64 dígitos hexadecimais\n' "$key_file" >&2
    exit 1
}

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ankiconnect-install.XXXXXX")
curl --fail --location --silent --show-error --retry 3 \
    --proto '=https' --tlsv1.2 \
    "$archive_url" --output "$temp_dir/ankiconnect.tar.gz"
printf '%s  %s\n' "$archive_sha256" "$temp_dir/ankiconnect.tar.gz" \
    | sha256sum --check --status || {
        printf 'checksum inválido para %s\n' "$archive_url" >&2
        exit 1
    }
tar -xzf "$temp_dir/ankiconnect.tar.gz" -C "$temp_dir"

install -d -m 0700 "$addon_dir"
rsync -a \
    "$temp_dir/anki-connect-${addon_version}/plugin/" \
    "$addon_dir/"

meta_file="$addon_dir/meta.json"
if [[ -s "$meta_file" ]] && jq -e 'type == "object"' "$meta_file" >/dev/null 2>&1; then
    meta=$(<"$meta_file")
else
    meta='{}'
fi

jq -n \
    --argjson existing "$meta" \
    --arg key "$api_key" \
    --arg version "$addon_version" '
      $existing
      | .name = "AnkiConnect"
      | .disabled = false
      | .update_enabled = false
      | .conflicts = (.conflicts // [])
      | .config = ((.config // {}) + {
          apiKey: $key,
          apiLogPath: null,
          webBindAddress: "127.0.0.1",
          webBindPort: 8765,
          webCorsOriginList: ["http://localhost"],
          ignoreOriginList: []
        })
      | .hyprStudyVersion = $version
    ' >"$temp_dir/meta.json"
install -m 0600 "$temp_dir/meta.json" "$meta_file"
printf '%s\n' "$addon_version" >"$addon_dir/.hypr-study-version"
chmod 0600 "$addon_dir/.hypr-study-version"

printf 'AnkiConnect %s instalado em %s\n' "$addon_version" "$addon_dir"
printf 'API limitada a 127.0.0.1 e protegida por chave em %s\n' "$key_file"
printf 'Reinicie o Anki para carregar ou atualizar o complemento.\n'
