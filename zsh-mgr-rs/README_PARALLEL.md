# 🚀 ZSH Manager - Implementación en Rust (OOP)

## 📋 Descripción

Implementación de zsh-mgr en Rust con capacidades de actualización paralela de repositorios Git. Este proyecto sigue principios de **Programación Orientada a Objetos** con las siguientes características:

- ✅ **Actualización paralela** de múltiples repositorios Git
- ✅ **Progreso en tiempo real** con indicadores visuales por repositorio
- ✅ **Gestión de credenciales** SSH automática (id_ed25519, id_rsa, ssh-agent)
- ✅ **Arquitectura OOP** con responsabilidades claramente separadas
- ✅ **Manejo de errores robusto** con `anyhow`
- ✅ **Salida JSON** para integración con scripts ZSH

## 🏗️ Arquitectura OOP

### Clases Principales

#### 1. **UpdateConfig**
- **Responsabilidad**: Encapsular configuración de actualización
- **Propiedades**: `fetch_only`, `verbose`

#### 2. **CredentialsManager**
- **Responsabilidad**: Gestión de autenticación SSH/HTTPS
- **Funcionalidad**: 
  - Intenta múltiples claves SSH (ed25519, rsa)
  - Fallback a SSH agent
  - Soporte para credential helpers

#### 3. **ProgressDisplay**
- **Responsabilidad**: Visualización de progreso en tiempo real
- **Funcionalidad**:
  - Muestra estado de cada repositorio en su propia línea
  - Actualización concurrente con `Arc<Mutex<>>`
  - Estados: Pending ⏳, Fetching 🔄, Merging ⬇️, Success ✓, Failed ✗

#### 4. **RepoUpdater**
- **Responsabilidad**: Lógica de actualización de un repositorio individual
- **Funcionalidad**:
  - Fetch desde remote
  - Detección de tipo de merge (fast-forward, normal, up-to-date)
  - Manejo de conflictos

#### 5. **BatchUpdater**
- **Responsabilidad**: Orquestar actualizaciones paralelas
- **Funcionalidad**:
  - Coordina múltiples `RepoUpdater` en paralelo
  - Gestiona el `ProgressDisplay` compartido
  - Recopila y agrega resultados

## 🎯 Características de Progreso

La implementación muestra el progreso de cada repositorio en tiempo real:

```
⏳ [ mi-proyecto-1                                        ]
🔄 [ mi-proyecto-2                                        ]
⬇️  [ mi-proyecto-3                                        ]
✓ [ mi-proyecto-4                                        ]
✗ [ mi-proyecto-5                                        ] Error: ...
```

- **⏳ Pending**: Esperando a ser procesado
- **🔄 Fetching**: Descargando cambios del remote
- **⬇️ Merging**: Integrando cambios
- **✓ Success**: Actualizado correctamente
- **✗ Failed**: Error durante la actualización

## 🚀 Uso

### Compilación

```bash
cargo build --release
```

### Ejecución

```bash
# Actualizar múltiples repositorios
./target/release/parallel-git-update \
  --repos /path/to/repo1 \
  --repos /path/to/repo2 \
  --repos /path/to/repo3 \
  --verbose

# Solo fetch (sin merge)
./target/release/parallel-git-update \
  --repos /path/to/repo1 \
  --repos /path/to/repo2 \
  --fetch-only

# Controlar número de trabajos paralelos
./target/release/parallel-git-update \
  --repos /path/to/repo1 \
  --repos /path/to/repo2 \
  --jobs 4
```

### Script de Prueba

```bash
chmod +x test_parallel_update.sh
./test_parallel_update.sh
```

## 📦 Dependencias

- **git2**: Bindings de libgit2 para operaciones Git
- **rayon**: Paralelización eficiente
- **clap**: Parsing de argumentos CLI
- **colored**: Colores en terminal
- **serde/serde_json**: Serialización JSON
- **anyhow**: Manejo de errores ergonómico

## 🔧 Configuración

### Variables de Entorno

- `HOME`: Requerida para localizar claves SSH
- `RUST_LOG`: Nivel de logging (info, debug, warn, error)

### Claves SSH

El sistema intenta automáticamente:
1. `~/.ssh/id_ed25519` (preferido)
2. `~/.ssh/id_rsa` (fallback)
3. SSH agent

## 📊 Salida JSON

El programa genera salida JSON estructurada:

```json
{
  "total": 5,
  "successful": 4,
  "failed": 1,
  "results": [
    {
      "repo_path": "/path/to/repo",
      "branch": "main",
      "success": true,
      "fetch_info": {
        "objects_received": 10,
        "bytes_received": 1024
      },
      "merge_info": {
        "merge_type": "FastForward",
        "conflicts": false
      },
      "duration": 1.234,
      "error": null
    }
  ]
}
```

## 🎨 Optimizaciones

### Profile Release

```toml
[profile.release]
opt-level = 3        # Máxima optimización
lto = true          # Link-Time Optimization
codegen-units = 1   # Mejor optimización (compilación más lenta)
strip = true        # Remover símbolos de debug
```

## 🔄 Próximos Pasos

- [ ] Soporte para stash automático cuando hay cambios locales
- [ ] Detección y manejo de conflictos de merge
- [ ] Cache de credenciales
- [ ] Webhooks para notificaciones
- [ ] Interfaz TUI con `ratatui`

## 📝 Licencia

MIT

## 👤 Autor

amt911
