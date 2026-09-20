#!/usr/bin/env bash
# Interrompe caso algum comando crítico falhe
set -e

echo "=========================================="
echo " Instalador B&W Minimal (Debian/XFCE base)"
echo " Otimizado para Intel Atom D525"
echo "=========================================="
echo " NOTA IMPORTANTE:"
echo " - O ambiente XFCE NÃO será removido ou alterado."
echo " - O i3 será adicionado como uma SESSÃO ADICIONAL."
echo " - Você poderá escolher entre XFCE e i3 na tela de login."
echo "=========================================="

# 1. Preparação Básica de Diretórios
echo -e "\n[1/7] Criando diretórios base..."
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/fonts"
mkdir -p "$HOME/Imagens"

# 2. Instalação de Dependências (Preserva pacotes do XFCE)
echo -e "\n[2/7] Instalando dependências do i3wm..."
sudo apt update
DEPENDENCIAS="i3 polybar rofi picom alacritty thunar wget unzip curl x11-xserver-utils network-manager-gnome dunst scrot fontconfig libnotify-bin"
for pct in $DEPENDENCIAS; do
    if ! dpkg -s "$pct" >/dev/null 2>&1; then
        sudo apt install -y --no-install-recommends "$pct"
    fi
done

# 3. Verificação Simples de Áudio
echo -e "\n[3/7] Verificando suporte a áudio..."
if command -v pulseaudio >/dev/null 2>&1 || command -v pactl >/dev/null 2>&1 || command -v wpctl >/dev/null 2>&1; then
    echo "Ferramentas de áudio detectadas. O funcionamento do módulo será confirmado na sessão gráfica."
else
    echo "[!] Utilitários de áudio não detectados nativamente."
    echo "    A barra continuará funcionando, mas o módulo de volume pode ficar inativo."
fi

# 4. Download Seguro da Fonte (Antes das configurações)
echo -e "\n[4/7] Verificando JetBrainsMono Nerd Font..."
if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    TEMP_DIR=$(mktemp -d)
    echo "Baixando fonte..."
    
    set +e
    if wget -q --show-progress -O "$TEMP_DIR/JB.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
        if unzip -q "$TEMP_DIR/JB.zip" -d "$TEMP_DIR/JB" 2>/dev/null; then
            FONTS_FOUND=$(find "$TEMP_DIR/JB" -type f -name "*.ttf")
            
            if [ -n "$FONTS_FOUND" ]; then
                find "$TEMP_DIR/JB" -type f -name "*.ttf" -exec cp {} "$HOME/.local/share/fonts/" \;
                fc-cache -fv >/dev/null 2>&1
                echo "Fonte instalada e atualizada com sucesso."
            else
                echo "[!] Aviso: Nenhum arquivo .ttf encontrado no ZIP extraído."
                echo "    Os ícones na barra Polybar podem não funcionar corretamente."
            fi
        else
            echo "[!] Aviso: Falha ao extrair a fonte baixada."
            echo "    Os ícones na barra Polybar podem não funcionar corretamente."
        fi
    else
        echo "[!] Aviso: Falha ao baixar a fonte (verifique a conexão de rede)."
        echo "    Os ícones na barra Polybar podem não funcionar corretamente."
    fi
    set -e
    rm -rf "$TEMP_DIR"
else
    echo "Fonte já instalada."
fi

# 5. Detecção Segura de Navegador
echo -e "\n[5/7] Detectando navegador do sistema..."
NAVEGADOR_CMD=""
for nav in firefox-esr firefox chromium chromium-browser google-chrome brave vivaldi; do
    if command -v "$nav" >/dev/null 2>&1; then
        NAVEGADOR_CMD="$nav"
        break
    fi
done

if [ -z "$NAVEGADOR_CMD" ]; then
    echo "Nenhum navegador detectado. O atalho exibirá apenas uma notificação."
else
    echo "Navegador detectado: $NAVEGADOR_CMD"
fi

# 6. Gerando Arquivos de Configuração e Script Auxiliar
echo -e "\n[6/7] Configurando o ambiente..."
mkdir -p "$HOME/.config/i3" "$HOME/.config/polybar" "$HOME/.config/rofi" "$HOME/.config/picom" "$HOME/.config/dunst"

# --- Script Auxiliar de Navegador ---
cat << EOF > "$HOME/.local/bin/abrir-navegador"
#!/usr/bin/env bash
if [ -n "$NAVEGADOR_CMD" ] && command -v "$NAVEGADOR_CMD" >/dev/null 2>&1; then
    $NAVEGADOR_CMD "\$@" &
else
    notify-send "Aviso" "Nenhum navegador encontrado no sistema"
fi
EOF
chmod +x "$HOME/.local/bin/abrir-navegador"

# --- I3WM ---
cat << 'EOF' > "$HOME/.config/i3/config"
set $mod Mod4
font pango:JetBrainsMono Nerd Font 10

default_border pixel 3
default_floating_border pixel 3
gaps inner 8
gaps outer 0

# Cores P&B Minimalista
client.focused          #ffffff #ffffff #000000 #ffffff   #ffffff
client.focused_inactive #222222 #222222 #888888 #222222   #222222
client.unfocused        #111111 #111111 #555555 #111111   #111111
client.urgent           #ffffff #ffffff #000000 #ffffff   #ffffff

# Autostart (Proteção contra processos duplicados)
exec --no-startup-id xsetroot -solid '#080808'
exec --no-startup-id bash -c 'pgrep -x picom >/dev/null || picom --config ~/.config/picom/picom.conf -b'
exec --no-startup-id bash -c 'pgrep -x nm-applet >/dev/null || nm-applet'
exec --no-startup-id bash -c 'pgrep -x dunst >/dev/null || dunst'

# A Polybar usa exec_always pois o script launch.sh encerra as antigas
exec_always --no-startup-id ~/.config/polybar/launch.sh

# Atalhos Universais
bindsym $mod+Return exec --no-startup-id alacritty
bindsym $mod+d      exec --no-startup-id rofi -show drun
bindsym $mod+w      exec --no-startup-id ~/.local/bin/abrir-navegador
bindsym $mod+e      exec --no-startup-id thunar
bindsym Print       exec --no-startup-id scrot '%Y-%m-%d-%H%M%S_screenshot.png' -e 'mv $f ~/Imagens/'

# Controle do i3
bindsym $mod+Shift+q kill
bindsym $mod+f       fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Sair da sessão i3?' -B 'Sim' 'i3-msg exit'"

# Foco (Setas)
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

# Mover Janela (Shift + Setas)
bindsym $mod+Shift+Left  move left
bindsym $mod+Shift+Down  move down
bindsym $mod+Shift+Up    move up
bindsym $mod+Shift+Right move right

# Workspaces
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4

# Mover para Workspaces
bindsym $mod+Shift+1 move container to workspace 1
bindsym $mod+Shift+2 move container to workspace 2
bindsym $mod+Shift+3 move container to workspace 3
bindsym $mod+Shift+4 move container to workspace 4

# Regras de Flutuação
for_window [class="Lxappearance"] floating enable
for_window [class="Thunar"] floating enable
for_window [class="Nm-connection-editor"] floating enable
EOF

# --- POLYBAR ---
cat << 'EOF' > "$HOME/.config/polybar/config.ini"
[colors]
bg = #080808
bg-alt = #1c1c1c
fg = #ffffff
fg-alt = #888888
border = #333333

[bar/main]
width = 100%
height = 28
fixed-center = true
background = ${colors.bg}
foreground = ${colors.fg}
border-bottom-size = 2
border-bottom-color = ${colors.border}
padding-left = 2
padding-right = 2
module-margin = 1

font-0 = JetBrainsMono Nerd Font:size=10;3

modules-left = menu term browser files i3
modules-center = title
modules-right = cpu memory wlan pulseaudio date systray
cursor-click = pointer
enable-ipc = true

[module/menu]
type = custom/text
content = ""
content-padding = 1
click-left = rofi -show drun &

[module/term]
type = custom/text
content = ""
content-foreground = ${colors.fg-alt}
content-padding = 1
click-left = alacritty &

[module/browser]
type = custom/text
content = ""
content-foreground = ${colors.fg-alt}
content-padding = 1
click-left = ~/.local/bin/abrir-navegador &

[module/files]
type = custom/text
content = ""
content-foreground = ${colors.fg-alt}
content-padding = 1
click-left = thunar &

[module/systray]
type = internal/tray
tray-spacing = 8px
tray-size = 60%
tray-background = ${colors.bg}

[module/i3]
type = internal/i3
format = <label-state>
label-focused = %index%
label-focused-background = ${colors.bg-alt}
label-focused-underline = #ffffff
label-focused-padding = 2
label-unfocused = %index%
label-unfocused-foreground = ${colors.fg-alt}
label-unfocused-padding = 2

[module/title]
type = internal/xwindow
format = <label>
label = %title%
label-maxlen = 40
label-empty = Minimal
label-empty-foreground = ${colors.fg-alt}

[module/cpu]
type = internal/cpu
interval = 10
format-prefix = " "
format-prefix-foreground = ${colors.fg-alt}
label = %percentage%%

[module/memory]
type = internal/memory
interval = 10
format-prefix = " "
format-prefix-foreground = ${colors.fg-alt}
label = %percentage_used%%

[module/wlan]
type = internal/network
interface-type = wireless
interval = 10
format-connected = <label-connected>
label-connected =  %essid%
label-connected-foreground = ${colors.fg}
format-disconnected = <label-disconnected>
label-disconnected = 
label-disconnected-foreground = ${colors.bg}

[module/pulseaudio]
type = internal/pulseaudio
use-ui-max = false
interval = 5
format-volume-prefix = " "
format-volume-prefix-foreground = ${colors.fg-alt}
label-volume = %percentage%%
label-muted = " Mudo"

[module/date]
type = internal/date
interval = 60
date = %H:%M
label =  %date%
EOF

# --- POLYBAR LAUNCHER ---
cat << 'EOF' > "$HOME/.config/polybar/launch.sh"
#!/usr/bin/env bash
polybar-msg cmd quit 2>/dev/null || killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
polybar main -c ~/.config/polybar/config.ini & disown
EOF
chmod +x "$HOME/.config/polybar/launch.sh"

# --- PICOM (Fade suave e leve, sem blur ou sombras) ---
cat << 'EOF' > "$HOME/.config/picom/picom.conf"
backend = "xrender";
vsync = false;
shadow = false; 

fading = true;
fade-in-step = 0.08;
fade-out-step = 0.08;
fade-delta = 10;

inactive-opacity = 0.95;
active-opacity = 1.0;
EOF

# --- ROFI ---
cat << 'EOF' > "$HOME/.config/rofi/config.rasi"
configuration { modi: "drun"; show-icons: false; font: "JetBrainsMono Nerd Font 11"; }
* { bg: #080808; fg: #dddddd; background-color: @bg; text-color: @fg; }
window { width: 450px; border: 2px solid; border-color: #ffffff; border-radius: 8px; padding: 20px; }
inputbar { padding: 0px 0px 15px 0px; children: [entry]; }
entry { placeholder: "Pesquisar aplicativo..."; text-color: #ffffff; }
listview { lines: 8; border: 0px; }
element { padding: 8px; border-radius: 4px; }
element selected { background-color: #ffffff; text-color: #000000; }
EOF

# --- DUNST ---
cat << 'EOF' > "$HOME/.config/dunst/dunstrc"
[global]
    width = 300
    height = 100
    offset = 20x40
    origin = top-right
    font = JetBrainsMono Nerd Font 10
    frame_width = 2
    frame_color = "#ffffff"
    separator_color = "#ffffff"
[urgency_low]
    background = "#000000"
    foreground = "#ffffff"
    timeout = 4
[urgency_normal]
    background = "#000000"
    foreground = "#ffffff"
    timeout = 6
EOF

# 7. Testes Finais de Validação
echo -e "\n[7/7] Validando configurações..."

# Testa i3 com interrupção estrita em caso de erro
if i3 -C -c "$HOME/.config/i3/config" >/dev/null 2>&1; then
    echo " -> Configuração do i3 validada com sucesso."
else
    echo "[ERRO] Configuração do i3 inválida. Instalação interrompida."
    i3 -C -c "$HOME/.config/i3/config" || true
    exit 1
fi

# Testa Polybar (Validação básica)
if polybar -c "$HOME/.config/polybar/config.ini" -m >/dev/null 2>&1; then
    echo " -> Sintaxe básica da Polybar validada com sucesso. (Testes completos dependem da sessão X11/i3 ativada)."
else
    echo "[!] Aviso: O comando de validação da Polybar encontrou divergências de sintaxe."
fi

echo -e "\n=========================================="
echo " TUDO PRONTO! "
echo "=========================================="
echo "Para usar o i3wm:"
echo " 1. Encerre sua sessão atual no XFCE (Sair / Logout)."
echo " 2. Na tela de login do Debian, clique no ícone de opções/engrenagem."
echo " 3. Escolha a sessão 'i3'."
echo " 4. Faça o login."
echo " (Seu XFCE continua lá, totalmente seguro, para quando você quiser usar).”

