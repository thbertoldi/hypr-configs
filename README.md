# Hyprland no openSUSE Tumbleweed

Esta configuração usa Hyprland 0.55+ em Lua, com Waybar, Fuzzel, Mako, Eww,
awww, Hyprlock/Hypridle, Ghostty e wlogout. O visual é Catppuccin Mocha com
acentos peach/maroon. Os componentes persistentes são supervisionados por
serviços systemd de usuário; UWSM gerencia o ciclo completo da sessão quando
ela é iniciada pela entrada **Hyprland (UWSM)**.

## Melhorias ativas

- Waybar com privacidade, inibidor de ociosidade, perfil de energia e indicador
  de gravação;
- dashboard Eww reativo com mídia, áudio, brilho, clipboard e quick toggles;
- temperatura noturna automática pelo `hyprsunset` (07:00/19:00) e alternância
  manual no Eww;
- OSD de volume e brilho pelo `wob`;
- agente de autorização `hyprpolkitagent` e montagem de mídia pelo `udiskie`;
- captura anotável com Swappy e gravação H.264/FLAC com `wf-recorder`;
- seleção de cor, configuração visual de monitores e monitor de sistema.

## Atalhos acrescentados

| Atalho | Ação |
|---|---|
| `Super+Print` | capturar uma região e abrir no Swappy |
| `Super+Alt+R` | iniciar/parar gravação de uma região |
| `Super+Shift+C` | copiar uma cor em hexadecimal com Hyprpicker |
| `Super+Ctrl+M` | abrir o NWG Displays |
| `Super+Ctrl+B` | abrir o btop no Ghostty |
| `Super+W` | abrir/fechar o dashboard Eww |
| `Super+O` | abrir a agenda moderna no DankCalendar |
| `Super+G` | abrir o menu de agentes locais |

As teclas físicas de áudio e brilho agora também exibem o OSD. `Print`,
`Shift+Print` e `Ctrl+Print` continuam sendo os fluxos rápidos de screenshot.

## Agenda integrada

O **DankCalendar** é a interface principal. Ele oferece visual escuro moderno,
modos dia/semana/mês/agenda e reúne Google e Outlook pessoal no mesmo banco
local. O relógio da Waybar, `Super+O` e o botão **Agenda** do Eww o abrem; o
dashboard consulta sua API local e mostra até cinco compromissos dos próximos
14 dias. No Hyprland, a janela abre flutuante, centralizada e proporcional ao
monitor. O serviço `dankcalendar.service` mantém sincronização e lembretes
ativos mesmo quando a janela está escondida.

Adicione as contas no painel **Accounts** da própria agenda ou pelo terminal:

```bash
~/.config/hypr/scripts/dcal.sh account add google
~/.config/hypr/scripts/dcal.sh account add microsoft
```

- **Google Calendar** usa OAuth no navegador;
- **Outlook pessoal** usa OAuth e Microsoft Graph. O clique do meio no relógio
  e o botão direito em **Agenda** continuam oferecendo o Outlook Web no
  navegador padrão;
- **Proton Calendar** permanece no navegador pelo botão Proton ou clique
  direito no relógio, pois não fornece sincronização CalDAV bidirecional.

O portal `Secret` do Flatpak foi ligado ao KWallet. Assim, tokens OAuth e
senhas ficam no cofre do sistema e nunca entram neste diretório ou no
bootstrap. As contas devem ser autenticadas novamente em outra máquina.

O Merkuro permanece instalado como fallback estável, com tema KDE escuro, e
pode ser aberto por `~/.config/hypr/scripts/calendar-open.sh merkuro`. O
KOrganizer/Akonadi continua disponível no modo `classic`; sua integração EWS
não é usada para Outlook, pois a retirada do EWS no Exchange Online começa em
outubro de 2026.

## Agentes locais

`Super+G` abre um menu para iniciar o Codex no Ghostty. Há perfis para esta
configuração, a agenda, uma pasta escolhida, todo `~/.config` ou inspeção somente leitura.
Os modos editáveis usam `workspace-write` com aprovação `on-request`; nenhuma
opção do menu desabilita sandbox e aprovações. No primeiro uso em outra máquina,
execute `codex login` ou simplesmente abra o menu e conclua o login no terminal.

## Reproduzir em outro computador

Transfira **todo este diretório**, pois o script depende de `lua/`, `scripts/`
e `portable/`. Por exemplo, a partir deste computador:

```bash
rsync -a ~/.config/hypr/ usuario@outro-computador:~/hypr-bootstrap/
```

No computador de destino:

```bash
cd ~/hypr-bootstrap
chmod +x bootstrap-opensuse-tumbleweed.sh
./bootstrap-opensuse-tumbleweed.sh --dry-run
./bootstrap-opensuse-tumbleweed.sh \
  --with-extras \
  --wallpaper ~/Pictures/meu-wallpaper.jpg \
  --avatar ~/Pictures/meu-avatar.jpeg
```

O instalador:

- confirma que o sistema é openSUSE Tumbleweed;
- instala as dependências pelos repositórios da distribuição e o DankCalendar
  oficial pelo Flathub;
- baixa fontes/temas de fontes oficiais, em versões e checksums fixados;
- cria backup datado em `~/.local/state/hypr-bootstrap/backups/`;
- instala Hyprland e os arquivos auxiliares em `~/.config/`;
- usa um perfil genérico de monitor no primeiro boot;
- valida scripts, JSON e a configuração com `Hyprland --verify-config`.

Use `--same-hardware` somente se o destino também tiver o mesmo LG ultrawide e
painel `eDP-1`. Para um painel interno com outro nome, use, por exemplo,
`--internal-output eDP-2`.

O wallpaper e o avatar atuais não ficam neste repositório. Eles podem ser
fornecidos pelas opções acima ou colocados em `assets/` conforme o README de lá.
Perfis VPN, chaves, credenciais, conteúdo do KWallet, Handy e `smarty-pants` não
são copiados. O mesmo vale para contas de agenda e autenticação do Codex.

## Opções úteis

```text
--with-extras     instala também o utilitário de diagnóstico de eventos `wev`
--skip-packages   instala apenas os arquivos de configuração
--skip-themes     não baixa Catppuccin, Bibata nem JetBrains Mono Nerd Font
--dry-run         mostra as alterações sem executá-las
```

O instalador já habilita os serviços de usuário, o OSD, o dashboard ampliado e
os fluxos de captura/gravação. No primeiro login, escolha **Hyprland (UWSM)**,
execute `hyprctl monitors` e ajuste
`~/.config/hypr/lua/monitors.lua`. Veja [SUGESTOES.md](SUGESTOES.md) para o
registro das melhorias incorporadas e da política adotada para plugins.
