#!/usr/bin/env zsh
# build.sh - Compila los binarios de zsh-mgr-rs y los instala

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="${0:A:h}"
TARGET_DIR="${SCRIPT_DIR}/target/release"
INSTALL_DIR="${HOME}/.local/bin"

echo "${YELLOW}🔧 Compilando zsh-mgr-rs...${NC}"

# Verificar que rust está instalado
if ! command -v cargo &> /dev/null; then
    echo "${RED}❌ Error: cargo no encontrado${NC}"
    echo "Instala Rust desde: https://rustup.rs/"
    exit 1
fi

# Compilar en modo release (optimizado)
cd "${SCRIPT_DIR}"
echo "${YELLOW}📦 Ejecutando: cargo build --release${NC}"
cargo build --release

if [ $? -ne 0 ]; then
    echo "${RED}❌ Error en compilación${NC}"
    exit 1
fi

echo "${GREEN}✅ Compilación exitosa${NC}"

# Crear directorio de instalación si no existe
mkdir -p "${INSTALL_DIR}"

# Copiar binarios
echo "${YELLOW}📋 Copiando binarios a ${INSTALL_DIR}${NC}"

BINARIES=(
    "git-status"
    "git-batch-update"
    "check-timestamps"
)

for binary in "${BINARIES[@]}"; do
    if [ -f "${TARGET_DIR}/${binary}" ]; then
        cp "${TARGET_DIR}/${binary}" "${INSTALL_DIR}/"
        chmod +x "${INSTALL_DIR}/${binary}"
        echo "${GREEN}  ✓ ${binary}${NC}"
    else
        echo "${RED}  ✗ ${binary} no encontrado${NC}"
    fi
done

# Verificar que ~/.local/bin está en PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "${YELLOW}⚠️  Advertencia: ${INSTALL_DIR} no está en tu PATH${NC}"
    echo "Añade esto a tu ~/.zshrc:"
    echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

echo ""
echo "${GREEN}✅ Instalación completa${NC}"
echo ""
echo "Binarios disponibles:"
for binary in "${BINARIES[@]}"; do
    echo "  - ${binary}"
done

echo ""
echo "Prueba con: git-status --help"
