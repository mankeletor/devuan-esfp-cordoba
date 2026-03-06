#!/bin/bash
# ESFP Córdoba - Generador Dinámico de Repositorios
# Uso: ./generate-sources.sh "deb.devuan.nz"

set -e

# Configuración base
RELEASE="excalibur"
ARCH="amd64"
PROTOCOLS=("http" "https")
RUTAS=("/devuan/merged" "/merged" "")
WANTED_COMPONENTS=("main" "contrib" "non-free" "non-free-firmware")

# 1. Leer mirror desde el argumento
MIRROR_HOST="$1"

if [ -z "$MIRROR_HOST" ]; then
    echo "# Error: No se recibió un mirror" >&2
    exit 1
fi

# 2. Descubrimiento de Ruta y Protocolo (Discovery)
BASE_URL=""
for proto in "${PROTOCOLS[@]}"; do
    for path in "${RUTAS[@]}"; do
        # Limpiar barras duplicadas
        CLEAN_PATH=$(echo "$path" | sed 's|/$||')
        TEST_URL="${proto}://${MIRROR_HOST}${CLEAN_PATH}/dists/${RELEASE}/Release"
        
        if curl -sLI --connect-timeout 3 "$TEST_URL" -o /dev/null 2>&1; then
            BASE_URL="${proto}://${MIRROR_HOST}${CLEAN_PATH}"
            break 2
        fi
    done
done

if [ -z "$BASE_URL" ]; then
    echo "# Error: Estructura Devuan no encontrada en $MIRROR_HOST" >&2
    exit 1
fi

# 3. Validación Física de Componentes (Integrity Check)
# Solo devolvemos a stdout los componentes que realmente tienen paquetes para amd64
FINAL_COMPONENTS=()
for comp in "${WANTED_COMPONENTS[@]}"; do
    CHECK_PATH="$BASE_URL/dists/$RELEASE/$comp/binary-$ARCH/Packages.gz"
    if curl -sLI --connect-timeout 2 "$CHECK_PATH" -o /dev/null 2>&1; then
        FINAL_COMPONENTS+=("$comp")
    fi
done

# Validación mínima: si no hay 'main', el mirror no sirve
if [[ ! " ${FINAL_COMPONENTS[@]} " =~ " main " ]]; then
    echo "# Error: Mirror incompleto (main no hallado)." >&2
    exit 1
fi

# 4. Generación de sources.list a stdout
COMP_STRING="${FINAL_COMPONENTS[*]}"

echo "############################################"
echo "# Generado por ESFP Córdoba Discovery Tool #"
echo "############################################"
echo "deb $BASE_URL $RELEASE $COMP_STRING"
echo "deb $BASE_URL $RELEASE-security $COMP_STRING"
echo "deb $BASE_URL $RELEASE-updates $COMP_STRING"
echo ""
