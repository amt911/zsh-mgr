#!/usr/bin/env zsh
# Integración de parallel-git-update con ZSH
# Este script muestra cómo usar el binario de Rust desde ZSH

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Ruta al binario compilado
PARALLEL_GIT_UPDATE="${HOME}/.zshpc/.config/zsh/zsh-mgr/zsh-mgr-rs/target/release/parallel-git-update"

# Directorio base donde están los repositorios a actualizar
ZSH_PLUGINS_DIR="${HOME}/.zsh-plugins"
ZSH_THEMES_DIR="${HOME}/.zshpc/.config/zsh/themes"

# ============================================================================
# FUNCIONES
# ============================================================================

# Actualizar todos los repositorios Git en paralelo
update_all_repos() {
    local repos=()
    local verbose_flag=""
    local quiet_flag="--quiet"  # Por defecto en modo quiet (sin JSON)

    # Encontrar todos los repositorios Git
    while IFS= read -r repo_dir; do
        repos+=("--repos" "$repo_dir")
    done < <(find "$ZSH_PLUGINS_DIR" "$ZSH_THEMES_DIR" -name ".git" -type d 2>/dev/null | xargs -I {} dirname {})

    # Verificar si hay repos
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo "❌ No se encontraron repositorios Git"
        return 1
    fi

    # Modo verbose si se pasa -v
    [[ "$1" == "-v" || "$1" == "--verbose" ]] && verbose_flag="--verbose"
    
    # Mostrar JSON si se pasa --json
    [[ "$1" == "--json" ]] && quiet_flag=""

    # Ejecutar actualización paralela
    if [[ -x "$PARALLEL_GIT_UPDATE" ]]; then
        "$PARALLEL_GIT_UPDATE" "${repos[@]}" $verbose_flag $quiet_flag
    else
        echo "❌ Error: Binario no encontrado o no ejecutable: $PARALLEL_GIT_UPDATE"
        echo "💡 Ejecuta: cd ~/.zshpc/.config/zsh/zsh-mgr/zsh-mgr-rs && cargo build --release"
        return 1
    fi
}

# Actualizar solo plugins
update_plugins() {
    local repos=()

    while IFS= read -r repo_dir; do
        repos+=("--repos" "$repo_dir")
    done < <(find "$ZSH_PLUGINS_DIR" -name ".git" -type d 2>/dev/null | xargs -I {} dirname {})

    [[ ${#repos[@]} -eq 0 ]] && { echo "❌ No plugins encontrados"; return 1; }

    "$PARALLEL_GIT_UPDATE" "${repos[@]}" --quiet
}

# Actualizar solo temas
update_themes() {
    local repos=()

    while IFS= read -r repo_dir; do
        repos+=("--repos" "$repo_dir")
    done < <(find "$ZSH_THEMES_DIR" -name ".git" -type d 2>/dev/null | xargs -I {} dirname {})

    [[ ${#repos[@]} -eq 0 ]] && { echo "❌ No themes encontrados"; return 1; }

    "$PARALLEL_GIT_UPDATE" "${repos[@]}" --quiet
}

# Actualizar con análisis JSON
update_with_stats() {
    local json_output
    local repos=()

    while IFS= read -r repo_dir; do
        repos+=("--repos" "$repo_dir")
    done < <(find "$ZSH_PLUGINS_DIR" "$ZSH_THEMES_DIR" -name ".git" -type d 2>/dev/null | xargs -I {} dirname {})

    [[ ${#repos[@]} -eq 0 ]] && { echo "❌ No repos encontrados"; return 1; }

    # Capturar salida JSON
    json_output=$("$PARALLEL_GIT_UPDATE" "${repos[@]}" 2>/dev/null)

    # Parsear con jq si está disponible
    if command -v jq &>/dev/null; then
        echo "📊 Estadísticas de actualización:"
        echo ""
        echo "$json_output" | jq -r '
            "Total: \(.total)",
            "Exitosos: \(.successful) ✓",
            "Fallidos: \(.failed) ✗",
            "",
            "Detalles por repositorio:",
            (.results[] | 
                if .success then
                    "  ✓ \(.repo_path | split("/") | last) (\(.branch)) - \(.duration)s"
                else
                    "  ✗ \(.repo_path | split("/") | last) - \(.error)"
                end
            )
        '
    else
        echo "$json_output" | python3 -m json.tool
    fi
}

# ============================================================================
# ALIASES RECOMENDADOS
# ============================================================================

# Agregar estos aliases a tu .zshrc:
#
# alias zupdall='update_all_repos'
# alias zupdall-v='update_all_repos -v'
# alias zupd-plugins='update_plugins'
# alias zupd-themes='update_themes'
# alias zupd-stats='update_with_stats'

# ============================================================================
# EJEMPLO DE USO
# ============================================================================

# Si este script se ejecuta directamente (no se hace source)
if [[ "${(%):-%x}" == "$0" ]]; then
    case "${1:-all}" in
        all|-a|--all)
            update_all_repos "${@:2}"
            ;;
        plugins|-p|--plugins)
            update_plugins
            ;;
        themes|-t|--themes)
            update_themes
            ;;
        stats|-s|--stats)
            update_with_stats
            ;;
        help|-h|--help)
            cat <<EOF
Uso: $0 [COMANDO] [OPCIONES]

COMANDOS:
  all, -a, --all       Actualizar todos los repositorios (default)
  plugins, -p          Actualizar solo plugins
  themes, -t           Actualizar solo temas
  stats, -s            Actualizar y mostrar estadísticas detalladas
  help, -h             Mostrar esta ayuda

OPCIONES (para 'all'):
  -v, --verbose        Modo verbose con logging detallado

EJEMPLOS:
  $0                   # Actualizar todo
  $0 all -v            # Actualizar todo con verbose
  $0 plugins           # Solo plugins
  $0 stats             # Con estadísticas

INTEGRACIÓN ZSH:
  Para usar estas funciones desde ZSH, agrega a tu .zshrc:
    source $0

  Luego podrás usar:
    update_all_repos
    update_plugins
    update_themes
    update_with_stats
EOF
            ;;
        *)
            echo "❌ Comando desconocido: $1"
            echo "💡 Usa '$0 help' para ver opciones disponibles"
            exit 1
            ;;
    esac
fi
