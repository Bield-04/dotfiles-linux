#!/usr/bin/env bash
# Instalador comunitário, não oficial. Leia LEIA-ME-gentoo.md antes de usar.
# amd64, UEFI, systemd, ext4, disco inteiro. Sem dual boot ou criptografia.
set -Eeuo pipefail
umask 077
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
say() { printf '\n>>> %s\n' "$*"; }
ask() { read -r -p "$1" "$2" < /dev/tty || die 'Entrada cancelada.'; }
plan() {
    cat <<'TEXT'
Gentoo base — plano de instalação (nenhum disco foi alterado)

Execute pelo Live USB oficial do Gentoo amd64, iniciado em UEFI.
Requisitos: internet, Secure Boot desativado e disco de pelo menos 32 GiB.

O modo --install pergunta qual disco usar e APAGA O DISCO INTEIRO:
  GPT: EFI FAT32 de 1 GiB + swap de 4 GiB + raiz ext4 no restante.
  Gentoo amd64/glibc/systemd, kernel gentoo-kernel-bin e GRUB UEFI.
  NetworkManager, sudo, nano; idioma pt_BR.UTF-8, teclado br-abnt2.
  Fuso America/Sao_Paulo; usuário e senhas definidos durante a instalação.
  Sem interface gráfica, dual boot, LUKS, RAID ou LVM.

Antes da formatação: valida ambiente, disco, assinatura e SHA-512 do stage3.
Você deve digitar o caminho do disco e depois a frase APAGAR <caminho>.
Não aceita --yes. Não reinicia automaticamente. Não possui retomada automática.

Uso:
  bash instalar-gentoo.sh --plan       Exibe este plano (padrão).
  sudo bash instalar-gentoo.sh --install
TEXT
}

# Funções separadas permitem testar parsers e bloqueios sem executar a instalação.
valid_hostname() { [[ $1 =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; }
valid_user() {
    [[ $1 =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] &&
        [[ ! $1 =~ ^(root|portage|nobody|daemon|bin|adm|sys|sync|shutdown|halt|mail|news|uucp|operator|games|ftp|sshd|systemd.*)$ ]]
}
stage_path() {
    awk '$1 ~ /^[0-9]+T[0-9]+Z\/stage3-amd64-systemd-[0-9]+T[0-9]+Z\.tar\.xz$/ {print $1; exit}' "$1"
}
digest_hash() {
    awk -v name="$2" 'length($1)==128 && $1 !~ /[^0-9a-fA-F]/ && $2==name {print tolower($1); exit}' "$1"
}
disk_identity() { lsblk -bdn -o MAJ:MIN,SIZE,MODEL,SERIAL,WWN "$1"; }
check_disk() {
    local disk=$1 node type base mount_info swap_device
    [[ -b $disk && $(lsblk -dn -o TYPE "$disk") == disk ]] || die 'Selecione um disco físico inteiro.'
    [[ $(lsblk -dn -o RO "$disk") == 0 ]] || die 'Disco somente leitura.'
    (( $(blockdev --getsize64 "$disk") >= 34359738368 )) || die 'Disco menor que 32 GiB.'
    # Descendentes montados, swap ativo e dispositivos com holders são recusados.
    # Assim também ficam bloqueados o Live USB montado, RAID, LVM e dm-crypt ativos.
    mount_info=$(lsblk -nr -o MOUNTPOINTS "$disk")
    [[ -z ${mount_info//[[:space:]]/} ]] || die 'Disco em uso: há montagem ou swap. Não desmonto automaticamente.'
    while read -r node type; do
        [[ $type == disk || $type == part ]] || die "Dispositivo mapeado/RAID detectado: $node"
        base=${node##*/}
        if compgen -G "/sys/class/block/$base/holders/*" >/dev/null; then
            die "Dispositivo em uso por outro volume: $node"
        fi
        while read -r swap_device; do
            [[ -z $swap_device ]] && continue
            [[ $(readlink -f "$swap_device") != "$node" ]] || die "Swap ativo: $node"
        done < <(swapon --show --noheadings --raw --output NAME)
    done < <(lsblk -nrpo NAME,TYPE "$disk")
}

WORK='' TARGET='' SUCCESS=0
cleanup() {
    local code=$?
    trap - EXIT
    set +e
    if [[ -n $TARGET ]]; then
        sync
        # Apenas desmonta a árvore privada criada por esta execução; nunca usa -l.
        if mountpoint -q "$TARGET"; then
            umount -R "$TARGET" || printf '\nNão foi possível desmontar tudo em %s. Não reinicie ainda.\n' "$TARGET" >&2
        fi
        rmdir "$TARGET" 2>/dev/null
    fi
    if [[ -n $WORK ]]; then
        printf '\nArquivos de diagnóstico desta execução: %s\n' "$WORK"
    fi
    if (( code != 0 )); then
        printf '\nInstalação interrompida. NÃO execute de novo para retomar: isso formataria novamente.\n' >&2
    elif (( SUCCESS )); then
        printf '\nInstalação concluída. Se não houve erro de desmontagem, desligue e retire o Live USB.\n'
    fi
    exit "$code"
}
fetch() { curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 30 --output "$2" "$1"; }

install_main() {
    (( EUID == 0 )) || die 'Use sudo ou um terminal root do Live USB.'
    [[ -t 0 && -t 1 ]] || die 'Execute em um terminal interativo, sem pipe.'
    [[ $(uname -m) == x86_64 ]] || die 'Somente amd64/x86_64.'
    [[ -d /sys/firmware/efi ]] || die 'Inicie o Live USB em modo UEFI; BIOS legado não é suportado.'
    local cmd rootfs secureboot value disk_input DISK HOST USER_NAME IDENTITY CONFIRM
    local archive relative base actual expected efi root swap jobs memory cpus node number
    for cmd in lsblk blockdev findmnt mount umount mountpoint swapon sgdisk partprobe udevadm \
        mkfs.vfat mkfs.ext4 mkswap blkid curl gpg sha512sum tar xz chroot \
        awk sed grep readlink mktemp df nproc flock od cp install sync uname mv rm mkdir rmdir; do
        command -v "$cmd" >/dev/null || die "Ferramenta ausente no Live USB: $cmd"
    done
    rootfs=$(findmnt -n -o FSTYPE /)
    case $rootfs in
        overlay|squashfs|tmpfs|rootfs|ramfs|aufs) ;;
        *) die 'A raiz não parece de um Live USB. Não execute dentro do sistema instalado.' ;;
    esac
    [[ -r /usr/share/openpgp-keys/gentoo-release.asc ]] || die 'Use uma mídia oficial recente do Gentoo com as chaves de lançamento.'
    secureboot=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
    [[ -r $secureboot ]] || die 'Não foi possível verificar Secure Boot. Verifique o boot UEFI e efivarfs.'
    value=$(od -An -t u1 -j 4 -N 1 "$secureboot")
    [[ ${value//[[:space:]]/} == 0 ]] || die 'Desative Secure Boot no firmware antes de instalar.'
    (( $(awk '/MemTotal:/ {print $2}' /proc/meminfo) >= 3500000 )) || die 'Esta versão exige pelo menos cerca de 4 GB de RAM.'

    plan
    say 'Discos disponíveis — confira tamanho, modelo, serial e montagens'
    lsblk -e 7 -o NAME,PATH,SIZE,TYPE,MODEL,SERIAL,MOUNTPOINTS
    ask 'Caminho completo do disco a APAGAR (sem padrão): ' disk_input
    [[ $disk_input == /dev/* ]] || die 'Caminho inválido.'
    DISK=$(readlink -f -- "$disk_input")
    check_disk "$DISK"

    # Configurações do sistema devem ser legíveis por usuários e serviços.
    umask 022
    IDENTITY=$(disk_identity "$DISK")
    ask 'Nome do computador [gentoo]: ' HOST
    HOST=${HOST:-gentoo}
    valid_hostname "$HOST" || die 'Hostname: letras minúsculas, números e hífen, até 63 caracteres.'
    ask 'Nome do seu usuário (ex.: gabriel): ' USER_NAME
    valid_user "$USER_NAME" || die 'Nome inválido ou reservado. Use letras minúsculas, números, _ e -.'

    mkdir -p /run/lock
    exec 9> /run/lock/instalar-gentoo.lock
    flock -n 9 || die 'Outra execução do instalador está ativa.'
    WORK=$(mktemp -d /var/tmp/gentoo-installer.XXXXXXXX)
    trap cleanup EXIT
    trap 'printf "\nFalha na linha %s.\n" "$LINENO" >&2' ERR
    trap 'exit 130' INT
    trap 'exit 143' TERM
    (( $(df -Pk "$WORK" | awk 'END {print $4}') >= 1572864 )) || die 'É necessário 1,5 GiB livre em /var/tmp para baixar o stage3.'
    base=https://distfiles.gentoo.org/releases/amd64/autobuilds
    say 'Baixando e validando o stage3 ANTES de apagar o disco'
    fetch "$base/latest-stage3-amd64-systemd.txt" "$WORK/latest.txt"
    relative=$(stage_path "$WORK/latest.txt")
    [[ -n $relative ]] || die 'Formato do índice de stage3 mudou. Pare e revise o script.'
    archive=${relative##*/}
    fetch "$base/$relative" "$WORK/$archive"
    fetch "$base/$relative.DIGESTS" "$WORK/$archive.DIGESTS"
    mkdir -m 700 "$WORK/gnupg"
    gpg --homedir "$WORK/gnupg" --batch --import /usr/share/openpgp-keys/gentoo-release.asc
    # WKD do domínio oficial renova chaves expiradas; falha é fatal, sem ignorar assinatura.
    gpg --homedir "$WORK/gnupg" --batch --auto-key-locate clear,nodefault,wkd --locate-keys releng@gentoo.org
    gpg --homedir "$WORK/gnupg" --batch --status-fd 3 --output "$WORK/digests.txt" \
        --decrypt "$WORK/$archive.DIGESTS" 3> "$WORK/gpg-status.txt"
    awk '$1=="[GNUPG:]" && $2=="VALIDSIG" &&
        ($NF=="13EBBDBEDE7A12775DFDB1BABB572E0E2D182910" ||
         $NF=="D99EAC7379A850BCE47DA5F29E6438C817072058") {ok=1}
        END {exit !ok}' "$WORK/gpg-status.txt" || die 'Assinatura não corresponde às chaves Gentoo esperadas. Verifique eventual rotação oficial.'
    expected=$(digest_hash "$WORK/digests.txt" "$archive")
    [[ -n $expected ]] || die 'SHA-512 do stage3 não encontrado no documento assinado.'
    actual=$(sha512sum "$WORK/$archive")
    [[ ${actual%% *} == "$expected" ]] || die 'SHA-512 divergente; nada foi formatado.'
    xz -t "$WORK/$archive"

    say 'ÚLTIMA CONFERÊNCIA: todas as partições deste disco serão destruídas'
    lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS "$DISK"
    printf '\nComputador: %s | Usuário: %s\n' "$HOST" "$USER_NAME"
    ask "Digite exatamente APAGAR $DISK para continuar: " CONFIRM
    [[ $CONFIRM == "APAGAR $DISK" ]] || die 'Confirmação não corresponde. Nada foi formatado.'
    [[ $(disk_identity "$DISK") == "$IDENTITY" ]] || die 'A identificação do disco mudou.'
    check_disk "$DISK"

    say 'Criando GPT, EFI, swap e raiz'
    sgdisk --zap-all "$DISK"
    sgdisk --clear --new=1:0:+1G --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:+4G --typecode=2:8200 --change-name=2:swap \
        --new=3:0:0 --typecode=3:8300 --change-name=3:Gentoo "$DISK"
    partprobe "$DISK"
    udevadm settle --timeout=30
    efi='' swap='' root=''
    while read -r node number; do
        case $number in 1) efi=$node ;; 2) swap=$node ;; 3) root=$node ;; esac
    done < <(lsblk -nrpo NAME,PARTN "$DISK")
    [[ -b $efi && -b $swap && -b $root ]] || die 'Partições não apareceram no kernel.'
    mkfs.vfat -F 32 -n GENTOO_EFI "$efi"
    mkswap -L gentoo-swap "$swap"
    mkfs.ext4 -F -L gentoo-root "$root"
    mkdir -p /mnt
    TARGET=$(mktemp -d /mnt/gentoo-install.XXXXXXXX)
    mount "$root" "$TARGET"
    mount --make-private "$TARGET"
    tar xpf "$WORK/$archive" --xattrs-include='*.*' --numeric-owner -C "$TARGET"
    mkdir -p "$TARGET/efi"
    mount "$efi" "$TARGET/efi"
    mkdir -p "$TARGET/etc/portage/package.use" "$TARGET/etc/portage/package.license"
    cat > "$TARGET/etc/fstab" <<EOF
# Gerado pelo instalador; UUIDs independem da ordem de detecção dos discos.
UUID=$(blkid -s UUID -o value "$root") / ext4 defaults,noatime 0 1
UUID=$(blkid -s UUID -o value "$efi") /efi vfat defaults,umask=0077 0 2
UUID=$(blkid -s UUID -o value "$swap") none swap sw 0 0
EOF
    memory=$(awk '/MemTotal:/ {print int($2/2097152)}' /proc/meminfo)
    cpus=$(nproc)
    jobs=$(( memory < cpus ? memory : cpus ))
    (( jobs >= 1 )) || jobs=1
    cat >> "$TARGET/etc/portage/make.conf" <<EOF

# Instalador: compilações limitadas pela RAM; preserva CFLAGS do stage3.
MAKEOPTS="-j$jobs"
GRUB_PLATFORMS="efi-64"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --getbinpkg=y"
FEATURES="\${FEATURES} binpkg-request-signature"
EOF
    cat > "$TARGET/etc/portage/package.use/installer" <<'EOF'
sys-kernel/installkernel dracut grub -systemd -systemd-boot -uki -ukify -ugrd
sys-kernel/gentoo-kernel-bin initramfs
net-misc/networkmanager tools wifi
EOF
    # Firmware pode exigir licenças de redistribuição; restrito a estes pacotes.
    cat > "$TARGET/etc/portage/package.license/installer-firmware" <<'EOF'
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
sys-firmware/intel-microcode intel-ucode
EOF
    # O binhost do stage3 é preservado. Na ausência de configuração ativa, usa o
    # caminho publicado para o perfil 23.0; perfil desconhecido exige revisão.
    if ! grep -RqsE '^[[:space:]]*sync-uri[[:space:]]*=' "$TARGET/etc/portage/binrepos.conf"; then
        [[ $(readlink "$TARGET/etc/portage/make.profile") == *'/23.0/'* ]] || die 'Perfil mudou; revise o binhost antes de continuar manualmente.'
        [[ ! -f $TARGET/etc/portage/binrepos.conf ]] || mv "$TARGET/etc/portage/binrepos.conf" "$TARGET/etc/portage/binrepos.conf.stage3"
        mkdir -p "$TARGET/etc/portage/binrepos.conf"
        cat > "$TARGET/etc/portage/binrepos.conf/gentoo.conf" <<'EOF'
[gentoo]
priority = 10
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/
EOF
    fi
    cp --dereference /etc/resolv.conf "$WORK/resolv.conf"
    rm -f "$TARGET/etc/resolv.conf"
    cp "$WORK/resolv.conf" "$TARGET/etc/resolv.conf"
    mount -t proc proc "$TARGET/proc"
    mount --rbind /sys "$TARGET/sys"
    mount --make-rslave "$TARGET/sys"
    mount --rbind /dev "$TARGET/dev"
    mount --make-rslave "$TARGET/dev"
    # /run próprio: não expõe sockets de serviços do ambiente live ao chroot.
    mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs "$TARGET/run"

    cat > "$TARGET/root/configurar-gentoo.sh" <<'CHROOT'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "\nFalha na configuração interna, linha %s.\n" "$LINENO" >&2' ERR
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C
export SYSTEMD_OFFLINE=1
source /etc/profile
HOST=$1
USER_NAME=$2
ROOT_UUID=$3
emerge-webrsync
eselect profile show
getuto
emerge --oneshot --getbinpkg --autounmask=n sys-apps/portage
emerge --update --deep --newuse --getbinpkg --autounmask=n @world
emerge --getbinpkg --autounmask=n sys-boot/grub sys-kernel/installkernel \
    sys-kernel/linux-firmware sys-fs/dosfstools sys-fs/e2fsprogs \
    net-misc/networkmanager app-admin/sudo app-editors/nano
if grep -q GenuineIntel /proc/cpuinfo; then
    emerge --getbinpkg --autounmask=n sys-firmware/intel-microcode
fi
printf '%s\n' "$HOST" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOST
EOF
cat > /etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF
locale-gen
printf 'LANG=pt_BR.UTF-8\n' > /etc/locale.conf
printf 'KEYMAP=br-abnt2\n' > /etc/vconsole.conf
ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
printf 'America/Sao_Paulo\n' > /etc/timezone
mkdir -p /etc/dracut.conf.d
printf 'hostonly="no"\n' > /etc/dracut.conf.d/installer.conf
printf 'root=UUID=%s rw\n' "$ROOT_UUID" > /etc/kernel/cmdline
emerge --getbinpkg --autounmask=n sys-kernel/gentoo-kernel-bin

# Cria explicitamente initramfs para cada kernel, sem reutilizar o kernel do Live USB.
found=0
for image in /boot/vmlinuz-*-gentoo-dist; do
    [[ -f $image ]] || continue
    version=${image##*/vmlinuz-}
    [[ -d /lib/modules/$version ]] || { echo 'Módulos do kernel ausentes.' >&2; exit 1; }
    dracut --force --no-hostonly "/boot/initramfs-$version.img" "$version"
    found=1
done
(( found == 1 )) || { echo 'Kernel não encontrado em /boot. Não reinicie.' >&2; exit 1; }
systemctl enable NetworkManager.service
systemctl disable systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
# NetworkManager gravará DNS; evita depender do resolved desabilitado.
mkdir -p /etc/NetworkManager/conf.d
printf '[main]\ndns=default\nrc-manager=file\n' > /etc/NetworkManager/conf.d/10-dns.conf
systemctl disable systemd-resolved.service 2>/dev/null || true
systemctl enable systemd-timesyncd.service
getent passwd "$USER_NAME" >/dev/null && { echo 'Usuário já existe no stage3; pare e revise.' >&2; exit 1; }
useradd -m -G wheel -s /bin/bash "$USER_NAME"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers
printf '\nDefina a senha do root:\n'
passwd root
printf '\nDefina a senha de %s:\n' "$USER_NAME"
passwd "$USER_NAME"
mkdir -p /etc/default
printf '\nGRUB_DISABLE_OS_PROBER=true\n' >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Gentoo --recheck
# Caminho de fallback no próprio disco alvo, útil se o firmware perder a entrada.
grub-install --target=x86_64-efi --efi-directory=/efi --removable --no-nvram --recheck
grub-mkconfig -o /boot/grub/grub.cfg
grub-script-check /boot/grub/grub.cfg
grep -q '^[[:space:]]*linux' /boot/grub/grub.cfg
grep -q '^[[:space:]]*initrd' /boot/grub/grub.cfg
test -s /efi/EFI/Gentoo/grubx64.efi
test -s /efi/EFI/BOOT/BOOTX64.EFI
touch /root/INSTALACAO-CONCLUIDA
CHROOT
    say 'Configurando o Gentoo; downloads e compilações podem demorar'
    chroot "$TARGET" /usr/bin/env -i HOME=/root TERM="${TERM:-linux}" \
        PATH=/usr/sbin:/usr/bin:/sbin:/bin /bin/bash /root/configurar-gentoo.sh \
        "$HOST" "$USER_NAME" "$(blkid -s UUID -o value "$root")"
    [[ -f $TARGET/root/INSTALACAO-CONCLUIDA ]] || die 'Configuração não foi concluída.'
    install -m 600 "$WORK/digests.txt" "$TARGET/root/stage3-digests-verificados.txt"
    SUCCESS=1
    say 'Gentoo instalado. Após iniciar, entre com seu usuário; para Wi-Fi use sudo nmtui.'
}

main() {
    (( $# <= 1 )) || die 'Use somente --plan ou --install.'
    case ${1:---plan} in
        --plan|--help|-h) plan ;;
        --install) install_main ;;
        *) die 'Opção desconhecida. Use --plan ou --install.' ;;
    esac
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
