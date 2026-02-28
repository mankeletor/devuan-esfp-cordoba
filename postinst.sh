#!/bin/bash
# postinst.sh - Optimizaciones finales para ESFP Córdoba
# Versión: PERSISTENTE (con /etc/skel)

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
apt-get autoremove --purge -y
apt-get autoclean -y

# --------------------------
# CONFIGURACIÓN DE MATE (DCONF)
# --------------------------
mkdir -p /etc/dconf/profile
mkdir -p /etc/dconf/db/local.d

cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

cat > /etc/dconf/db/local.d/01-esfp-custom << 'DCONF'
[org/mate/marco/general]
compositing-manager=false
theme='Menta'

[org/mate/interface]
gtk-theme='Menta'
enable-animations=false

[org/mate/background]
picture-filename='/usr/share/backgrounds/desktop-background'
picture-options='zoom'

[org/mate/power-manager]
sleep-display-ac=0
sleep-display-battery=0
DCONF

# Aplicar los cambios a la base de datos de dconf
dconf update

# Forzar la recarga de esquemas si fuera necesario
if command -v glib-compile-schemas &>/dev/null; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/
fi

# Marcar la instalación
echo "INSTALACIÓN ESFP-CÓRDOBA - $(date)" >> /etc/issue
echo "✅ Sistema optimizado para ESFP Córdoba" >> /etc/motd

echo "=== Optimización completada ==="
exit 0
