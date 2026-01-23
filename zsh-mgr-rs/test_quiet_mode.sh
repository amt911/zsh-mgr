#!/bin/bash
# Ejemplo de uso de parallel-git-update con --quiet

# Ruta al binario
BINARY="./target/release/parallel-git-update"

# Directorio de plugins
PLUGINS_DIR="${HOME}/.zsh-plugins"

# Encontrar repositorios
REPOS=$(find "$PLUGINS_DIR" -name ".git" -type d -exec dirname {} \; 2>/dev/null | head -5)

# Construir argumentos
REPO_ARGS=()
while IFS= read -r repo; do
    REPO_ARGS+=("--repos" "$repo")
done <<< "$REPOS"

# MODO NORMAL (con JSON)
echo "════════════════════════════════════════════════════════════"
echo "MODO NORMAL (con salida JSON):"
echo "════════════════════════════════════════════════════════════"
"$BINARY" "${REPO_ARGS[@]}"

echo ""
echo ""

# MODO QUIET (sin JSON)
echo "════════════════════════════════════════════════════════════"
echo "MODO QUIET (solo resumen, sin JSON):"
echo "════════════════════════════════════════════════════════════"
"$BINARY" "${REPO_ARGS[@]}" --quiet

echo ""
echo "✓ Listo! Ahora tienes la opción --quiet para ocultar el JSON"
