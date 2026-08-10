#!/usr/bin/env bash
# Emit a base64-encoded MP3 for a French phrase using HyperTTS's pinned gTTS.
set -euo pipefail

(( $# == 1 )) || {
    printf 'uso: %s FRASE_EM_FRANCÊS\n' "${0##*/}" >&2
    exit 64
}
phrase=$1
[[ -n "$phrase" ]] || exit 64

flatpak_addon="$HOME/.var/app/net.ankiweb.Anki/data/Anki2/addons21/111623432"
native_addon="${XDG_DATA_HOME:-$HOME/.local/share}/Anki2/addons21/111623432"

python_code='import base64,io,sys; from gtts import gTTS; output=io.BytesIO(); gTTS(text=sys.argv[1],lang="fr",timeout=15).write_to_fp(output); sys.stdout.write(base64.b64encode(output.getvalue()).decode("ascii"))'

if command -v flatpak >/dev/null 2>&1 \
    && flatpak info net.ankiweb.Anki >/dev/null 2>&1 \
    && [[ -d "$flatpak_addon/external/gtts" ]]; then
    # shellcheck disable=SC2016 # $1..$3 expand inside the Flatpak shell.
    exec flatpak run --command=sh net.ankiweb.Anki -c \
        'PYTHONPATH="$1/external" /usr/bin/python -c "$2" "$3"' \
        sh "$flatpak_addon" "$python_code" "$phrase"
fi

if python3 -c 'import gtts' >/dev/null 2>&1; then
    exec python3 -c "$python_code" "$phrase"
fi

if [[ -d "$native_addon/external/gtts" ]]; then
    PYTHONPATH="$native_addon/external" exec python3 -c "$python_code" "$phrase"
fi

printf 'gTTS não está disponível; execute anki-tts-install.sh\n' >&2
exit 1
