#!/usr/bin/env zsh
# Ejemplo de uso de parallel-git-update

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}=== Ejemplo de uso: parallel-git-update ===${NC}\n"

# Ruta al binario
BINARY="./target/debug/parallel-git-update"

# Compilar si no existe
if [[ ! -f "$BINARY" ]]; then
    echo "${BLUE}Compilando...${NC}"
    cargo build --bin parallel-git-update
fi

# Ejemplo 1: Un solo repo
echo "\n${GREEN}1. Actualizar un solo repositorio:${NC}"
echo "   $BINARY --repos /home/andres/repos/not\ mine/powerlevel10k --verbose\n"

# Ejemplo 2: Múltiples repos en paralelo
echo "${GREEN}2. Actualizar múltiples repositorios en paralelo:${NC}"
echo "   $BINARY --repos \\"
echo "     /home/andres/repos/not\ mine/powerlevel10k \\"
echo "     /home/andres/repos/not\ mine/zinit \\"
echo "     --jobs 4 --verbose\n"

# Ejemplo 3: Solo fetch (sin merge)
echo "${GREEN}3. Solo fetch (sin merge):${NC}"
echo "   $BINARY --repos /path/to/repo1 /path/to/repo2 --fetch-only\n"

# Ejemplo 4: Output JSON
echo "${GREEN}4. Output JSON para procesamiento:${NC}"
echo "   $BINARY --repos /path/to/repo1 --pretty > results.json\n"

# Ejemplo 5: Integración con find (todos los repos en un directorio)
echo "${GREEN}5. Actualizar todos los repos en un directorio:${NC}"
echo '   find ~/projects -name ".git" -type d -exec dirname {} \; | xargs $BINARY --repos\n'

# Prueba real (comentada - descomenta para probar)
echo "\n${BLUE}=== Prueba real (descomenta para ejecutar) ===${NC}"
echo "# Actualizar powerlevel10k y zinit:"
echo "# $BINARY --repos \\"
echo "#   /home/andres/repos/not\ mine/powerlevel10k \\"
echo "#   /home/andres/repos/not\ mine/zinit \\"
echo "#   --verbose --pretty"

echo "\n${GREEN}Tip:${NC} Usa --help para ver todas las opciones:"
echo "   $BINARY --help"
