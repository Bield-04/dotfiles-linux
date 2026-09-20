#!/usr/bin/env bash
# D525 GRAPHITE — instalador autocontido para Debian 12/13.
# Execute como seu usuario normal: bash rice-i3-debian-d525.sh
# As configuracoes completas estao incorporadas no final deste arquivo.
set -Eeuo pipefail

usage() {
    cat <<'HELP'
D525 GRAPHITE | Debian 12/13 | i3

Uso:
  bash rice-i3-debian-d525.sh
  bash rice-i3-debian-d525.sh --sem-pacotes
  bash rice-i3-debian-d525.sh --sem-audio
  bash rice-i3-debian-d525.sh --extrair DIRETORIO_NOVO
  bash rice-i3-debian-d525.sh --restaurar DIRETORIO_DO_BACKUP

O padrao instala o Xorg, i3, barra, menu, terminal, notificacoes,
bloqueio, gerenciador de arquivos de terminal e audio, quando ausente.
--sem-pacotes: aplica somente o rice, exigindo dependencias instaladas.
--sem-audio: nao instala um servidor de audio novo; mantem o existente.
--extrair: grava todas as configuracoes em uma pasta nova, sem instalar.
--restaurar: recupera as configuracoes guardadas no backup indicado.

Use seu usuario normal. Somente o APT pedira acesso de administrador.
A meta de 600 MB se refere ao sistema ocioso; nao e uma garantia.
HELP
}

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
info() { printf '\n%s\n' "$*"; }
stage_dir=''
backup_dir=''
cleanup() {
    if [[ -n "$stage_dir" && -d "$stage_dir" ]]; then
        rm -rf -- "$stage_dir"
    fi
}
trap cleanup EXIT
trap 'printf "\nFalha na linha %s. Nenhuma reinicializacao foi feita.\nBackup, se criado: %s\n" "$LINENO" "${backup_dir:-ainda nao criado}" >&2' ERR

write_payload() {
    local out=$1
    mkdir -p -- "$out"/.config/i3
    cat > "$out"/.config/i3/config <<'D525_PAYLOAD_00_END'
# D525 GRAPHITE | Debian 12/13 | i3 >= 4.22
# Configuracao completa. Super = tecla Windows.
set $mod Mod4
font pango:DejaVu Sans Mono 9
floating_modifier $mod
default_border pixel 2
default_floating_border normal 2
hide_edge_borders smart
gaps inner 6
gaps outer 2
smart_gaps on
focus_follows_mouse no
workspace_auto_back_and_forth yes
popup_during_fullscreen smart

#                           borda    fundo    texto    indicador borda-filho
client.focused              #9CB6A3 #293B33 #F1F4F2 #9CB6A3 #9CB6A3
client.focused_inactive     #36413C #1B2220 #AEBBB3 #36413C #36413C
client.unfocused            #29302E #171C1A #7F8D84 #29302E #29302E
client.urgent               #D39C84 #6A4438 #FFFFFF #D39C84 #D39C84
client.placeholder          #29302E #171C1A #AEBBB3 #29302E #29302E
client.background           #111518

# Programas abertos somente por atalho.
bindsym $mod+Return exec --no-startup-id xterm
bindsym $mod+d exec --no-startup-id dmenu_run -i -fn 'DejaVu Sans Mono-10' -nb '#171C1A' -nf '#CFD8D1' -sb '#9CB6A3' -sf '#111518' -p 'abrir >'
bindsym $mod+e exec --no-startup-id xterm -T Arquivos -e mc
bindsym $mod+Shift+m exec --no-startup-id xterm -T Monitor -e htop
bindsym $mod+F1 exec --no-startup-id xterm -T Atalhos -e "$HOME/.local/share/i3-graphite/bin/atalhos"
bindsym $mod+F2 exec --no-startup-id xterm -T Memoria -e "$HOME/.local/share/i3-graphite/bin/medir-ram" --pausa
bindsym $mod+Shift+q kill

# Foco, setas ou HJKL.
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Disposicao das janelas.
bindsym $mod+b split h
bindsym $mod+v split v
bindsym $mod+f fullscreen toggle
bindsym $mod+w layout tabbed
bindsym $mod+s layout stacking
bindsym $mod+Shift+e layout toggle split
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent
bindsym $mod+Shift+minus move scratchpad
bindsym $mod+minus scratchpad show

set $ws1 "1:term"
set $ws2 "2:code"
set $ws3 "3:web"
set $ws4 "4:files"
set $ws5 "5:misc"
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Tab workspace back_and_forth

bindsym $mod+r mode "redimensionar: setas / HJKL | Enter para sair"
mode "redimensionar: setas / HJKL | Enter para sair" {
    bindsym h resize shrink width 10 px or 10 ppt
    bindsym j resize grow height 10 px or 10 ppt
    bindsym k resize shrink height 10 px or 10 ppt
    bindsym l resize grow width 10 px or 10 ppt
    bindsym Left resize shrink width 10 px or 10 ppt
    bindsym Down resize grow height 10 px or 10 ppt
    bindsym Up resize shrink height 10 px or 10 ppt
    bindsym Right resize grow width 10 px or 10 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+x exec --no-startup-id i3lock --color=111518
bindsym $mod+Shift+p exec --no-startup-id "$HOME/.local/share/i3-graphite/bin/sessao"
bindsym XF86AudioRaiseVolume exec --no-startup-id "$HOME/.local/share/i3-graphite/bin/volume" up
bindsym XF86AudioLowerVolume exec --no-startup-id "$HOME/.local/share/i3-graphite/bin/volume" down
bindsym XF86AudioMute exec --no-startup-id "$HOME/.local/share/i3-graphite/bin/volume" mute

# Nao inicia programas de outros desktops via dex/autostart.
exec_always --no-startup-id "$HOME/.local/share/i3-graphite/bin/aplicar-tema"
exec --no-startup-id dunst -config "$HOME/.config/i3-graphite/dunstrc"
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork --color=111518

bar {
    position top
    status_command exec i3status -c "$HOME/.config/i3-graphite/i3status.conf"
    font pango:DejaVu Sans Mono 9
    strip_workspace_numbers no
    workspace_buttons yes
    binding_mode_indicator yes
    tray_output none
    separator_symbol " / "
    colors {
        background #111518
        statusline #CFD8D1
        separator #536359
        focused_workspace #9CB6A3 #9CB6A3 #111518
        active_workspace #36413C #26352D #CFD8D1
        inactive_workspace #111518 #111518 #7F8D84
        urgent_workspace #D39C84 #6A4438 #FFFFFF
        binding_mode #D39C84 #6A4438 #FFFFFF
    }
}
D525_PAYLOAD_00_END
    chmod 644 "$out"/.config/i3/config
    mkdir -p -- "$out"/.config/i3-graphite
    cat > "$out"/.config/i3-graphite/Xresources <<'D525_PAYLOAD_01_END'
! D525 GRAPHITE | Recursos aplicados somente ao xterm.
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 10
XTerm*renderFont: true
XTerm*utf8: 1
XTerm*locale: true
XTerm*saveLines: 2000
XTerm*scrollBar: false
XTerm*internalBorder: 14
XTerm*borderWidth: 0
XTerm*background: #171C1A
XTerm*foreground: #CFD8D1
XTerm*cursorColor: #9CB6A3
XTerm*cursorBlink: false
XTerm*highlightColor: #364A3E
XTerm*highlightTextColor: #F1F4F2
XTerm*bellIsUrgent: true
XTerm*visualBell: true
XTerm*metaSendsEscape: true
XTerm*selectToClipboard: true
XTerm*allowWindowOps: false
XTerm*color0: #202724
XTerm*color1: #C28F7E
XTerm*color2: #9CB6A3
XTerm*color3: #C8B98B
XTerm*color4: #8EA8B5
XTerm*color5: #AAA0B9
XTerm*color6: #91B6AD
XTerm*color7: #C3CEC6
XTerm*color8: #65776B
XTerm*color9: #DAAA98
XTerm*color10: #BDD0BE
XTerm*color11: #DFCEA1
XTerm*color12: #B0C9D5
XTerm*color13: #C4BBD1
XTerm*color14: #B4D1C8
XTerm*color15: #F1F4F2
XTerm*VT100.Translations: #override \n\
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \n\
    Ctrl <Key>plus: larger-vt-font() \n\
    Ctrl <Key>minus: smaller-vt-font()
D525_PAYLOAD_01_END
    chmod 644 "$out"/.config/i3-graphite/Xresources
    mkdir -p -- "$out"/.config/i3-graphite
    cat > "$out"/.config/i3-graphite/dunstrc <<'D525_PAYLOAD_02_END'
[global]
    width = 300
    height = 160
    origin = top-right
    offset = 12x38
    notification_limit = 3
    font = DejaVu Sans 9
    frame_width = 2
    frame_color = "#536359"
    separator_height = 1
    padding = 10
    horizontal_padding = 12
    corner_radius = 0
    icon_position = off
    format = "<b>%s</b>\n%b"
    idle_threshold = 120
[urgency_low]
    background = "#171C1A"
    foreground = "#CFD8D1"
    timeout = 4
[urgency_normal]
    background = "#171C1A"
    foreground = "#CFD8D1"
    timeout = 6
[urgency_critical]
    background = "#392923"
    foreground = "#F1F4F2"
    frame_color = "#D39C84"
    timeout = 0
D525_PAYLOAD_02_END
    chmod 644 "$out"/.config/i3-graphite/dunstrc
    mkdir -p -- "$out"/.config/i3-graphite
    cat > "$out"/.config/i3-graphite/i3status.conf <<'D525_PAYLOAD_03_END'
general {
    output_format = "i3bar"
    colors = true
    interval = 5
    color_good = "#9CB6A3"
    color_degraded = "#D6BD87"
    color_bad = "#D39C84"
}
order += "ethernet _first_"
order += "cpu_usage"
order += "memory"
order += "tztime local"

ethernet _first_ {
    format_up = "LAN on"
    format_down = "LAN off"
}
cpu_usage {
    format = "CPU %usage"
}
memory {
    format = "RAM %used"
    memory_used_method = "memavailable"
    unit = "Mi"
    decimals = 0
    threshold_degraded = "10%"
    threshold_critical = "5%"
}
tztime local {
    format = "%d/%m  %H:%M"
}
D525_PAYLOAD_03_END
    chmod 644 "$out"/.config/i3-graphite/i3status.conf
    mkdir -p -- "$out"/.local/share/i3-graphite/bin
    cat > "$out"/.local/share/i3-graphite/bin/aplicar-tema <<'D525_PAYLOAD_04_END'
#!/bin/sh
# Cada comando termina; nao fica um processo de wallpaper executando.
xsetroot -solid '#111518' -cursor_name left_ptr
xrdb -nocpp -merge "$HOME/.config/i3-graphite/Xresources"
setxkbmap -model abnt2 -layout br
xset b off
# xss-lock bloqueia quando o protetor de tela dispara, aos 10 minutos.
xset s 600 600
xset dpms 600 900 1200 2>/dev/null || true
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY 2>/dev/null || true
fi
D525_PAYLOAD_04_END
    chmod 755 "$out"/.local/share/i3-graphite/bin/aplicar-tema
    mkdir -p -- "$out"/.local/share/i3-graphite/bin
    cat > "$out"/.local/share/i3-graphite/bin/atalhos <<'D525_PAYLOAD_05_END'
#!/bin/sh
cat <<'TEXT'

  D525 / GRAPHITE
  Debian + i3 | atalhos

  Super = tecla Windows

  Super + Enter             Terminal
  Super + D                 Abrir programa pelo nome
  Super + E                 Arquivos (Midnight Commander)
  Super + Shift + M         Monitor de processos
  Super + F1                Esta ajuda
  Super + F2                Medir RAM do sistema
  Super + Shift + Q         Fechar janela

  Super + 1 ... 5           Trocar de area de trabalho
  Super + Shift + 1 ... 5   Mover janela para outra area
  Super + setas / HJKL      Trocar foco
  Super + Shift + setas     Mover janela
  Super + B / V             Proxima divisao horizontal / vertical
  Super + W                 Janelas em abas
  Super + Shift + E         Voltar para divisao lado a lado
  Super + F                 Tela cheia
  Super + R                 Redimensionar; Enter encerra
  Super + Shift + Espaco    Alternar janela flutuante

  Ctrl + Shift + C / V      Copiar / colar no xterm
  Super + Shift + C         Recarregar configuracao
  Super + Shift + R         Reiniciar o i3 sem fechar os apps
  Super + Shift + X         Bloquear tela
  Super + Shift + P         Menu de sessao

  A tela bloqueia apos 10 minutos de inatividade.
  Digite sua senha e Enter para desbloquear.
  No gerenciador de arquivos: Tab troca painel; F10 sai.

TEXT
printf 'Enter para fechar.'
read -r _answer || true
D525_PAYLOAD_05_END
    chmod 755 "$out"/.local/share/i3-graphite/bin/atalhos
    mkdir -p -- "$out"/.local/share/i3-graphite/bin
    cat > "$out"/.local/share/i3-graphite/bin/medir-ram <<'D525_PAYLOAD_06_END'
#!/bin/sh
set -eu
printf '\nD525 GRAPHITE | MEDICAO REAL DE MEMORIA\n\n'
awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { available = $2; found = 1 }
    END {
        if (!found) { print "MemAvailable indisponivel."; exit 1 }
        used_bytes = (total - available) * 1024
        printf "Sistema inteiro: %.1f MB (%.1f MiB) usados\n", used_bytes / 1000000, used_bytes / 1048576
        printf "Criterio: MemTotal - MemAvailable, incluindo esta sessao.\n"
        printf "Meta em repouso: 600 MB decimais (aprox. 572 MiB).\n"
        if (used_bytes <= 600000000)
            print "Resultado desta amostra: DENTRO da meta."
        else
            print "Resultado desta amostra: ACIMA da meta."
    }
' /proc/meminfo
printf '\nMemoria e swap (MB decimais):\n'
free --mega
printf '\nMaiores processos por RSS (KiB; memoria compartilhada pode se repetir):\n'
LC_ALL=C ps -eo pid,comm,rss --sort=-rss | sed -n '1,16p'
printf '\nMeça apos 2 minutos de login, com os aplicativos fechados.\n'
printf 'O terminal e este medidor tambem entram na conta.\n'
if [ "${1:-}" = --completo ]; then
    printf '\nServicos de sistema ativos:\n'
    systemctl --no-pager --type=service --state=running || true
    printf '\nServicos do usuario ativos:\n'
    systemctl --user --no-pager --type=service --state=running || true
fi
if [ "${1:-}" = --pausa ]; then
    printf '\nEnter para fechar.'
    read -r _answer || true
fi
D525_PAYLOAD_06_END
    chmod 755 "$out"/.local/share/i3-graphite/bin/medir-ram
    mkdir -p -- "$out"/.local/share/i3-graphite/bin
    cat > "$out"/.local/share/i3-graphite/bin/sessao <<'D525_PAYLOAD_07_END'
#!/bin/sh
set -eu
choose() {
    dmenu -i -fn 'DejaVu Sans Mono-10' -nb '#171C1A' -nf '#CFD8D1' \
        -sb '#9CB6A3' -sf '#111518' -p "$1"
}
choice=$(printf 'Bloquear\nSair do i3\nReiniciar\nDesligar\n' | choose 'sessao >') || exit 0
case "$choice" in
    Bloquear) exec i3lock --color=111518 ;;
    'Sair do i3'|Reiniciar|Desligar)
        answer=$(printf 'Cancelar\nConfirmar\n' | choose "$choice ?") || exit 0
        [ "$answer" = Confirmar ] || exit 0
        case "$choice" in
            'Sair do i3') i3-msg exit ;;
            Reiniciar) systemctl reboot ;;
            Desligar) systemctl poweroff ;;
        esac || notify-send 'Sessao' 'A operacao falhou. Consulte o terminal.'
        ;;
esac
D525_PAYLOAD_07_END
    chmod 755 "$out"/.local/share/i3-graphite/bin/sessao
    mkdir -p -- "$out"/.local/share/i3-graphite/bin
    cat > "$out"/.local/share/i3-graphite/bin/volume <<'D525_PAYLOAD_08_END'
#!/bin/sh
set -eu
action=${1:-}
case "$action" in up|down|mute) ;; *) exit 2 ;; esac

# Usa o servidor de audio que ja estiver respondendo.
if command -v wpctl >/dev/null 2>&1 && wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
    case "$action" in
        up) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
        down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
elif command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    case "$action" in
        up) pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
        down) pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
        mute) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
    esac
else
    case "$action" in
        up) amixer -q sset Master 5%+ ;;
        down) amixer -q sset Master 5%- ;;
        mute) amixer -q sset Master toggle ;;
    esac
fi
D525_PAYLOAD_08_END
    chmod 755 "$out"/.local/share/i3-graphite/bin/volume
    mkdir -p -- "$out"/.
    cat > "$out"/.xinitrc <<'D525_PAYLOAD_09_END'
#!/bin/sh
# O Xsession do Debian prepara D-Bus, recursos X e ambiente da sessao.
exec /etc/X11/Xsession /usr/bin/i3
D525_PAYLOAD_09_END
    chmod 755 "$out"/.xinitrc
}

skip_packages=false
skip_audio=false
extract_dir=''
restore_dir=''
while (($#)); do
    case "$1" in
        --sem-pacotes) skip_packages=true; shift ;;
        --sem-audio) skip_audio=true; shift ;;
        --extrair)
            (($# >= 2)) || die 'Falta o diretorio para --extrair.'
            extract_dir=$2; shift 2 ;;
        --restaurar)
            (($# >= 2)) || die 'Falta o diretorio para --restaurar.'
            restore_dir=$2; shift 2 ;;
        --ajuda|--help|-h) usage; exit 0 ;;
        *) die "Opcao desconhecida: $1. Use --ajuda." ;;
    esac
done
[[ -z "$extract_dir" || -z "$restore_dir" ]] || die 'Escolha extrair ou restaurar.'

if [[ -n "$extract_dir" ]]; then
    [[ ! -e "$extract_dir" && ! -L "$extract_dir" ]] || die 'A pasta de extracao ja existe. Escolha uma pasta nova.'
    mkdir -p -- "$extract_dir"
    write_payload "$extract_dir"
    info "Configuracoes completas extraidas em: $extract_dir"
    exit 0
fi

((EUID != 0)) || die 'Execute como seu usuario normal, sem sudo antes de bash. O instalador pede a senha quando precisar.'
[[ -n "${HOME:-}" && "$HOME" = /* && "$HOME" != / ]] || die 'Diretorio pessoal invalido.'
[[ -d "$HOME" && -w "$HOME" ]] || die 'Seu diretorio pessoal nao permite escrita.'
[[ "${XDG_CONFIG_HOME:-$HOME/.config}" = "$HOME/.config" ]] || die 'XDG_CONFIG_HOME personalizado: use --extrair e adapte os caminhos antes de instalar.'

# Lista fechada de destinos. O backup nao pode indicar arquivos arbitrarios.
allowed_target() {
    case "$1" in
        .config/i3/config|.i3/config|.config/i3-graphite/i3status.conf|.config/i3-graphite/Xresources|.config/i3-graphite/dunstrc|.local/share/i3-graphite/bin/aplicar-tema|.local/share/i3-graphite/bin/volume|.local/share/i3-graphite/bin/sessao|.local/share/i3-graphite/bin/medir-ram|.local/share/i3-graphite/bin/atalhos|.xinitrc) return 0 ;;
        *) return 1 ;;
    esac
}

# Evita escrever atraves de diretorios simbolicos. Arquivos simbolicos
# individuais sao guardados como links e podem ser restaurados depois.
check_parent() {
    local relative=$1 parent=$HOME part
    local -a parts
    IFS='/' read -r -a parts <<< "$relative"
    unset 'parts[-1]'
    for part in "${parts[@]}"; do
        parent+="/$part"
        [[ ! -L "$parent" ]] || die "Pasta simbolica encontrada: $parent. Use --extrair para adaptar manualmente."
        [[ ! -e "$parent" || -d "$parent" ]] || die "Um arquivo ocupa o lugar de uma pasta: $parent"
    done
}

if [[ -n "$restore_dir" ]]; then
    [[ -d "$restore_dir/files" && -f "$restore_dir/manifest.tsv" ]] || die 'Backup incompleto ou inexistente.'
    [[ "$(cat "$restore_dir/usuario-home.txt")" = "$HOME" ]] || die 'O backup pertence a outro diretorio pessoal.'
    declare -a restored_paths=() restored_states=()
    while IFS=$'\t' read -r state relative; do
        [[ "$state" = presente || "$state" = ausente ]] || die 'Manifesto de backup invalido.'
        allowed_target "$relative" || die 'O backup contem um destino inesperado.'
        check_parent "$relative"
        [[ ! -d "$HOME/$relative" || -L "$HOME/$relative" ]] || die "O destino virou uma pasta: $relative"
        if [[ "$state" = presente ]]; then
            [[ -f "$restore_dir/files/$relative" || -L "$restore_dir/files/$relative" ]] || die "Falta um arquivo no backup: $relative"
        fi
        restored_paths+=("$relative")
        restored_states+=("$state")
    done < "$restore_dir/manifest.tsv"
    ((${#restored_paths[@]})) || die 'O manifesto esta vazio.'
    check_parent '.local/state/i3-graphite-backups/novo'
    mkdir -p -- "$HOME/.local/state/i3-graphite-backups"
    backup_dir=$(mktemp -d "$HOME/.local/state/i3-graphite-backups/pre-restauracao-XXXXXXXX")
    mkdir -- "$backup_dir/files"
    printf '%s\n' "$HOME" > "$backup_dir/usuario-home.txt"
    : > "$backup_dir/manifest.tsv"
    for relative in "${restored_paths[@]}"; do
        if [[ -e "$HOME/$relative" || -L "$HOME/$relative" ]]; then
            mkdir -p -- "$backup_dir/files/$(dirname -- "$relative")"
            cp -a -- "$HOME/$relative" "$backup_dir/files/$relative"
            printf 'presente\t%s\n' "$relative" >> "$backup_dir/manifest.tsv"
        else
            printf 'ausente\t%s\n' "$relative" >> "$backup_dir/manifest.tsv"
        fi
    done
    for i in "${!restored_paths[@]}"; do
        relative=${restored_paths[$i]}
        rm -f -- "$HOME/$relative"
        if [[ "${restored_states[$i]}" = presente ]]; then
            mkdir -p -- "$HOME/$(dirname -- "$relative")"
            cp -a -- "$restore_dir/files/$relative" "$HOME/$relative"
        fi
    done
    info "Configuracoes restauradas. Estado anterior a restauracao salvo em: $backup_dir"
    info 'Encerre a sessao e entre novamente. Os pacotes instalados foram mantidos.'
    exit 0
fi

[[ -r /etc/os-release ]] || die 'Nao foi possivel identificar o sistema.'
# shellcheck source=/dev/null
. /etc/os-release
[[ "${ID:-}" = debian ]] || die 'Este instalador foi preparado para Debian 12/13.'
case "${VERSION_ID:-}" in
    12|13) ;;
    *) die 'Versao nao coberta: use Debian 12 ou 13, ou --extrair para instalar manualmente.' ;;
esac

stage_dir=$(mktemp -d)
write_payload "$stage_dir"
declare -a targets=(
    .config/i3/config
    .config/i3-graphite/i3status.conf
    .config/i3-graphite/Xresources
    .config/i3-graphite/dunstrc
    .local/share/i3-graphite/bin/aplicar-tema
    .local/share/i3-graphite/bin/volume
    .local/share/i3-graphite/bin/sessao
    .local/share/i3-graphite/bin/medir-ram
    .local/share/i3-graphite/bin/atalhos
    .xinitrc
)
# ~/.i3/config tem precedencia no i3. Mantemos uma copia igual se ja existir.
if [[ -e "$HOME/.i3/config" || -L "$HOME/.i3/config" ]]; then
    mkdir -p -- "$stage_dir/.i3"
    cp -- "$stage_dir/.config/i3/config" "$stage_dir/.i3/config"
    targets+=(.i3/config)
fi
for relative in "${targets[@]}"; do
    check_parent "$relative"
    [[ ! -d "$HOME/$relative" || -L "$HOME/$relative" ]] || die "O destino e uma pasta: $relative"
done
check_parent '.local/state/i3-graphite-backups/novo'

admin() {
    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v su >/dev/null 2>&1; then
        local command_line
        printf -v command_line '%q ' "$@"
        su -s /bin/bash -c "$command_line"
    else
        die 'Nao encontrei sudo nem su para instalar os pacotes.'
    fi
}
is_installed() {
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" = 'install ok installed' ]]
}

if ! $skip_packages; then
    declare -a packages=(
        xserver-xorg xserver-xorg-core xserver-xorg-video-intel
        xserver-xorg-input-libinput xinit xauth x11-xserver-utils x11-xkb-utils
        dbus-user-session libpam-systemd
        i3-wm i3status suckless-tools xterm xfonts-base fonts-dejavu-core
        dunst libnotify-bin i3lock xss-lock alsa-utils mc htop nano procps
    )
    if ! $skip_audio && ! is_installed pulseaudio && ! is_installed pipewire-pulse; then
        packages+=(pipewire-audio)
    fi
    info 'Instalando os pacotes oficiais. O APT mostrara o que vai instalar.'
    info 'Sem sudo instalado, su pedira a senha de root; com sudo, a do seu usuario.'
    admin apt-get update
    # --no-remove aborta se a resolucao exigir remover pacotes existentes.
    admin apt-get install --no-install-recommends --no-remove "${packages[@]}"
fi

for executable in i3 i3status dmenu_run dmenu xterm xrdb xsetroot xset setxkbmap startx dunst notify-send i3lock xss-lock amixer mc htop nano free ps timeout; do
    command -v "$executable" >/dev/null 2>&1 || die "Falta o comando $executable. Instale os pacotes antes de aplicar o rice."
done
[[ -x /usr/bin/Xorg ]] || die 'O servidor Xorg nao esta instalado.'
[[ -r /etc/X11/Xsession ]] || die 'Falta /etc/X11/Xsession.'
i3_version=$(i3 --version | awk '{print $3}')
dpkg --compare-versions "$i3_version" ge 4.22 || die 'Esta configuracao requer i3 4.22 ou posterior.'

info 'Validando as configuracoes antes de substituir qualquer arquivo...'
if ! i3 -C -c "$stage_dir/.config/i3/config" > "$stage_dir/i3-check.log" 2>&1; then
    cat "$stage_dir/i3-check.log" >&2
    die 'O i3 rejeitou a configuracao. Os arquivos anteriores continuam intactos.'
fi
status_rc=0
timeout 2s i3status -c "$stage_dir/.config/i3-graphite/i3status.conf" > "$stage_dir/status.json" 2> "$stage_dir/status.log" || status_rc=$?
if [[ "$status_rc" -ne 124 && "$status_rc" -ne 0 ]]; then
    cat "$stage_dir/status.log" >&2
    die 'O i3status rejeitou a configuracao. Os arquivos anteriores continuam intactos.'
fi
[[ -s "$stage_dir/status.json" ]] || die 'O i3status nao gerou dados. Nenhuma configuracao foi substituida.'

mkdir -p -- "$HOME/.local/state/i3-graphite-backups"
backup_dir=$(mktemp -d "$HOME/.local/state/i3-graphite-backups/$(date +%Y%m%d-%H%M%S)-XXXXXXXX")
mkdir -- "$backup_dir/files"
printf '%s\n' "$HOME" > "$backup_dir/usuario-home.txt"
: > "$backup_dir/manifest.tsv"
for relative in "${targets[@]}"; do
    if [[ -e "$HOME/$relative" || -L "$HOME/$relative" ]]; then
        mkdir -p -- "$backup_dir/files/$(dirname -- "$relative")"
        cp -a -- "$HOME/$relative" "$backup_dir/files/$relative"
        printf 'presente\t%s\n' "$relative" >> "$backup_dir/manifest.tsv"
    else
        printf 'ausente\t%s\n' "$relative" >> "$backup_dir/manifest.tsv"
    fi
done

# Escrita em arquivo temporario + rename: nao altera o alvo de links antigos.
for relative in "${targets[@]}"; do
    destination="$HOME/$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    temporary=$(mktemp "$(dirname -- "$destination")/.graphite-XXXXXXXX")
    cp -- "$stage_dir/$relative" "$temporary"
    case "$relative" in
        .xinitrc|.local/share/i3-graphite/bin/*) chmod 755 "$temporary" ;;
        *) chmod 644 "$temporary" ;;
    esac
    mv -Tf -- "$temporary" "$destination"
done

info 'D525 GRAPHITE instalado.'
printf 'Backup: %s\n' "$backup_dir"
printf '\nNo console local, entre com seu usuario e execute: startx\n'
printf 'Se ja ha uma tela de login, escolha a sessao i3 e entre novamente.\n'
printf 'Super+Enter: terminal | Super+D: menu | Super+F1: atalhos | Super+F2: RAM\n'
printf '\nA meta de 600 MB depende dos servicos e aplicativos ativos.\n'
printf 'Depois de entrar, aguarde 2 minutos e meça com Super+F2.\n'
printf 'Para desfazer as configuracoes:\n  bash rice-i3-debian-d525.sh --restaurar %q\n' "$backup_dir"
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet display-manager.service; then
    printf '\nHa um gerenciador de login ativo; ele tambem consome memoria.\n'
fi
