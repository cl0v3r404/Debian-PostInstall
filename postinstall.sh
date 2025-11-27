#!/bin/bash

# Script de postinstalación para Debian
# Compatible con Debian 12 (Bookworm), 13 (Trixie), etc.
sudo apt install wget curl -y
set -e

# Detectar codename de la distro (bookworm, trixie, etc.)
CODENAME=$(lsb_release -sc)

echo "→ Modificando /etc/apt/sources.list para agregar contrib y non-free-firmware..."

# Reemplazar el sources.list con contrib y non-free incluidos
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian $CODENAME-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $CODENAME-updates main contrib non-free non-free-firmware
EOF

# Agregar repositorio multimedia
cat <<EOF > /etc/apt/sources.list.d/dmo.list
deb https://www.deb-multimedia.org $CODENAME main non-free
EOF
wget -P /tmp https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb
sudo dpkg -i /tmp/deb-multimedia-keyring_2024.9.1_all.deb

#Agregar backports
cat <<EOF > /etc/apt/sources.list.d/backports.list
deb http://deb.debian.org/debian $CODENAME-backports main
EOF

# Actualizar repositorios
echo "→ Actualizando lista de paquetes..."
sudo apt update

# Instalar firmware non-free
echo "→ Instalando firmware no libre y microcodigos..."
sudo apt install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree intel-microcode

# Instalar encabezados del kernel
echo "→ Instalando linux headers..."
sudo apt install -y linux-headers-amd64 build-essential

# Instalar ffmpeg
echo "→ Instalando ffmpeg..."
sudo apt install -y ffmpeg

# Instalar soporte para archivos comprimidos comunes
echo "→ Instalando soporte para archivos comprimidos..."
sudo apt install -y unzip p7zip-full unrar tar gzip bzip2 lzma xz-utils zstd unace lzip arj mpack lzop zip lhasa cabextract lrzip rzip zpaq kgb

# Instalar herramientas
echo "→ Instalando herramientas..."
sudo apt install -y flatpak git wget dpkg plymouth plymouth-themes

# Instalar fuentes
echo "→ Instalando fuentes..."
sudo apt -y install fonts-inconsolata fonts-droid-fallback xfonts-terminus fonts-droid-fallback ttf-bitstream-vera fonts-cantarell fonts-liberation fonts-oflb-asana-math fonts-mathjax ttf-mscorefonts-installer

# Agregando repositorio de flatpak
echo "→ Agregando repositorio Flatpak..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Limpieza
echo "→ Limpiando paquetes innecesarios..."
sudo apt autoremove -y
sudo apt clean

echo "Post-instalación completada correctamente, se recomienda reiniciar."
