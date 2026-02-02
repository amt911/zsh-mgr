#!/bin/bash
# Script de prueba para parallel-git-update
# Muestra el progreso en tiempo real de actualización de repositorios Git en paralelo

set -euo pipefail

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===========================================================${NC}"
echo -e "${GREEN}🚀 Parallel Git Update Test${NC}"
echo -e "${BLUE}===========================================================${NC}"
echo ""

# Directorio base donde buscar repositorios Git
# BASE_DIR="${HOME}/.zshpc/.config/zsh"
BASE_DIR="${HOME}/.zsh-plugins"

# Encuentra todos los repositorios Git
echo -e "${BLUE}Buscando repositorios Git en: ${BASE_DIR}${NC}"
REPOS=$(find "$BASE_DIR" -name ".git" -type d -exec dirname {} \; 2>/dev/null | head -5)

if [ -z "$REPOS" ]; then
    echo "No se encontraron repositorios Git"
    exit 1
fi

echo -e "${GREEN}Repositorios encontrados:${NC}"
echo "$REPOS" | while read -r repo; do
    echo "  - $repo"
done
echo ""

# Construir argumentos para el comando
REPO_ARGS=()
while IFS= read -r repo; do
    REPO_ARGS+=("--repos" "$repo")
done <<< "$REPOS"

# Ejecutar parallel-git-update
echo -e "${BLUE}Ejecutando actualización paralela...${NC}"
echo ""

# Ejecutar el binario
./target/release/parallel-git-update "${REPO_ARGS[@]}" --verbose

echo ""
echo -e "${GREEN}✓ Actualización completada${NC}"
