#!/bin/bash
# CorbexOS - Generador Dinámico de Repositorios
# Uso: ./3.5_build_source.sh "deb.devuan.nz"
#
# Sin set -e: errores manejados explícitamente para no interferir con el discovery.
# Salidas:
#   stdout → contenido del sources.list
#   stderr → mensajes de log/error (prefijados con #)

# --- 0. Leer config.env si existe ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="$SCRIPT_DIR/../config.env"
if [ -f "$CONFIG_ENV" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_ENV"
fi

# Valores por defecto (override por config.env)
RELEASE="${RELEASE:-excalibur}"
ARCH="${ARCH:-amd64}"

PROTOCOLS=("https" "http")
RUTAS=("/devuan/merged" "/merged" "")
WANTED_COMPONENTS=("main" "contrib" "non-free" "non-free-firmware")
CURL_TIMEOUT=5  # segundos por request

# --- 1. Leer mirror desde argumento ---
MIRROR_HOST="$1"

if [ -z "$MIRROR_HOST" ]; then
    echo "# Error: No se recibió un mirror como argumento." >&2
    exit 1
fi

# --- Helper: devuelve el HTTP status code de una URL ---
http_status() {
    curl -sL \
        --connect-timeout "$CURL_TIMEOUT" \
        --max-time "$((CURL_TIMEOUT * 3))" \
        -o /dev/null \
        -w "%{http_code}" \
        "$1" 2>/dev/null
}

# --- 2. Discovery: Protocolo y Ruta ---
BASE_URL=""
for proto in "${PROTOCOLS[@]}"; do
    for path in "${RUTAS[@]}"; do
        TEST_URL="${proto}://${MIRROR_HOST}${path}/dists/${RELEASE}/Release"
        STATUS=$(http_status "$TEST_URL")
        if [ "$STATUS" = "200" ]; then
            BASE_URL="${proto}://${MIRROR_HOST}${path}"
            echo "# Mirror encontrado: $BASE_URL" >&2
            break 2
        fi
    done
done

if [ -z "$BASE_URL" ]; then
    echo "# Error: Estructura Devuan (release=$RELEASE) no encontrada en $MIRROR_HOST" >&2
    exit 1
fi

# --- 3. Validación de Componentes ---
FINAL_COMPONENTS=()
for comp in "${WANTED_COMPONENTS[@]}"; do
    CHECK_URL="$BASE_URL/dists/$RELEASE/$comp/binary-$ARCH/Packages.gz"
    STATUS=$(http_status "$CHECK_URL")
    if [ "$STATUS" = "200" ]; then
        FINAL_COMPONENTS+=("$comp")
        echo "# Componente validado: $comp" >&2
    else
        echo "# Componente no disponible (ignorado): $comp [HTTP $STATUS]" >&2
    fi
done

# Validación mínima: 'main' es obligatorio
if [[ ! " ${FINAL_COMPONENTS[*]} " =~ " main " ]]; then
    echo "# Error: Mirror incompleto — componente 'main' no hallado." >&2
    exit 1
fi

# --- 4. Detectar suites opcionales (-updates, -security) ---
EXTRA_SUITES=()
for suite_suffix in "-updates" "-security"; do
    SUITE_URL="$BASE_URL/dists/${RELEASE}${suite_suffix}/Release"
    STATUS=$(http_status "$SUITE_URL")
    if [ "$STATUS" = "200" ]; then
        EXTRA_SUITES+=("${RELEASE}${suite_suffix}")
        echo "# Suite adicional disponible: ${RELEASE}${suite_suffix}" >&2
    fi
done

# --- 5. Generar sources.list a stdout ---
COMP_STRING="${FINAL_COMPONENTS[*]}"

echo "############################################"
echo "# Generado por CorbexOS Discovery Tool #"
echo "############################################"
echo "deb $BASE_URL $RELEASE $COMP_STRING"
for suite in "${EXTRA_SUITES[@]}"; do
    echo "deb $BASE_URL $suite $COMP_STRING"
done
echo ""
