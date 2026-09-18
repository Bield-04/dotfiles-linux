#!/usr/bin/env bash
# Aplicativos do Gabriel para o Arch Linux, incluindo C#/.NET e ferramentas
# de apoio ao LazyVim. A configuracao e o tema do Neovim ficam a seu criterio.
# Execute depois de iniciar o Arch instalado, com seu usuario normal:
#   bash instalar-apps-arch.sh
#
# Esta etapa instala os aplicativos. A configuracao de Btrfs, snapshots,
# GRUB, kernels e zram sera feita separadamente, conforme a instalacao.

set -euo pipefail

if (( EUID == 0 )); then
    printf 'Execute com seu usuario normal: bash instalar-apps-arch.sh\n' >&2
    printf 'O proprio script usa sudo quando necessario.\n' >&2
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    printf 'Este script foi preparado para o Arch Linux.\n' >&2
    exit 1
fi

# --needed evita reinstalar pacotes que ja estao na mesma versao.
# -Syu atualiza o sistema inteiro junto com a instalacao dos aplicativos.
printf '\nAtualizando o Arch e instalando os pacotes dos repositorios...\n'
sudo pacman -Syu --needed \
    firefox \
    fastfetch \
    neovim \
    wine \
    mousepad \
    vlc \
    vlc-plugin-ffmpeg \
    alacritty \
    flameshot \
    gwenview \
    git \
    base-devel \
    go \
    dotnet-sdk \
    ripgrep \
    fd \
    fzf \
    tree-sitter-cli \
    curl \
    unzip

# dotnet-sdk fornece as ferramentas para criar, compilar e executar C#.
# ripgrep/fd/fzf ajudam nas buscas do editor; tree-sitter-cli e o compilador
# C de base-devel permitem compilar os parsers. curl e unzip sao usados
# por plugins e instaladores de ferramentas. O LazyVim e seus extras sao
# configurados dentro do Neovim; este script prepara os pacotes do sistema.

# Instala o Yay somente se ele ainda nao estiver disponivel.
# A pasta de compilacao fica no disco e tem um nome exclusivo.
if ! command -v yay >/dev/null 2>&1; then
    printf '\nInstalando o Yay...\n'
    mkdir -p "$HOME/.cache"
    yay_build_dir=$(mktemp -d "$HOME/.cache/arch-yay.XXXXXX")

    # Remove apenas a pasta temporaria criada nesta execucao.
    trap 'rm -rf -- "$yay_build_dir"' EXIT

    git clone https://aur.archlinux.org/yay.git "$yay_build_dir/yay"
    (
        cd "$yay_build_dir/yay"
        # makepkg precisa ser executado com usuario normal.
        makepkg -si
    )
fi

# Estes aplicativos estao no AUR. O Yay cuida das dependencias.
printf '\nInstalando DeaDBeeF e Hydra Launcher pelo AUR...\n'
yay -S --needed deadbeef hydra-launcher-bin

printf '\nInstalacao dos aplicativos concluida.\n'
