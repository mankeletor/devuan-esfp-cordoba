#!/bin/bash
# ============================================
# SCRIPT PARA CUSTOMIZAR ISO DEVUAN - ESFP CÓRDOBA
# Versión: 0.10
# maintainer: Pablo Saquilan <psaquilan82@gmail.com>
# ============================================

echo "🚀 Iniciando customización de ISO para ESFP Córdoba"
echo "================================================"

# --------------------
# 0. CONFIGURACIÓN DE RUTAS
# --------------------
ISO_ORIGINAL="/media/bighdd/isoimages/devuan_excalibur_6.1.0_amd64_netinstall.iso"
POOL1_ISO="/media/bighdd/isoimages/devuan_excalibur_6.1.0_amd64_pool1.iso"
WORKDIR="$(pwd)/custom_esfp"
ISO_HOME="$WORKDIR/isohome"

# --------------------
# 0. VERIFICAR DEPENDENCIAS
# --------------------
echo "📋 Verificando dependencias..."
for cmd in cpio gzip xorriso curl rsync; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd no está instalado. Instalalo con: apt install $cmd"
        exit 1
    fi
done

# Verificar que isohdpfx.bin existe
if [ ! -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]; then
    echo "❌ Error: /usr/lib/ISOLINUX/isohdpfx.bin no encontrado"
    echo "   Instalá: sudo apt install isolinux"
    exit 1
fi

# Verificar que existen las ISOs
if [ ! -f "$ISO_ORIGINAL" ]; then
    echo "❌ Error: No se encuentra ISO original: $ISO_ORIGINAL"
    exit 1
fi

if [ ! -f "$POOL1_ISO" ]; then
    echo "❌ Error: No se encuentra pool1 en $POOL1_ISO"
    exit 1
fi
echo "✅ ISOs encontradas"

# --------------------
# 1. CREAR ESTRUCTURA DE TRABAJO
# --------------------
echo "📁 Creando estructura de trabajo en $WORKDIR..."
rm -rf "$WORKDIR" 2>/dev/null  # Limpiar versiones anteriores
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# --------------------
# 2. EXTRAER ISO ORIGINAL
# --------------------
echo "💿 Extrayendo ISO original..."
mkdir -p "$ISO_HOME"
sudo mkdir -p /mnt/original_iso
sudo mount -o loop "$ISO_ORIGINAL" /mnt/original_iso

echo "   Copiando archivos (puede tardar unos minutos)..."
rsync -a /mnt/original_iso/ "$ISO_HOME/"

sudo umount /mnt/original_iso
sudo rmdir /mnt/original_iso
echo "✅ ISO original extraída en $ISO_HOME"

# --------------------
# 3. COPIAR PRESEED Y SCRIPTS AL DIRECTORIO DE TRABAJO
# --------------------
echo "📝 Copiando archivos de configuración..."
cp "$WORKDIR/../preseed.cfg" "$WORKDIR/preseed.cfg" 2>/dev/null || cp "../preseed.cfg" "$WORKDIR/preseed.cfg"
cp "$WORKDIR/../postinst.sh" "$WORKDIR/postinst.sh" 2>/dev/null || cp "../postinst.sh" "$WORKDIR/postinst.sh"
cp "$WORKDIR/../rc.conf" "$WORKDIR/rc.conf" 2>/dev/null || cp "../rc.conf" "$WORKDIR/rc.conf"

if [ ! -f "$WORKDIR/preseed.cfg" ]; then
    echo "❌ Error: No se encuentra preseed.cfg"
    exit 1
fi
echo "✅ Archivos de configuración copiados"

# --------------------
# 3.5 CARGAR LISTA DE PAQUETES DESDE PKGS.TXT (¡ANTES DE USARLA!)
# --------------------
echo "📦 Cargando lista de paquetes desde pkgs.txt..."

PKGS_FILE="$WORKDIR/../pkgs.txt"
if [ ! -f "$PKGS_FILE" ]; then
    echo "⚠️ No se encuentra pkgs.txt, usando lista por defecto"
    PAQUETES=(
        mate-desktop-environment-core mate-terminal mate-calc mate-system-monitor
        mate-control-center mate-settings-daemon mate-power-manager mate-menu
        firmware-linux-nonfree firmware-intel-graphics firmware-realtek
        firmware-iwlwifi intel-microcode tlp pavucontrol htop net-tools ntfs-3g
        synaptic software-properties-common curl wget bash-completion gawk network-manager
        network-manager-gnome firefox-esr libreoffice-writer libreoffice-calc
        libreoffice-impress gimp audacity build-essential python3-venv python3-pip
        python3-dev git vim dbus-x11 policykit-1-gnome pulseaudio alsa-utils
    )
else
    echo "📄 Leyendo lista de paquetes desde pkgs.txt..."
    PAQUETES=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Saltar líneas vacías y de encabezado
        if [[ -z "$line" || "$line" == Estado=* || "$line" == Err?=* || "$line" == Nombre ]]; then
            continue
        fi
        # Limpiar la línea y extraer el nombre del paquete
        pkg=$(echo "$line" | awk '{ if ($1 ~ /^[a-z][a-z]$/) print $2; else print $1; }' | sed 's/:.*//')
        if [ -n "$pkg" ] && [[ ! "$pkg" =~ ^[./] ]]; then
            PAQUETES+=("$pkg")
        fi
    done < "$PKGS_FILE"
    
    # Agregar VSCode a la lista si no está
    if [[ ! " ${PAQUETES[@]} " =~ " code " ]]; then
        echo "   → Agregando VSCode a la lista de paquetes"
        PAQUETES+=("code")
    fi
fi

# Asegurar que mate-menu y extras estén siempre en la lista
# (mate-menu provee MateMenuApplet; mate-desktop-environment-extras lo incluye)
for pkg_extra in mate-menu mate-desktop-environment-extras mate-applets multiload-ng; do
    if [[ ! " ${PAQUETES[@]} " =~ " $pkg_extra " ]]; then
        echo "   → Asegurando $pkg_extra en la lista"
        PAQUETES+=("$pkg_extra")
    fi
done

echo "📊 Total de paquetes a procesar: ${#PAQUETES[@]}"

# --------------------
# 4. CREAR/ACTUALIZAR SCRIPT DE POST-INSTALACIÓN
# --------------------
echo "📝 Creando script postinst.sh versión completa..."
cat > "$WORKDIR/postinst.sh" << 'EOF'
#!/bin/bash
# postinst.sh - Optimizaciones finales para ESFP Córdoba

echo "=== Optimizando sistema para 4GB RAM (ESFP Córdoba) ==="

# Configuración de idioma y localización
echo "es_AR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen es_AR.UTF-8
update-locale LANG=es_AR.UTF-8

# Reducir swappiness
echo "vm.swappiness=10" >> /etc/sysctl.conf

# Desactivar servicios innecesarios
SERVICIOS_INNECESARIOS="cups bluetooth whoopsie avahi-daemon speech-dispatcher ModemManager"
for servicio in $SERVICIOS_INNECESARIOS; do
    if [ -f /etc/init.d/$servicio ]; then
        update-rc.d $servicio disable
        echo "Servicio $servicio desactivado"
    fi
done

# OpenRC: desactivar servicios
if command -v rc-update &> /dev/null; then
    rc-update del bluetooth default 2>/dev/null || true
    rc-update del cups default 2>/dev/null || true
    rc-update del avahi-daemon default 2>/dev/null || true
    rc-update del ModemManager default 2>/dev/null || true
    echo "Servicios OpenRC desactivados"
fi

# Limpiar basura
#apt-get autoremove --purge -y
apt-get autoclean -y

# --------------------------
# CONFIGURACIÓN DE MATE (SISTEMA-DB)
# Aplica valores por defecto para TODOS los usuarios.
# El panel layout se aplica en el primer login via /etc/profile.d/
# --------------------------
mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d

# Perfil: el usuario usa su db + la db del sistema
cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

# Configuraciones globales del sistema (todas las claves que NO son panel layout)
cat > /etc/dconf/db/local.d/01-esfp-custom << 'DCONF'
# ==================================================
# CONFIGURACIÓN MATE v0.99rc (Brisk Menu + ESFP Fix)
# ==================================================

[org/mate/panel/general]
# Mantenemos object-0 y object-1 para el Menú y el Monitor
object-id-list=['notification-area', 'clock', 'show-desktop', 'window-list', 'workspace-switcher', 'object-0', 'object-1']
toplevel-id-list=['top', 'bottom']

# --- SECCIÓN DEL MENÚ (Brisk Menu) ---
[org/mate/panel/objects/object-0]
applet-iid='BriskMenuFactory::BriskMenu'
object-type='applet'
position=0
toplevel-id='top'

[org/mate/mate-menu]
hot-key='Super_L'

# --- MONITOR DE SISTEMA (Carga de CPU/RAM/Red) ---
[org/mate/panel/objects/object-1]
applet-iid='MultiLoadAppletFactory::MultiLoadApplet'
object-type='applet'
position=147
relative-to-edge='end'
toplevel-id='top'

[org/mate/panel/objects/object-1/prefs]
view-cpuload=true
view-memload=true
view-netload=true

# --- RELOJ Y LOCALIZACIÓN CÓRDOBA ---
[org/mate/panel/objects/clock]
applet-iid='ClockAppletFactory::ClockApplet'
locked=true
object-type='applet'
position=0
relative-to-edge='end'
toplevel-id='top'

[org/mate/panel/objects/clock/prefs]
cities=['<location name="" city="Córdoba" timezone="America/Argentina/Buenos_Aires" latitude="-31.316668" longitude="-64.216667" code="SACO" current="true"/>']
format='24-hour'
expand-locations=true

# --- ESCRITORIO Y APARIENCIA ---
[org/mate/desktop/background]
picture-filename='/usr/share/backgrounds/mate/nature/Aqua.jpg'
picture-options='zoom'

[org/mate/marco/general]
theme='Menta'
button-layout=':minimize,maximize,close'
allow-tiling=true

[org/mate/desktop/interface]
gtk-decoration-layout=':minimize,maximize,close'

# --- AUDIO (FIX VOLUMEN BAJO) ---
[org/mate/sound]
allow-amplification=true
event-sounds=true

[org/mate/volume-control]
allow-amplification=true

# --- TERMINAL (TRANSPARENCIA) ---
[org/mate/terminal/profiles/default]
background-type='transparent'
background-darkness=0.85
use-theme-colors=false
visible-name='Default'

# --- OTROS AJUSTES ---
[org/mate/desktop/peripherals/keyboard]
numlock-state='on'

[org/mate/panel/toplevels/top]
expand=true
orientation='top'
size=24

[org/mate/panel/toplevels/bottom]
expand=true
orientation='bottom'
size=24
DCONF

# Compilar la base de datos del sistema
dconf update
echo "✅ dconf sistema-db compilado"

# --------------------------
# SCRIPT DE PRIMER LOGIN: aplica panel layout y settings de usuario
# Usa dconf load para escribir en la db del usuario, lo que requiere
# una sesión activa (D-Bus). Se ejecuta una sola vez al primer login.
# --------------------------
cat > /etc/profile.d/esfp-dconf-setup.sh << 'FIRSTLOGIN'
#!/bin/bash
# Aplica la configuración de panel MATE al usuario alumno en el primer login.
# Se autoelimiina después de ejecutarse.

MARKER="/home/alumno/.config/esfp-dconf-applied"
[ -f "$MARKER" ] && return 0
[ "$USER" != "alumno" ] && return 0

# Esperar a que D-Bus esté disponible
for i in $(seq 1 20); do
    [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && break
    sleep 0.5
done

# Inyectar configuración del panel vía dconf load
dconf load / << 'SETTINGS'
[org/mate/panel/general]
object-id-list=['notification-area', 'clock', 'show-desktop', 'window-list', 'workspace-switcher', 'object-0', 'object-1']
toplevel-id-list=['top', 'bottom']

[org/mate/panel/objects/clock]
applet-iid='ClockAppletFactory::ClockApplet'
locked=true
object-type='applet'
position=0
relative-to-edge='end'
toplevel-id='top'

[org/mate/panel/objects/clock/prefs]
cities=['<location name="" city="Córdoba" timezone="America/Argentina/Buenos_Aires" latitude="-31.316668" longitude="-64.216667" code="SACO" current="true"/>']
custom-format=''
expand-locations=true
format='24-hour'

[org/mate/panel/objects/notification-area]
applet-iid='NotificationAreaAppletFactory::NotificationArea'
locked=true
object-type='applet'
position=10
relative-to-edge='end'
toplevel-id='top'

[org/mate/panel/objects/object-0]
applet-iid='MultiLoadAppletFactory::MultiLoadApplet'
object-type='applet'
position=196
relative-to-edge='end'
toplevel-id='top'

[org/mate/panel/objects/object-0/prefs]
view-cpuload=true
view-memload=true
view-netload=true

[org/mate/panel/objects/object-1]
applet-iid='MateMenuAppletFactory::MateMenuApplet'
object-type='applet'
position=0
toplevel-id='top'

[org/mate/panel/objects/show-desktop]
applet-iid='WnckletFactory::ShowDesktopApplet'
locked=true
object-type='applet'
position=0
toplevel-id='bottom'

[org/mate/panel/objects/window-list]
applet-iid='WnckletFactory::WindowListApplet'
locked=true
object-type='applet'
position=20
toplevel-id='bottom'

[org/mate/panel/objects/workspace-switcher]
applet-iid='WnckletFactory::WorkspaceSwitcherApplet'
locked=true
object-type='applet'
position=0
relative-to-edge='end'
toplevel-id='bottom'

[org/mate/panel/toplevels/bottom]
expand=true
orientation='bottom'
screen=0
size=24
y-bottom=0

[org/mate/panel/toplevels/top]
expand=true
orientation='top'
screen=0
size=24
SETTINGS

# Reiniciar el panel para aplicar el nuevo layout
mate-panel --replace &>/dev/null &

# Marcar como aplicado para no volver a ejecutar
mkdir -p /home/alumno/.config
touch "$MARKER"
FIRSTLOGIN

chmod 644 /etc/profile.d/esfp-dconf-setup.sh
echo "✅ Script de primer login instalado en /etc/profile.d/"

# --------------------------
# CONFIGURAR AUTOLOGIN
# --------------------------
mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=alumno
autologin-user-timeout=0
LIGHTDM

chmod 644 /etc/lightdm/lightdm.conf.d/50-autologin.conf

# --------------------------
# CONFIGURAR SUDO
# --------------------------
cat > /etc/sudoers.d/alumno << 'SUDO'
alumno ALL=(ALL) ALL
SUDO

chmod 440 /etc/sudoers.d/alumno
chown root:root /etc/sudoers.d/alumno

# Marcar instalación
echo "INSTALACIÓN ESFP-CÓRDOBA - $(date)" >> /etc/issue
echo "✅ Sistema optimizado para ESFP Córdoba" >> /etc/motd

echo "=== Optimización completada ==="
exit 0
EOF

chmod +x "$WORKDIR/postinst.sh"
echo "✅ postinst.sh creado (versión completa con dconf + primer login)"

# --------------------
# 5. CREAR CONFIGURACIÓN OPENRC
# --------------------
echo "📝 Creando rc.conf optimizado..."
cat > "$WORKDIR/rc.conf" << 'EOF'
# /etc/rc.conf - OpenRC Config (ESFP Córdoba Optimized)
rc_loopsolver_enable="YES"
rc_loopsolver_warnings="YES"
rc_nocolor=YES
rc_parallel="YES"
rc_tty_number=12
EOF
echo "✅ rc.conf creado"

# --------------------
# 6. RESPALDAR INITRD ORIGINAL
# --------------------
echo "💾 Respaldando initrd original..."
cp "$ISO_HOME/boot/isolinux/initrd.gz" "$ISO_HOME/boot/isolinux/initrd.gz.original"
echo "✅ Respaldo creado"

# --------------------
# 7. EXTRAER, INYECTAR Y REEMPAQUETAR INITRD
# --------------------
echo "📦 Extrayendo initrd original..."
cd "$WORKDIR"
mkdir -p temp_initrd
cd temp_initrd

echo "   Descomprimiendo initrd.gz..."
if ! zcat "$ISO_HOME/boot/isolinux/initrd.gz" | cpio -idmv 2>&1 > /dev/null; then
    echo "❌ Error al extraer initrd"
    cd "$WORKDIR" && rm -rf temp_initrd
    exit 1
fi
echo "✅ Initrd extraído correctamente"

echo "📝 Inyectando archivos personalizados..."
cp "$WORKDIR/preseed.cfg" ./preseed.cfg
cp "$WORKDIR/postinst.sh" ./postinst.sh
cp "$WORKDIR/rc.conf" ./rc.conf
echo "✅ Archivos inyectados:"
ls -la preseed.cfg postinst.sh rc.conf

# --- IMPORTANTE: INYECTAR PAQUETES EN PRESEED ---
echo "📦 Sincronizando paquetes de pkgs.txt con preseed.cfg..."
PKGS_STRING=$(echo "${PAQUETES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
sed -i "s/d-i pkgsel\/include string .*/d-i pkgsel\/include string $PKGS_STRING/g" ./preseed.cfg
echo "✅ preseed.cfg actualizado con ${#PAQUETES[@]} paquetes"
# ------------------------------------------------

echo "🗜️ Reempaquetando initrd personalizado..."
find . | cpio -H newc -o | gzip -9 > "$WORKDIR/initrd_nuevo.gz"
if [ $? -ne 0 ]; then
    echo "❌ Error al reempaquetar initrd"
    cd "$WORKDIR" && rm -rf temp_initrd
    exit 1
fi
echo "✅ Nuevo initrd creado: $WORKDIR/initrd_nuevo.gz"

cd "$WORKDIR"
rm -rf temp_initrd

# --------------------
# 8. REEMPLAZAR INITRD EN LA ISO
# --------------------
echo "🔄 Reemplazando initrd en estructura ISO..."
mv "$WORKDIR/initrd_nuevo.gz" "$ISO_HOME/boot/isolinux/initrd.gz"
echo "✅ Initrd reemplazado"

# --------------------
# 9. CONFIGURAR ISOLINUX - MENÚ ÚNICO ESFP CON ASCII ART
# --------------------
echo "🎨 Configurando isolinux con menú único ESFP y ASCII art..."

cat > "$ISO_HOME/boot/isolinux/isolinux.cfg" << 'EOF'
# ISOLINUX configuration for ESFP Córdoba
DEFAULT esfp-auto
PROMPT 0
TIMEOUT 40

SAY 
SAY $$$$$$$$\  $$$$$$\  $$$$$$$$\ $$$$$$$\
SAY $$  _____|$$  __$$\ $$  _____|$$  __$$\
SAY $$ |      $$ /  \__|$$ |      $$ |  $$ |
SAY $$$$$$\    \$$$$$$\  $$$$$\    $$$$$$$ |
SAY $$  __|    \____$$\ $$  __|   $$  ____/
SAY $$ |      $$\   $$ |$$ |      $$ |
SAY $$$$$$$$\ \$$$$$$  |$$ |      $$ |
SAY \________| \______/ \__|      \__|
SAY 
SAY  $$$$$$\                            $$\           $$
SAY $$  __$$\                           $$ |          $$ |
SAY $$ /  \__| $$$$$$\   $$$$$$\   $$$$$$$ | $$$$$$\  $$$$$$$\   $$$$$$\
SAY $$ |      $$  __$$\ $$  __$$\ $$  __$$ |$$  __$$\ $$  __$$\  \____$$\
SAY $$ |      $$ /  $$ |$$ |  \__|$$ /  $$ |$$ /  $$ |$$ |  $$ | $$$$$$$ |
SAY $$ |  $$\ $$ |  $$ |$$ |      $$ |  $$ |$$ |  $$ |$$ |  $$ |$$  __$$ |
SAY \$$$$$$  |\$$$$$$  |$$ |      \$$$$$$$ |\$$$$$$  |$$$$$$$  |\$$$$$$$ |
SAY  \______/  \______/ \__|       \_______| \______/ \_______/  \_______|
SAY 

LABEL esfp-auto
  MENU LABEL ^Instalación Automática ESFP Córdoba
  KERNEL /boot/isolinux/linux
  APPEND vga=788 initrd=/boot/isolinux/initrd.gz preseed/file=/preseed.cfg auto=true priority=critical -- quiet

LABEL rescue
  MENU LABEL Modo Rescate
  KERNEL /boot/isolinux/linux
  APPEND vga=788 initrd=/boot/isolinux/initrd.gz rescue/enable=true priority=critical -- quiet
EOF

rm -f "$ISO_HOME/boot/isolinux/menu.cfg" 2>/dev/null
rm -f "$ISO_HOME/boot/isolinux/stdmenu.cfg" 2>/dev/null
rm -f "$ISO_HOME/boot/isolinux/vesamenu.c32" 2>/dev/null
echo "✅ Menú único ESFP con ASCII art configurado"

# --------------------
# 10. MONTAR POOL1
# --------------------
echo "💿 Montando pool1..."
sudo mkdir -p /mnt/pool1
if ! sudo mount -o loop "$POOL1_ISO" /mnt/pool1; then
    echo "❌ Error al montar pool1"
    exit 1
fi
echo "✅ Pool1 montada"

# --------------------
# 11. CREAR REPOSITORIO LOCAL DESDE POOL1
# --------------------
echo "📦 Creando repositorio local de paquetes desde pool1..."

mkdir -p "$ISO_HOME/pool/main"
mkdir -p "$ISO_HOME/pool/main/c/code"
mkdir -p "$ISO_HOME/dists/excalibur/main/binary-amd64"
mkdir -p "$ISO_HOME/dists/excalibur/main/debian-installer/binary-amd64"

cd "$ISO_HOME"

find_package() {
    find /mnt/pool1/pool -name "${1}_*.deb" 2>/dev/null | head -1
}

download_vscode() {
    local dest_dir="$ISO_HOME/pool/main/c/code"
    local vscode_url="https://vscode.download.prss.microsoft.com/dbazure/download/stable/072586267e68ece9a47aa43f8c108e0dcbf44622/code_1.109.5-1771531656_amd64.deb"
    local vscode_file="code_1.109.5-1771531656_amd64.deb"
    
    echo -ne "   → Descargando VSCode... "
    wget -q --show-progress -O "$dest_dir/$vscode_file" "$vscode_url" 2>&1
    if [ $? -eq 0 ] && [ -f "$dest_dir/$vscode_file" ]; then
        echo "✓"
        return 0
    else
        echo "✗"
        return 1
    fi
}

TOTAL=${#PAQUETES[@]}
ENCONTRADOS=0
DESCARGADOS=0
FALTANTES=0

for i in "${!PAQUETES[@]}"; do
    paquete="${PAQUETES[$i]}"
    echo -ne "   → [$((i+1))/$TOTAL] $paquete ... "
    
    DEB_FILE=$(find_package "$paquete")
    if [ -n "$DEB_FILE" ]; then
        cp "$DEB_FILE" pool/main/ 2>/dev/null && echo "✓" && ((ENCONTRADOS++)) || echo "✗" && ((FALTANTES++))
    else
        if [ "$paquete" = "code" ]; then
            if download_vscode; then
                ((DESCARGADOS++))
                ((ENCONTRADOS++))
            else
                echo "⚠️ VSCode no disponible"
                ((FALTANTES++))
            fi
        else
            echo "⚠️ no encontrado"
            ((FALTANTES++))
        fi
    fi
done

cd pool
dpkg-scanpackages . /dev/null | gzip -9c > ../dists/excalibur/main/binary-amd64/Packages.gz
cd ..
touch dists/excalibur/main/debian-installer/binary-amd64/Packages.gz

TOTAL_PAQUETES=$(find pool -name '*.deb' | wc -l)
echo "✅ Repositorio local creado:"
echo "   - Encontrados en pool1: $ENCONTRADOS"
echo "   - Descargados (VSCode): $DESCARGADOS"
echo "   - Faltantes: $FALTANTES"
echo "   - Total en pool/: $TOTAL_PAQUETES"

cd "$WORKDIR"

# --------------------
# 12. DESMONTAR POOL1
# --------------------
sudo umount /mnt/pool1
sudo rmdir /mnt/pool1
echo "✅ Pool1 desmontada"

# --------------------
# 13. RECONSTRUIR ISO
# --------------------
echo "💿 Reconstruyendo ISO final..."
ISO_FILENAME="devuan-esfp-cordoba-$(date +%Y%m%d_%H%M).iso"

xorriso -as mkisofs \
    -r -V "DEVUAN-ESFP" \
    -o "$WORKDIR/$ISO_FILENAME" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c boot/isolinux/boot.cat \
    -b boot/isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$ISO_HOME"

if [ $? -eq 0 ]; then
    echo "✅ ISO creada: $WORKDIR/$ISO_FILENAME"
    cd "$WORKDIR"
    md5sum "$ISO_FILENAME" > "$ISO_FILENAME.md5"
    sha256sum "$ISO_FILENAME" > "$ISO_FILENAME.sha256"
else
    echo "❌ Error al crear ISO"
    exit 1
fi

# --------------------
# 14. VERIFICACIONES FINALES
# --------------------
echo ""
echo "🔍 Verificando archivos en initrd..."
mkdir verify_initrd && cd verify_initrd
if gzip -dc "$ISO_HOME/boot/isolinux/initrd.gz" | cpio -idmv "preseed.cfg" "postinst.sh" "rc.conf" 2>&1 > /dev/null; then
    echo "✅ Archivos en initrd:"
    ls -la preseed.cfg postinst.sh rc.conf 2>/dev/null | sed 's/^/   /'
fi
cd "$WORKDIR" && rm -rf verify_initrd

echo ""
echo "🔍 Verificando repositorio local..."
[ -f "$ISO_HOME/dists/excalibur/main/binary-amd64/Packages.gz" ] && \
    echo "✅ Repositorio OK: $(find "$ISO_HOME/pool" -name '*.deb' | wc -l) paquetes"

echo ""
echo "🔍 Verificando booteo..."
file "$WORKDIR/$ISO_FILENAME" | grep -q "DOS/MBR boot sector" && \
    echo "✅ ISO booteable (MBR detectado)"

# --------------------
# 15. INSTRUCCIONES FINALES
# --------------------
echo ""
echo "🎉 ¡PROCESO COMPLETADO CON ÉXITO! 🎉"
echo "=================================="
echo "📀 ISO generada: $WORKDIR/$ISO_FILENAME ($(du -sh "$WORKDIR/$ISO_FILENAME" | cut -f1))"
echo "📦 Total paquetes: $TOTAL_PAQUETES"
echo ""
echo "💡 Para USB: sudo dd if='$WORKDIR/$ISO_FILENAME' of=/dev/sdX bs=4M status=progress && sync"
echo "🔗 Verificar: cd '$WORKDIR' && md5sum -c $ISO_FILENAME.md5"
echo ""

exit 0
