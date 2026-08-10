#!/usr/bin/env bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
fifo="$runtime_dir/wob.sock"

if [[ -e "$fifo" && ! -p "$fifo" ]]; then
    printf 'recusando substituir caminho que não é FIFO: %s\n' "$fifo" >&2
    exit 1
fi

[[ -p "$fifo" ]] || mkfifo -m 600 "$fifo"

# Abrir o FIFO para leitura e escrita mantém a entrada viva entre atualizações.
exec 3<>"$fifo"
exec wob <&3
