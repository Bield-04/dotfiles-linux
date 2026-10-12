#!/usr/bin/env bash

# ============================================================
#   AstronyXP Lightweight Rice
#   Linux Mint 22.x + XFCE
#
#   Focado em:
#   - Celeron / CPUs antigas
#   - 4 GB RAM
#   - Intel HD antiga
#   - visual clean e desempenho
# ============================================================

set -u

# ------------------------------------------------------------
# CORES
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

clear

echo -e "${PURPLE}"
cat << 'EOF'
    ___        __                         _  ______
   /   | _____/ /________  ____  __  ____| |/ / __ \
  / /| |/ ___/ __/ ___/ / __ \/ / / / __  / /_/ /
 / ___ (__  ) /_/ /  / /_/ / /_/ / /_/ / ____/
/_/  |_/____/\__/_/   \____/\__, /\__,_/_/
                           /____/

         Lightweight XFCE Rice
EOF
echo -e "${NC}"

echo "Sistema otimizado para hardware antigo."
echo

# ------------------------------------------------------------
# NÃO RODAR COMO ROOT
# ------------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
    error "Não execute este script usando sudo."
    echo
    echo "Use:"
    echo "  ./rice.sh"
    exit 1
fi

# ------------------------------------------------------------
# DIRETÓRIO DE BACKUP
# ------------------------------------------------------------

BACKUP="$HOME/.rice-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP"

info "Backups serão salvos em:"
echo "$BACKUP"
echo

# ------------------------------------------------------------
# BACKUPS
# ------------------------------------------------------------

info "Criando backups..."

[ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$BACKUP/bashrc"

[ -d "$HOME/.config/rofi" ] && cp -r "$HOME/.config/rofi" "$BACKUP/"

[ -d "$HOME/.config/fastfetch" ] && cp -r "$HOME/.config/fastfetch" "$BACKUP/"

ok "Backup concluído."

# ------------------------------------------------------------
# ATUALIZAÇÃO
# ------------------------------------------------------------

echo
info "Atualizando lista de pacotes..."

sudo apt update

# ------------------------------------------------------------
# PACOTES
# ------------------------------------------------------------

echo
info "Instalando programas..."

PACKAGES=(
    fastfetch
    rofi
    papirus-icon-theme
    arc-theme
    fonts-jetbrains-mono
    git
    curl
    htop
    btop
    fzf
    ripgrep
    bat
    neovim
    zram-tools
)

for pkg in "${PACKAGES[@]}"; do

    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg já está instalado."
    else
        info "Instalando $pkg..."
        sudo apt install -y "$pkg" || warn "Não consegui instalar $pkg."
    fi

done

# ------------------------------------------------------------
# EZA
# ------------------------------------------------------------

echo
info "Tentando instalar eza..."

if command -v eza >/dev/null 2>&1; then
    ok "eza já está instalado."

elif apt-cache show eza >/dev/null 2>&1; then
    sudo apt install -y eza

else
    warn "O pacote eza não foi encontrado."
    warn "O sistema continuará normalmente usando ls."
fi

# ------------------------------------------------------------
# XFCE - DESLIGAR COMPOSITOR
# ------------------------------------------------------------

echo
info "Desligando compositor do XFCE..."

if command -v xfconf-query >/dev/null 2>&1; then

    xfconf-query \
        -c xfwm4 \
        -p /general/use_compositing \
        -s false 2>/dev/null || true

    ok "Compositor desligado."

else
    warn "xfconf-query não encontrado."
fi

# ------------------------------------------------------------
# XFCE - TEMA
# ------------------------------------------------------------

echo
info "Configurando tema Arc-Dark..."

if command -v xfconf-query >/dev/null 2>&1; then

    xfconf-query \
        -c xsettings \
        -p /Net/ThemeName \
        -s "Arc-Dark" 2>/dev/null || true

    xfconf-query \
        -c xfwm4 \
        -p /general/theme \
        -s "Arc-Dark" 2>/dev/null || true

    ok "Tema Arc-Dark configurado."
fi

# ------------------------------------------------------------
# XFCE - ÍCONES
# ------------------------------------------------------------

info "Configurando Papirus-Dark..."

xfconf-query \
    -c xsettings \
    -p /Net/IconThemeName \
    -s "Papirus-Dark" 2>/dev/null || true

ok "Ícones configurados."

# ------------------------------------------------------------
# XFCE - FONTE
# ------------------------------------------------------------

info "Configurando JetBrains Mono..."

xfconf-query \
    -c xsettings \
    -p /Gtk/FontName \
    -s "JetBrains Mono 10" 2>/dev/null || true

ok "Fonte configurada."

# ------------------------------------------------------------
# ROFI
# ------------------------------------------------------------

echo
info "Configurando Rofi..."

mkdir -p "$HOME/.config/rofi"

cat > "$HOME/.config/rofi/config.rasi" << 'EOF'
configuration {
    modi: "drun,run";
    show-icons: true;
    display-drun: "Apps";
    drun-display-format: "{name}";
    matching: "fuzzy";
}

* {
    font: "JetBrains Mono 11";

    bg: #111111;
    bg-alt: #181818;
    fg: #eeeeee;
    selected: #444444;

    background-color: transparent;
    text-color: @fg;
}

window {
    width: 550px;
    border: 1px;
    border-color: #555555;
    border-radius: 6px;
    background-color: @bg;
}

mainbox {
    padding: 15px;
    background-color: @bg;
}

inputbar {
    padding: 10px;
    spacing: 10px;
    background-color: @bg-alt;
}

prompt {
    text-color: @fg;
}

entry {
    text-color: @fg;
}

listview {
    lines: 7;
    columns: 1;
    spacing: 4px;
    margin: 10px 0px 0px;
    scrollbar: false;
}

element {
    padding: 8px;
    spacing: 10px;
    border-radius: 4px;
}

element selected {
    background-color: @selected;
}

element-text {
    text-color: inherit;
}

element-icon {
    size: 24px;
}
EOF

ok "Rofi configurado."

# ------------------------------------------------------------
# ATALHO SUPER + SPACE
# ------------------------------------------------------------

echo
info "Criando atalho Super + Espaço para o Rofi..."

xfconf-query \
    -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Super>space" \
    -n \
    -t string \
    -s "rofi -show drun" 2>/dev/null || true

ok "Atalho configurado: SUPER + SPACE"

# ------------------------------------------------------------
# FASTFETCH
# ------------------------------------------------------------

echo
info "Configurando Fastfetch..."

mkdir -p "$HOME/.config/fastfetch"

cat > "$HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",

    "logo": {
        "type": "small"
    },

    "display": {
        "separator": "  "
    },

    "modules": [
        "title",
        "separator",

        {
            "type": "os",
            "key": "OS"
        },

        {
            "type": "host",
            "key": "PC"
        },

        {
            "type": "kernel",
            "key": "Kernel"
        },

        {
            "type": "uptime",
            "key": "Uptime"
        },

        {
            "type": "packages",
            "key": "Packages"
        },

        {
            "type": "shell",
            "key": "Shell"
        },

        {
            "type": "display",
            "key": "Display"
        },

        {
            "type": "de",
            "key": "DE"
        },

        {
            "type": "wm",
            "key": "WM"
        },

        {
            "type": "theme",
            "key": "Theme"
        },

        {
            "type": "icons",
            "key": "Icons"
        },

        {
            "type": "terminal",
            "key": "Terminal"
        },

        {
            "type": "cpu",
            "key": "CPU"
        },

        {
            "type": "gpu",
            "key": "GPU"
        },

        {
            "type": "memory",
            "key": "RAM"
        },

        {
            "type": "disk",
            "key": "Disk"
        }
    ]
}
EOF

ok "Fastfetch configurado."

# ------------------------------------------------------------
# BASH
# ------------------------------------------------------------

echo
info "Configurando Bash..."

# Remove configuração antiga deste script
sed -i '/# ===== ASTRONYXP RICE START =====/,/# ===== ASTRONYXP RICE END =====/d' "$HOME/.bashrc"

cat >> "$HOME/.bashrc" << 'EOF'


# ===== ASTRONYXP RICE START =====

# -----------------------------
# AstronyXP Lightweight Shell
# -----------------------------

# LS moderno, caso eza esteja instalado

if command -v eza >/dev/null 2>&1; then

    alias ls='eza --icons'
    alias ll='eza -lah --icons --group-directories-first'
    alias la='eza -a --icons'
    alias tree='eza --tree --icons'

else

    alias ll='ls -lah'
    alias la='ls -A'

fi


# Bat

if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --paging=never'
elif command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi


# Utilidades

alias grep='grep --color=auto'

alias update='sudo apt update && sudo apt upgrade'

alias cls='clear'

alias ff='fastfetch'

alias nv='nvim'


# Prompt leve

PS1='\[\e[38;5;39m\]\u\[\e[0m\]@\[\e[38;5;141m\]\h\[\e[0m\] \[\e[38;5;245m\]\w\[\e[0m\]\n❯ '


# ===== ASTRONYXP RICE END =====
EOF

ok "Bash configurado."

# ------------------------------------------------------------
# ZRAM
# ------------------------------------------------------------

echo
info "Configurando ZRAM..."

if [ -f /etc/default/zramswap ]; then

    sudo cp /etc/default/zramswap \
        "$BACKUP/zramswap.backup" 2>/dev/null || true

fi

sudo tee /etc/default/zramswap >/dev/null << 'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

sudo systemctl enable zramswap.service >/dev/null 2>&1 || true

sudo systemctl restart zramswap.service >/dev/null 2>&1 || true

ok "ZRAM configurado."

# ------------------------------------------------------------
# SERVIÇOS PESADOS OPCIONAIS
# ------------------------------------------------------------

echo
info "Verificando serviços desnecessários..."

# Bluetooth:
# Não desativamos automaticamente porque o usuário pode usar.
#
# Para desativar:
#
# sudo systemctl disable --now bluetooth

# ------------------------------------------------------------
# LIMPEZA
# ------------------------------------------------------------

echo
info "Limpando pacotes desnecessários..."

sudo apt autoremove -y

sudo apt clean

ok "Limpeza concluída."

# ------------------------------------------------------------
# RESULTADO ZRAM
# ------------------------------------------------------------

echo
info "Swap / ZRAM:"

swapon --show || true

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}              RICE INSTALADO COM SUCESSO!                  ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo

echo -e "${CYAN}Atalhos:${NC}"
echo
echo "SUPER + SPACE     Abrir Rofi"
echo
echo "ff                Fastfetch"
echo "ll                Listar arquivos"
echo "nv                Neovim"
echo "btop              Monitor do sistema"
echo "update            Atualizar sistema"
echo

echo -e "${CYAN}Configurações:${NC}"
echo
echo "Tema:       Arc-Dark"
echo "Ícones:     Papirus-Dark"
echo "Fonte:      JetBrains Mono"
echo "Launcher:   Rofi"
echo "Compositor: OFF"
echo "ZRAM:       ON"
echo

echo -e "${YELLOW}Backup:${NC}"
echo "$BACKUP"
echo

echo -e "${PURPLE}Agora faça logout e login novamente.${NC}"
echo
echo "Ou reinicie:"
echo
echo "    reboot"
echo
