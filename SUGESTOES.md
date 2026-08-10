# Melhorias incorporadas ao ambiente

As sugestões abaixo foram implementadas em 8 de agosto de 2026. Elas ficam
neste arquivo como registro das decisões e dos componentes necessários para
reproduzir o ambiente.

## Prioridade alta

1. **Módulos `privacy`, `idle_inhibitor` e `power-profiles-daemon` no Waybar.**
   A barra agora indica compartilhamento/microfone, permite inibir o Hypridle e
   alterna entre os perfis de energia disponíveis.

2. **`hyprsunset`.** Perfis nativos alternam entre a identidade às 07:00 e
   4500 K às 19:00; o botão no Eww também oferece alternância manual.

3. **OSD de volume e brilho com `wob`.** Um FIFO gerenciado pelo systemd recebe
   os valores dos wrappers de `wpctl` e `brightnessctl`.

4. **`hyprpolkitagent`.** O agente nativo substituiu o agente MATE na sessão e
   está sob supervisão do systemd de usuário.

## Fluxos úteis

5. **Anotação de screenshots com `swappy`.** `Super+Print` captura uma região e
   abre o editor; os atalhos Print existentes continuam rápidos.

6. **Gravação de tela com `wf-recorder`.** `Super+Alt+R` seleciona uma área,
   grava H.264/FLAC em `~/Videos/Recordings` e sinaliza o estado no Waybar.

7. **`udiskie` para mídia removível.** Automount, notificações, LUKS e ícone de
   tray estão ativos.

8. **Atalho para `hyprpicker`.** `Super+Shift+C` copia a cor hexadecimal e
   notifica o resultado.

## Widgets do Eww

9. **Cartão de clipboard.** O dashboard mostra os seis itens mais recentes,
   permite copiá-los e oferece remoção individual.

10. **Sliders de áudio e brilho.** Ajustam PipeWire e backlight diretamente e
    mostram saída, mute e microfone.

11. **Quick toggles reativos.** Wi-Fi, Bluetooth, DND e luz noturna usam estado
    real e classes visuais `on/off`.

12. **Atualizações por eventos.** Mídia e áudio usam streams contínuos; brilho
    usa `inotify`, evitando polling por segundo.

## Mudança estrutural

13. **UWSM + serviços systemd de usuário.** Waybar, Mako, Eww, awww, agentes e
    utilitários agora são unidades supervisionadas. A sessão atual usa o target
    de compatibilidade; no próximo login, a entrada **Hyprland (UWSM)** entrega
    também o ciclo de vida do compositor ao UWSM.

14. **Plugins somente quando houver uma necessidade concreta.** Esta política
    foi mantida: nenhum plugin arbitrário foi carregado no compositor. Plugins
    precisam acompanhar o ABI exato do Hyprland; quando houver um caso de uso,
    use `hyprpm`, revise o código e não misture pacotes `-git` com o stack do
    Tumbleweed.

## Agenda e agentes

15. **Agenda unificada e moderna.** DankCalendar agrega Google e Outlook
    pessoal com OAuth, usa Microsoft Graph, mantém sincronização/lembretes em
    segundo plano e alimenta os próximos compromissos do Eww por IPC. Seu tema
    escuro combina com o restante do desktop. Merkuro e KOrganizer/Akonadi
    ficam como fallbacks; Proton permanece no navegador por não oferecer
    CalDAV bidirecional.

16. **Menu de agentes locais.** `Super+G` inicia o Codex em uma pasta e com o
    menor sandbox apropriado. Alterações fora do workspace continuam exigindo
    elevação/aprovação; não há atalho para acesso irrestrito silencioso.

## Estudos integrados

17. **Study Hub no Anki.** Waybar e Eww mostram a carga diária e abrem
    diretamente Kubernetes, NVIDIA/GPU em Kubernetes ou francês. Sessenta
    notas iniciais curadas convivem com os baralhos existentes, e
    `Super+Shift+A` inicia a sessão completa.

18. **Francês com áudio verificável.** As frases iniciais recebem MP3 cacheado,
    com HyperTTS como fallback. O template legado que apontava para
    `AwesomeTTS` é salvo e migrado para o identificador atual `HyperTTS`; um
    diagnóstico testa versão, templates e síntese sem reproduzir som.

19. **Agente de estudos com limites explícitos.** O menu de agentes ganhou um
    perfil que consulta o AnkiConnect local autenticado. Edições em massa,
    templates e exclusões exigem confirmação, e acesso SQLite direto é
    proibido pelo próprio prompt do perfil.

## Música

20. **Spotify confiável com interface alternativa.** O cliente oficial mantém
    login, biblioteca e reprodução confiáveis, enquanto Spicetify aplica o
    layout Sleek/Catppuccin e oferece um Marketplace visual. A implantação
    Flatpak do usuário evita `sudo`; `Super+M`, Eww e um StatusNotifier próprio
    abrem o cliente e controlam MPRIS. A bandeja mostra faixa/artista e oferece
    play/pause, anterior, próxima, shuffle, repeat e cópia do link. Versões e
    downloads usados na personalização são fixados e verificados por SHA-256.
