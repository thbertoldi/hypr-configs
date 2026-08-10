#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

if ! command -v codex >/dev/null 2>&1; then
    notify-send -a Hyprland -u critical \
        'Agente indisponível' \
        'Codex CLI não está instalado. Execute o bootstrap ou instale @openai/codex.'
    exit 1
fi

launch_agent() {
    local workdir=$1 sandbox=$2 approval=$3
    shift 3
    exec "$script_dir/app-launch.sh" \
        ghostty --working-directory="$workdir" -e \
        codex -C "$workdir" --sandbox "$sandbox" --ask-for-approval "$approval" "$@"
}

if ! codex login status >/dev/null 2>&1; then
    notify-send -a Hyprland 'Autenticação do agente' \
        'Conclua o login no terminal; o navegador será aberto pelo Codex.'
    exec "$script_dir/app-launch.sh" ghostty -e codex login
fi

if [[ "${1:-}" == study ]]; then
    choice='Estudos — criar/revisar flashcards'
else
    choice=$(
        printf '%s\n' \
            'Hyprland — editar esta configuração' \
            'Agenda — planejar com um agente' \
            'Estudos — criar/revisar flashcards' \
            'Pasta/projeto — escolher diretório' \
            'Desktop — editar ~/.config' \
            'Computador — somente inspecionar' \
            'Retomar uma conversa' \
            'Diagnóstico do Codex' \
            | fuzzel --dmenu --prompt='Agentes › ' --width=48
    ) || exit 0
fi

case "$choice" in
    'Hyprland — editar esta configuração')
        launch_agent "$HOME/.config/hypr" workspace-write on-request
        ;;
    'Agenda — planejar com um agente')
        launch_agent "$HOME" read-only on-request \
            'Ajude-me a organizar a agenda do DankCalendar. Consulte calendários e eventos com ~/.config/hypr/scripts/dcal.sh ipc calendars.list e ~/.config/hypr/scripts/dcal.sh ipc events.list from=DATA_RFC3339 to=DATA_RFC3339; se ele não estiver disponível, consulte o Akonadi com konsolekalendar. Antes de criar, alterar ou excluir qualquer compromisso, apresente a ação exata e peça minha confirmação explícita; não tente contornar o sandbox. Google e Outlook pessoal podem ser geridos no DankCalendar; Proton Calendar deve ser aberto somente pela web.'
        ;;
    'Estudos — criar/revisar flashcards')
        launch_agent "$HOME/.config/hypr" workspace-write on-request \
            'Ajude-me a estudar com o Anki, especialmente Kubernetes, NVIDIA/GPU em Kubernetes e francês. Use somente a API local autenticada pelos scripts ~/.config/hypr/scripts/anki-connect.sh e ~/.config/hypr/scripts/study-*.sh; nunca edite o banco SQLite do Anki diretamente. Você pode inspecionar baralhos, notas e estatísticas livremente. Antes de adicionar em massa, alterar templates, substituir conteúdo ou excluir qualquer nota/baralho, mostre a ação exata e peça minha confirmação explícita. Preserve os baralhos importados e prefira cartões atômicos, verificáveis e com fonte primária.'
        ;;
    'Pasta/projeto — escolher diretório')
        workdir=$(kdialog --getexistingdirectory "$HOME") || exit 0
        [[ -d "$workdir" ]] || exit 0
        launch_agent "$workdir" workspace-write on-request
        ;;
    'Desktop — editar ~/.config')
        launch_agent "$HOME/.config" workspace-write on-request
        ;;
    'Computador — somente inspecionar')
        launch_agent "$HOME" read-only on-request
        ;;
    'Retomar uma conversa')
        exec "$script_dir/app-launch.sh" ghostty -e codex resume
        ;;
    'Diagnóstico do Codex')
        exec "$script_dir/app-launch.sh" ghostty -e bash -lc \
            'codex doctor --summary; printf "\nPressione Enter para fechar..."; read -r'
        ;;
esac
