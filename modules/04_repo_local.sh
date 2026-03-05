#!/bin/bash
# modules/04_repo_local.sh
# Lógica Complementaria Robusta v0.99rc25
set -euo pipefail

# Cargar configuración y asegurar BASE_DIR
if [ -z "${BASE_DIR:-}" ]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [ -f "$BASE_DIR/config.env" ]; then
    source "$BASE_DIR/config.env"
else
    echo "❌ Error: config.env no encontrado en $BASE_DIR"
    exit 1
fi

# Redirección de logs (Cerebro v0.99rc25)
# Usar WORKDIR de config.env o fallback al directorio actual
WORKDIR="${WORKDIR:-$BASE_DIR/custom_esfp}"
LOG_FILE="$WORKDIR/logs/04_repo_local.log"
WARN_LOG="$WORKDIR/logs/warnings.log"
mkdir -p "$WORKDIR/logs"
exec > >(tee -a "$LOG_FILE") 2>&1

# Optimización de hilos (Max segura)
CPU_COUNT=$(nproc)
THREADS=$((CPU_COUNT + 1))
[ "$THREADS" -gt 8 ] && THREADS=8
echo "   Utilizando $THREADS hilos para procesamiento paralelo."

# 0. Cargar y Validar paquetes (Usando lista manual para resolución)
echo "   Cargando y validando paquetes desde $PKGS_MANUAL_FILE..."
PAQUETES_RAW=()
if [ -f "$PKGS_MANUAL_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^# || "$line" == Estado=* || "$line" == Err?=* || "$line" == Nombre ]] && continue
        pkg=$(echo "$line" | awk '{ if ($1 ~ /^[a-z][a-z]$/) print $2; else print $1; }' | sed 's/:.*//')
        
        # Validación Regex de nombre de paquete Debian
        if [[ "$pkg" =~ ^[a-z0-9][a-z0-9+.-]+$ ]]; then
            PAQUETES_RAW+=("$pkg")
        else
            [ -n "$pkg" ] && echo "⚠️ Nombre de paquete inválido omitido: $pkg" >> "$WARN_LOG"
        fi
    done < "$PKGS_MANUAL_FILE"
else
    echo "❌ Error: $PKGS_MANUAL_FILE no encontrado."
    exit 1
fi

# Inyección de paquetes CRÍTICOS (Declarativo)
PAQUETES_CRITICOS=(
    mate-menu 
    mate-desktop-environment-extras 
    mate-applets 
    bash-completion 
    sudo 
    zlib1g 
    libeudev1 
    libc6 
    libgcc-s1 
    vlc 
    vlc-plugin-base
)
PAQUETES_RAW+=("${PAQUETES_CRITICOS[@]}")

# Eliminar duplicados iniciales
PAQUETES_UNIQ=($(printf "%s\n" "${PAQUETES_RAW[@]}" | sort -u))
echo "   🔍 Resolviendo dependencias para ${#PAQUETES_UNIQ[@]} paquetes base..."

# Resolución de dependencias recursiva (filtro básico)
# Usamos apt-cache depends para obtener la lista completa
DEPS_ALL=$(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances "${PAQUETES_UNIQ[@]}" 2>/dev/null | grep "^\w" | sort -u || true)

if [ -n "$DEPS_ALL" ]; then
    PAQUETES=($DEPS_ALL)
else
    PAQUETES=("${PAQUETES_UNIQ[@]}")
fi

echo "   ✅ Total de paquetes (base + dependencias) a procesar: ${#PAQUETES[@]}"

# Directorios
mkdir -p "$ISO_HOME/pool/local"
mkdir -p "$ISO_HOME/dists/excalibur/local/binary-amd64"

# 1. Identificar paquetes BASE
echo "   Indexando base Netinstall para de-duplicación..."
BASE_PKGS_FILE="$WORKDIR/base_packages.txt"
if [ -f "$ISO_HOME/dists/excalibur/main/binary-amd64/Packages" ]; then
    grep "^Package: " "$ISO_HOME/dists/excalibur/main/binary-amd64/Packages" | cut -d' ' -f2 | sort -u > "$BASE_PKGS_FILE"
else
    touch "$BASE_PKGS_FILE"
fi

# 2. Extraer e Indexar Pool1
EXTRACT_DIR="$WORKDIR/pool1_files"
POOL1_INDEX="$WORKDIR/pool1_index.txt"
echo "   Extrayendo Pool1.iso..."
rm -rf "$EXTRACT_DIR" 2>/dev/null
mkdir -p "$EXTRACT_DIR"
xorriso -osirrox on -indev "$POOL1_ISO" -extract /pool "$EXTRACT_DIR" 2>/dev/null || { echo "❌ Error: Falló la extracción de $POOL1_ISO"; exit 1; }

# Crear índice de búsqueda rápida
find "$EXTRACT_DIR" -name "*.deb" -printf "%p\n" > "$POOL1_INDEX"
DEB_COUNT=$(wc -l < "$POOL1_INDEX")
echo "   ✅ Pool1 indexado ($DEB_COUNT paquetes)."

# 3. Procesamiento Paralelo Optimizado
export EXTRACT_DIR ISO_HOME BASE_PKGS_FILE POOL1_INDEX WARN_LOG
process_pkg() {
    local pkg=$1
    local retries=2
    local count=0
    
    # 1. ¿Está en base?
    if grep -q "^${pkg}$" "$BASE_PKGS_FILE"; then return 0; fi

    # 2. Buscar en índice de Pool1
    local DEB_PATH=$(grep -m1 "/${pkg}_" "$POOL1_INDEX" || true)
    
    if [ -n "$DEB_PATH" ] && [ -f "$DEB_PATH" ]; then
        cp "$DEB_PATH" "$ISO_HOME/pool/local/" || echo "❌ Error copiando $pkg desde Pool1" >> "$WARN_LOG"
    else
        # 3. Descarga con Re-intento
        while [ "$count" -le "$retries" ]; do
            if (cd "$ISO_HOME/pool/local/" && apt-get download "$pkg" -qq 2>/dev/null); then
                # Verificar que el archivo existe
                if ls "$ISO_HOME/pool/local/${pkg}_"*.deb >/dev/null 2>&1; then
                    return 0
                fi
            fi
            ((count++))
            [ "$count" -le "$retries" ] && sleep 1
        done
        echo "❌ No disponible tras $retries reintentos: $pkg" >> "$WARN_LOG"
    fi
}
export -f process_pkg

echo "   Iniciando copia/descarga paralela..."
printf "%s\n" "${PAQUETES[@]}" | xargs -I {} -P "$THREADS" bash -c 'process_pkg "$@"' _ {}

# 4. Generar Índices Apt
echo "   Generando índices de repositorio local..."
cd "$ISO_HOME"
dpkg-scanpackages -m pool/local /dev/null | sed "s|^Filename: \(.*\)$|Filename: ./\1|g" | gzip -9c > dists/excalibur/local/binary-amd64/Packages.gz
zcat dists/excalibur/local/binary-amd64/Packages.gz > dists/excalibur/local/binary-amd64/Packages

# Generar archivo Release con checksums MD5
echo "   Generando Release con checksums MD5..."
cat > "dists/excalibur/local/binary-amd64/Release" << EOF
Origin: Devuan ESFP Córdoba
Label: ESFP Córdoba Local Repo
Suite: excalibur
Codename: excalibur
Date: $(date -Ru)
Architectures: amd64
Components: local
Description: Paquetes Complementarios ESFP Córdoba

MD5Sum:
$(find "dists/excalibur/local/binary-amd64" -type f -name "Packages*" -printf "%P\n" | while read -r f; do
    md5sum "dists/excalibur/local/binary-amd64/$f" | awk '{print "  " $1 " " $2}' | sed "s|dists/excalibur/local/binary-amd64/||"
done)
EOF

rm -rf "$EXTRACT_DIR"
echo "✅ Módulo 04 finalizado exitosamente."
