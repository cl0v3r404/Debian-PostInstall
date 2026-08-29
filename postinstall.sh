#!/bin/bash
#
# postinstall.sh — Script de post-instalación para Debian (KDE Plasma y/o GNOME)
# Compatible con Debian 12 (Bookworm), 13 (Trixie), etc.
# El debloat de cada escritorio se aplica solo si ese escritorio está instalado.
#
# Debe ejecutarse como root (sudo ./postinstall.sh)

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root. Usa: sudo $0"
    exit 1
fi

# Se obtiene el codename desde /etc/os-release en vez de lsb_release,
# ya que el paquete lsb-release no siempre está presente (p. ej. en
# algunas instalaciones live/netinst mínimas).
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

if [ -z "$CODENAME" ]; then
    echo "No se pudo determinar el codename de la distro desde /etc/os-release."
    exit 1
fi

# ---------------------------------------------------------------------------
# Detección de entorno
# ---------------------------------------------------------------------------

# Detecta qué entorno de escritorio hay instalado, para aplicar el debloat
# correspondiente (KDE Plasma y/o GNOME; ambos si el sistema tiene los dos)
HAS_KDE=false
HAS_GNOME=false
if dpkg -l plasma-desktop 2>/dev/null | grep -q "^ii" || dpkg -l task-kde-desktop 2>/dev/null | grep -q "^ii"; then
    HAS_KDE=true
fi
if dpkg -l gnome-shell 2>/dev/null | grep -q "^ii" || dpkg -l task-gnome-desktop 2>/dev/null | grep -q "^ii"; then
    HAS_GNOME=true
fi

# Detecta fabricante de CPU para el microcode correspondiente
CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
case "$CPU_VENDOR" in
    GenuineIntel)
        MICROCODE_PKG="intel-microcode"
        ;;
    AuthenticAMD)
        MICROCODE_PKG="amd64-microcode"
        ;;
    *)
        echo "→ Fabricante de CPU no reconocido ($CPU_VENDOR), omitiendo microcode."
        MICROCODE_PKG=""
        ;;
esac

echo "→ Entorno detectado: codename=$CODENAME, cpu=$CPU_VENDOR, kde=$HAS_KDE, gnome=$HAS_GNOME"
echo

# ---------------------------------------------------------------------------
# 1. Repositorios: contrib, non-free, non-free-firmware, backports, multimedia
# ---------------------------------------------------------------------------

echo "→ Instalando dependencias básicas (wget, curl, gnupg)..."
apt update
apt install -y wget curl gnupg

echo "→ Configurando /etc/apt/sources.list (main, contrib, non-free, non-free-firmware)..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian $CODENAME-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $CODENAME-updates main contrib non-free non-free-firmware
EOF

echo "→ Agregando repositorio de backports (archivo separado)..."
cat <<EOF > /etc/apt/sources.list.d/backports.list
deb http://deb.debian.org/debian $CODENAME-backports main contrib non-free non-free-firmware
EOF

echo "→ Agregando repositorio deb-multimedia (archivo separado)..."
cat <<EOF > /etc/apt/sources.list.d/dmo.list
deb https://www.deb-multimedia.org $CODENAME main non-free
EOF

echo "→ Descargando e instalando keyring de deb-multimedia..."
# Se resuelve el nombre del paquete dinámicamente para evitar depender
# de una versión fija que quede desactualizada.
DMO_KEYRING_URL=$(wget -qO- https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/ \
    | grep -oE 'deb-multimedia-keyring_[0-9.]+_all\.deb' | sort -V | tail -n1)

if [ -n "$DMO_KEYRING_URL" ]; then
    wget -P /tmp "https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/$DMO_KEYRING_URL"
    dpkg -i "/tmp/$DMO_KEYRING_URL" || apt install -f -y
else
    echo "⚠ No se pudo resolver automáticamente el keyring de deb-multimedia."
    echo "  Descárgalo manualmente de https://www.deb-multimedia.org/ e instálalo con dpkg -i."
fi

echo "→ Actualizando lista de paquetes y actualizando sistema..."
apt update
apt upgrade -y

# ---------------------------------------------------------------------------
# Función auxiliar: quita solo los paquetes de la lista que estén realmente
# instalados. Los que no estén presentes se reportan, sin generar error.
# ---------------------------------------------------------------------------
apt_remove_available() {
    local to_remove=()
    local not_found=()

    for pkg in "$@"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_remove+=("$pkg")
        else
            not_found+=("$pkg")
        fi
    done

    if [ ${#not_found[@]} -gt 0 ]; then
        echo "  (${#not_found[@]} paquete(s) no están presentes, se omiten: ${not_found[*]})"
    fi

    if [ ${#to_remove[@]} -gt 0 ]; then
        apt remove --purge -y "${to_remove[@]}"
    else
        echo "  Ningún paquete de esta lista está instalado, nada que quitar."
    fi
}

# ---------------------------------------------------------------------------
# 2. Debloat del escritorio (KDE Plasma y/o GNOME, según lo instalado)
# ---------------------------------------------------------------------------

if [ "$HAS_KDE" = true ]; then
    echo
    echo "→ Desinflando KDE Plasma..."

    echo "→ Reteniendo kdeaccessibility (no se desinstala)..."
    apt-mark hold kdeaccessibility || true

    # Paquetes a quitar. Incluye tanto los que suelen venir en una
    # instalación normal (netinstall + tasksel) como los que solo
    # aparecen al instalar desde la ISO Live de KDE; los que no estén
    # presentes en el sistema simplemente se reportan y se ignoran.
    KDE_REMOVE=(
        konqueror
        konq-plugins
        akregator
        kmail
        kaddressbook
        gimp
        xterm
        kwrite
        debian-reference-common
        dragonplayer
        juk
        goldendict-ng
        anthy
        anthy-common
        mozc-data
        uim-mozc
        mozc-server
        xiterm+thai
        libime-data
        libime-data-language-model
        fcitx-config-common
        libfcitx5-qt-data
        libfcitx5config6
        libfcitx5utils2
        fcitx-frontend-all
        fcitx-frontend-qt5
        fcitx-frontend-qt6
        fcitx5
        fcitx-modules
        fcitx-module-quickphrase-editor
        fcitx5-data
        fcitx5-config
        fcitx5-config-qt
        fcitx5-chinese-addons-data
        fcitx5-m17n
        fcitx5-module-lua-common
        libpinyin-data
        ibus-data
    )

    echo "→ Quitando paquetes innecesarios de KDE..."
    apt_remove_available "${KDE_REMOVE[@]}"

    echo "→ Instalando herramientas de integración KDE/Plymouth..."
    apt install -y kde-config-plymouth
fi

if [ "$HAS_GNOME" = true ]; then
    echo
    echo "→ Desinflando GNOME (juegos)..."
    echo "  Nota: algunos nombres de juegos han cambiado entre versiones de"
    echo "  Debian/GNOME; los que no existan se reportan y se ignoran."

    # Solo juegos: incluye tanto los que trae netinst+tasksel como los
    # que solo vienen en la ISO Live de GNOME (p. ej. gnome-klotski).
    GNOME_REMOVE=(
        gnome-games
        shotwell
        shotwell-common
        aisleriot
        gnome-mahjongg
        gnome-mines
        gnome-sudoku
        gnome-chess
        gnome-2048
        gnome-nibbles
        gnome-robots
        gnome-taquin
        gnome-tetravex
        four-in-a-row
        hitori
        iagno
        lightsoff
        quadrapassel
        swell-foop
        tali
        gnome-klotski
        mozc-data
        uim-mozc
        mozc-server
        libpinyin-data
        ibus
        ibus-data
        ibus-gtk
        ibus-gtk3
        ibus-gtk4
        im-config
        evolution
        evolution-common
        evolution-ews-core
    )

    echo "→ Quitando juegos de GNOME..."
    apt_remove_available "${GNOME_REMOVE[@]}"
fi

# ---------------------------------------------------------------------------
# 3. Paquetes básicos del sistema
# ---------------------------------------------------------------------------

echo
echo "→ Instalando headers del kernel y herramientas de compilación..."
apt install -y linux-headers-amd64 build-essential

echo "→ Instalando firmware no libre..."
apt install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree

if [ -n "$MICROCODE_PKG" ]; then
    echo "→ Instalando microcode ($MICROCODE_PKG)..."
    apt install -y "$MICROCODE_PKG"
fi

echo "→ Instalando ffmpeg..."
apt install -y ffmpeg

echo "→ Instalando soporte para archivos comprimidos comunes..."
apt install -y unzip p7zip-full unrar tar gzip bzip2 lzma xz-utils zstd unace \
    lzip arj mpack lzop zip lhasa cabextract lrzip rzip zpaq kgb

echo "→ Instalando herramientas varias..."
apt install -y flatpak git wget dpkg plymouth plymouth-themes synaptic

echo "→ Instalando fuentes comunes y de Microsoft..."
echo "  (ttf-mscorefonts-installer requiere aceptar licencia EULA de forma no interactiva)"
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
apt install -y fonts-inconsolata fonts-droid-fallback xfonts-terminus ttf-bitstream-vera \
    fonts-cantarell fonts-liberation fonts-oflb-asana-math fonts-mathjax ttf-mscorefonts-installer

echo "→ Instalando integración de Flatpak con la tienda de software del escritorio..."
if [ "$HAS_KDE" = true ]; then
    echo "  KDE detectado: instalando backend de Flatpak para Discover..."
    apt install -y plasma-discover-backend-flatpak kde-config-flatpak
fi
if [ "$HAS_GNOME" = true ]; then
    echo "  GNOME detectado: instalando backend de Flatpak para GNOME Software..."
    apt install -y gnome-software-plugin-flatpak
fi

echo "→ Agregando repositorio Flatpak (Flathub)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------------
# 4. Configuración de zram
# ---------------------------------------------------------------------------
 
echo
echo "→ Instalando y configurando zram (swap comprimido en RAM)..."
apt install -y zram-tools
 
# ALGO=zstd: mejor ratio de compresión que lz4/lzo, con un coste de CPU
# asumible en hardware moderno.
# PERCENT=50: techo máximo de RAM que zram puede llegar a usar (no un uso
# inmediato ni fijo) — es el valor por defecto recomendado para uso general.
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
 
systemctl enable --now zramswap.service 2>/dev/null || service zramswap restart 

# ---------------------------------------------------------------------------
# 5. Limpieza
# ---------------------------------------------------------------------------

echo
echo "→ Limpiando paquetes innecesarios..."
apt autoremove --purge -y
apt clean

echo
echo "✔ Post-instalación completada correctamente. Se recomienda reiniciar."