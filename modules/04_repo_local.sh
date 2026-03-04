#!/usr/bin/env bash
# modules/04_repo_local.sh
# Genera repositorio local offline + relleno opcional de paquetes faltantes
# Basado en Debian Wiki + guías simples + tu flujo actual

set -euo pipefail

# ────────────────────────────────────────────────
# Cargar configuración
# ────────────────────────────────────────────────
source "${BASE_DIR:-$(pwd)}/config.env" 2>/dev/null || true

WORK_DIR="${WORK_DIR:-$(pwd)/work}"
CDROM_DIR="${WORK_DIR}/cdrom"
POOL_LOCAL="${CDROM_DIR}/pool/local"
DIST_DIR="${CDROM_DIR}/dists/excalibur/local"
BINARY_DIR="${DIST_DIR}/binary-amd64"
ARCH="amd64"
SUITE="excalibur"
COMPONENT="local"

LISTA_PKGS="${BASE_DIR}/pkgs_offline.txt"
LISTA_MANUAL="${BASE_DIR}/pkgs_manual.txt" 

# Activar relleno dinámico (descarga online si falta paquete)
# Por defecto: false → 100% offline
FILL_MISSING="${FILL_MISSING:-false}"

# Mirror para relleno (elige uno rápido y confiable para Devuan)
FILL_MIRROR="${FILL_MIRROR:-http://deb.devuan.nz/devuan}"

# ────────────────────────────────────────────────
# Funciones auxiliares
# ────────────────────────────────────────────────

log() { echo "[04_repo_local] $*" >&2; }
error() { echo "[04_repo_local] ERROR: $*" >&2; exit 1; }

ensure_dir() {
    mkdir -p "$1" || error "No se pudo crear $1"
}

check_commands() {
    for cmd in dpkg-scanpackages gzip apt-get; do
        command -v "$cmd" >/dev/null || error "Falta herramienta requerida: $cmd"
    done
}

# ────────────────────────────────────────────────
# Paso 1: Tomar SOLO pkgs_manual.txt como deseados explícitos
# ────────────────────────────────────────────────

if [ ! -s "$LISTA_MANUAL" ]; then
    error "pkgs_manual.txt vacío o no existe → nada que instalar manualmente"
fi

cp "$LISTA_MANUAL" "${WORK_DIR}/pkgs_manual_clean.txt"
log "Paquetes manuales deseados: $(wc -l < "${WORK_DIR}/pkgs_manual_clean.txt")"

# ────────────────────────────────────────────────
# Paso 2: Generar lista completa = manuales + TODAS sus dependencias
# ────────────────────────────────────────────────

log "Calculando dependencias de los paquetes manuales..."

> "${WORK_DIR}/pkgs_full.txt"  # lista final

while IFS= read -r pkg; do
    echo "$pkg" >> "${WORK_DIR}/pkgs_full.txt"
    
    # Obtener dependencias (apt-cache depende del mirror temporal o local)
    # Usamos un sources.list temporal con el mirror para resolver deps correctamente
    apt-cache depends "$pkg" --important 2>/dev/null | grep '^  Depends: ' | awk '{print $2}' | sort -u >> "${WORK_DIR}/pkgs_full.txt"
done < "${WORK_DIR}/pkgs_manual_clean.txt"

# Limpiar duplicados y versiones (nos quedamos con nombres base)
sort -u "${WORK_DIR}/pkgs_full.txt" > "${WORK_DIR}/pkgs_to_include.txt"

log "Lista completa (manuales + deps): $(wc -l < "${WORK_DIR}/pkgs_to_include.txt") paquetes"

# ────────────────────────────────────────────────
# Paso 3: Copiar lo que ya existe localmente
# ────────────────────────────────────────────────

log "Copiando paquetes disponibles localmente..."

copiados_local=0
while IFS= read -r pkg; do
    found=$(find "$POOL_SOURCE" -type f -name "${pkg}_*.deb" -print -quit 2>/dev/null)
    if [ -n "$found" ]; then
        cp -v "$found" "${POOL_LOCAL}/" && ((copiados_local++)) || true
    fi
done < "${WORK_DIR}/pkgs_to_include.txt"

log "Copiados desde pool extraído: $copiados_local"

# ────────────────────────────────────────────────
# Paso 4: Relleno solo para lo que falta (si activado)
# ────────────────────────────────────────────────

copiados_online=0

if [ "$FILL_MISSING" = "true" ]; then
    log "Rellenando dependencias y paquetes faltantes..."

    DOWNLOAD_DIR="${WORK_DIR}/downloads_temp"
    ensure_dir "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR" || error "No se pudo entrar a temp download"

    cat > sources.list.temp << EOF
deb $FILL_MIRROR $SUITE main contrib non-free non-free-firmware
EOF

    apt-get update \
        -o Dir::Etc::sourcelist="$(pwd)/sources.list.temp" \
        -o Dir::Cache::archives="$(pwd)" \
        -o Dir::State::status=/dev/null \
        --allow-insecure-repositories || log "Advertencia: apt update falló"

    while IFS= read -r pkg; do
        if ! ls "${POOL_LOCAL}/${pkg}_"*.deb &>/dev/null; then
            log "Descargando $pkg + sus dependencias..."
            if apt-get install --reinstall --download-only -y \
                -o Dir::Cache::archives="$(pwd)" \
                "$pkg" >/dev/null 2>&1; then
                
                find . -maxdepth 1 -name "*.deb" -exec mv {} "${POOL_LOCAL}/" \;
                ((copiados_online++))
            else
                log "Fallo al descargar $pkg"
            fi
        fi
    done < "${WORK_DIR}/pkgs_to_include.txt"

    rm -rf "$DOWNLOAD_DIR"/*
    apt-get clean

    log "Relleno completado: $copiados_online paquetes nuevos"
fi

# ────────────────────────────────────────────────
# Continuar con generación de Packages, Release, etc. (igual que antes)
# ────────────────────────────────────────────────