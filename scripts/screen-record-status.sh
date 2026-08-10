#!/usr/bin/env bash
set -euo pipefail

if systemctl --user is-active --quiet screen-recorder.service; then
    jq -nc '{text:"󰑋 REC",class:"on",tooltip:"Gravando a tela — clique para encerrar"}'
else
    jq -nc '{text:"",class:"off",tooltip:"Iniciar gravação de tela"}'
fi
