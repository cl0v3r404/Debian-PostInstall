# Debian-PostInstall

Script de post-instalación para Debian que automatiza las tareas más comunes tras una instalación limpia: repositorios adicionales, debloat de KDE Plasma y/o GNOME, firmware, drivers básicos, fuentes, Flatpak y zram.

Pensado para ahorrar el trabajo manual repetitivo de dejar un Debian recién instalado listo para el uso diario, tanto si se instaló desde el **netinstall** con `tasksel` como desde una **ISO Live** de KDE o GNOME.

> Este script ha sido creado con ayuda de Inteligencia Artificial, supervisado y probado por mí personalmente.

## ¿Qué hace?

El script detecta automáticamente el entorno de escritorio instalado (KDE Plasma, GNOME, ambos, o ninguno), el fabricante de la CPU, y versión del sistema instalada ajustando su comportamiento en consecuencia. No hace falta indicar nada manualmente.

1. **Repositorios**
   - Configura `/etc/apt/sources.list` con `main`, `contrib`, `non-free` y `non-free-firmware`.
   - Agrega el repositorio de **backports** en un archivo separado (`/etc/apt/sources.list.d/backports.list`).
   - Agrega el repositorio de **deb-multimedia** en un archivo separado (`/etc/apt/sources.list.d/dmo.list`), resolviendo automáticamente la última versión del keyring.

2. **Debloat del escritorio**
   - **KDE Plasma**: quita aplicaciones que la mayoría no usa a diario (Konqueror, KMail, Akregator, Dragon Player, JuK, Kwrite, Xterm...) y métodos de entrada para idiomas que no se suelen necesitar (Anthy, Mozc, Fcitx5, IBus...). `kdeaccessibility` se retiene explícitamente para no desinstalarlo por error.
   - **GNOME**: quita los juegos que trae por defecto (Aisleriot, Mahjongg, Sudoku, 2048, Robots...), Shotwell, Evolution y otros métodos de entrada sobrantes.
   - Solo se ejecuta el debloat del escritorio que esté realmente presente en el sistema. Si no se detecta ni KDE ni GNOME (otro escritorio, o una instalación sin entorno gráfico), el script simplemente omite estas secciones y continúa con el resto sin problema.
   - Los paquetes que no estén instalados en el sistema no generan error: se reportan por pantalla y se ignoran.

3. **Paquetes básicos del sistema**
   - Headers del kernel y herramientas de compilación (`build-essential`).
   - Firmware no libre y microcode, detectando automáticamente si la CPU es **Intel** o **AMD**.
   - `ffmpeg`.
   - Soporte para los formatos de archivo comprimido más comunes (zip, 7z, rar, tar, zstd, lrzip, arj...).
   - Fuentes de uso común y las fuentes de Microsoft (`ttf-mscorefonts-installer`, aceptando la licencia EULA de forma no interactiva).
   - `synaptic` como gestor de paquetes gráfico.

4. **Flatpak**
   - Instala el paquete base de Flatpak y agrega el repositorio de Flathub.
   - Instala automáticamente el backend correspondiente según el escritorio detectado: `plasma-discover-backend-flatpak` para KDE Discover, o `gnome-software-plugin-flatpak` para GNOME Software.

5. **zram**
   - Instala `zram-tools` y configura swap comprimido en RAM con algoritmo **zstd**, un techo del **50% de la RAM total** y prioridad alta frente a cualquier swap en disco.

6. **Limpieza final**
   - `apt autoremove --purge` y `apt clean`.

## Requisitos

- Debian 12 (Bookworm), Debian 13 (Trixie) o superior.
- Conexión a internet.
- Ejecutarse como root.

## Uso

```bash
wget https://raw.githubusercontent.com/cl0v3r404/Debian-PostInstall/refs/heads/main/postinstall.sh
cd Debian-PostInstall
chmod +x postinstall.sh
sudo ./postinstall.sh
```

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/cl0v3r404/Debian-PostInstall/main/postinstall.sh)"
```

o

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/cl0v3r404/Debian-PostInstall/main/postinstall.sh)"
```


Al finalizar, se recomienda reiniciar el sistema.

## Notas

- El script está pensado para ser lo más estándar posible y no asume ningún hardware específico (más allá de detectar el fabricante de la CPU para el microcode). No incluye configuración de GPU ni drivers gráficos — eso queda para scripts aparte.
- Los nombres de algunos paquetes de debloat (especialmente juegos y métodos de entrada) pueden variar entre versiones de Debian o del propio escritorio. El script está preparado para ignorar sin error cualquier paquete de la lista que no exista en el sistema.
- Antes de quitar un paquete que forme parte de un metapaquete (como `gnome` o `gnome-core`), se verificó con Synaptic que la única baja adicional fuera ese metapaquete vacío, sin afectar a ningún componente real del escritorio.
- Si usas otro entorno de escritorio (XFCE, Cinnamon, MATE...) o ningún entorno gráfico, el script sigue funcionando: simplemente omite las secciones de debloat y de Flatpak específicas de KDE/GNOME, y aplica el resto con normalidad.

## Contribuciones

Si detectas algún paquete que debería añadirse o quitarse de las listas de debloat, o algún fallo, las *issues* y *pull requests* son bienvenidas.

## Licencia

Este proyecto está licenciado bajo la [GNU General Public License v3.0](LICENSE).