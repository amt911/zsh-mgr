# 🚀 Parallel Git Update - Guía Rápida

## 📋 Opciones CLI Disponibles

```bash
parallel-git-update [OPTIONS]

OPTIONS:
  -r, --repos <PATHS>...    Rutas de repositorios a actualizar (requerido)
  -j, --jobs <JOBS>         Número de trabajos paralelos (default: núm. CPUs)
  -f, --fetch-only          Solo fetch, no merge
  -p, --pretty              JSON formateado (pretty-print)
  -v, --verbose             Salida verbose con logs detallados
  -q, --quiet               ⭐ Modo silencioso (sin JSON, solo resumen)
  -h, --help                Mostrar ayuda
  -V, --version             Mostrar versión
```

## 🎯 Ejemplos de Uso

### Básico (con JSON)
```bash
./parallel-git-update \
  --repos ~/repo1 \
  --repos ~/repo2
```

### Modo Quiet (sin JSON) ⭐ RECOMENDADO
```bash
./parallel-git-update \
  --repos ~/repo1 \
  --repos ~/repo2 \
  --quiet
```

### Verbose + Quiet
```bash
./parallel-git-update \
  --repos ~/repo1 \
  --repos ~/repo2 \
  --quiet \
  --verbose
```

### Solo Fetch (sin merge)
```bash
./parallel-git-update \
  --repos ~/repo1 \
  --fetch-only \
  --quiet
```

### Controlar Paralelismo
```bash
./parallel-git-update \
  --repos ~/repo1 \
  --repos ~/repo2 \
  --jobs 4 \
  --quiet
```

## 📊 Salidas

### Modo Normal (sin --quiet)
```
[línea vacía para separación]
✓ [ repo-1 ]
✓ [ repo-2 ]

============================================================
✓ Updated repositories in 0.46s
  2 successful, 0 failed
============================================================
{"total":2,"successful":2,"failed":0,"results":[...]}
```

### Modo Quiet (con --quiet)
```
[línea vacía para separación]
✓ [ repo-1 ]
✓ [ repo-2 ]

============================================================
✓ Updated repositories in 0.46s
  2 successful, 0 failed
============================================================
[sin JSON - salida limpia]
```

## 🔧 Integración con ZSH

### Instalación
```bash
# Agregar a .zshrc
source ~/.zshpc/.config/zsh/zsh-mgr/zsh-mgr-rs/zsh-integration.zsh
```

### Funciones Disponibles
```bash
# Actualizar todo (usa --quiet por defecto)
update_all_repos

# Actualizar con verbose
update_all_repos -v

# Forzar salida JSON
update_all_repos --json

# Solo plugins
update_plugins

# Solo temas
update_themes

# Con estadísticas parseadas
update_with_stats
```

### Aliases Sugeridos
```bash
# Agregar a .zshrc
alias zupd='update_all_repos'
alias zupd-v='update_all_repos -v'
alias zupd-plugins='update_plugins'
alias zupd-themes='update_themes'
```

## ⚡ Rendimiento

- **Paralelismo automático**: Usa todos los cores CPU disponibles
- **Thread-safe**: Actualización concurrente sin conflictos
- **Optimizado**: Compilado con LTO y optimizaciones máximas
- **Rápido**: Aprovecha libgit2 nativo en C

## 🎨 Estados del Progreso

Durante la ejecución verás estos estados en tiempo real:

- ⏳ **Pending** - Esperando procesamiento
- 🔄 **Fetching** - Descargando cambios
- ⬇️ **Merging** - Integrando cambios  
- ✓ **Success** - Completado correctamente
- ✗ **Failed** - Error (con mensaje descriptivo)

## 💡 Tips

1. **Usa `--quiet` por defecto** - Salida más limpia para uso diario
2. **`--verbose` solo cuando debuggees** - Para ver qué está haciendo
3. **Captura JSON cuando lo necesites** - Redirige stdout a archivo
4. **Funciones ZSH** - Más cómodas que el comando directo

## 📁 Ubicación del Binario

```bash
~/.zshpc/.config/zsh/zsh-mgr/zsh-mgr-rs/target/release/parallel-git-update
```

## 🔨 Recompilar

```bash
cd ~/.zshpc/.config/zsh/zsh-mgr/zsh-mgr-rs
cargo build --release --bin parallel-git-update
```

---

**Versión**: 0.0.1  
**Última actualización**: 2026-01-23
