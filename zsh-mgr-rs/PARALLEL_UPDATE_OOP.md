# Parallel Git Update - Diseño OOP

## 📁 Archivo: `src/bin/parallel-git-update.rs`

Este archivo muestra un diseño **orientado a objetos** para actualizar múltiples repositorios Git en paralelo.

---

## 🏗️ Estructura OOP (Clases/Structs)

### 1. **`CredentialsManager`** - Gestión de credenciales
**Responsabilidad única**: Manejar autenticación SSH.

```rust
struct CredentialsManager {
    home_dir: PathBuf,
}
```

**Métodos**:
- `new()`: Constructor que obtiene el directorio HOME
- `get_ssh_credentials()`: Intenta cargar claves SSH en orden de preferencia:
  1. `~/.ssh/id_ed25519` (más moderno)
  2. `~/.ssh/id_rsa` (legacy)
  3. SSH Agent (fallback)

**Ventajas**:
- ✅ Lógica de auth centralizada y reutilizable
- ✅ Fácil de testear de forma aislada
- ✅ Fácil extender (añadir nuevos tipos de keys)

---

### 2. **`UpdateConfig`** - Configuración de operación
**Responsabilidad única**: Almacenar opciones de configuración.

```rust
struct UpdateConfig {
    fetch_only: bool,
    verbose: bool,
}
```

**Métodos**:
- `new()`: Constructor simple

**Ventajas**:
- ✅ Configuración inmutable y compartida entre threads (`Arc<UpdateConfig>`)
- ✅ Separa configuración de lógica de negocio

---

### 3. **`RepoUpdater`** - Actualizar un repositorio individual
**Responsabilidad única**: Gestionar fetch/merge de un solo repo.

```rust
struct RepoUpdater {
    repo_path: PathBuf,
    config: Arc<UpdateConfig>,
    credentials: Arc<CredentialsManager>,
}
```

**Métodos principales**:
- `update()`: Método público principal - orquesta todo el proceso
- `get_current_branch()`: Obtiene rama actual
- `fetch()`: Hace fetch desde origin
- `merge()`: Hace merge de cambios
- `do_fast_forward()`: Fast-forward merge
- `do_normal_merge()`: Merge normal con conflictos

**Ventajas**:
- ✅ Encapsula toda la lógica de un repo
- ✅ Métodos privados bien organizados
- ✅ Fácil de testear con repos de prueba
- ✅ Usa `Arc<T>` para compartir config/credentials sin copiar

---

### 4. **`BatchUpdater`** - Orquestador paralelo
**Responsabilidad única**: Coordinar actualizaciones en paralelo.

```rust
struct BatchUpdater {
    config: Arc<UpdateConfig>,
    credentials: Arc<CredentialsManager>,
}
```

**Métodos**:
- `new()`: Constructor que crea `CredentialsManager`
- `update_all()`: Procesa múltiples repos **en paralelo** usando Rayon

**Ventajas**:
- ✅ Abstrae la paralelización (el usuario no ve detalles de threads)
- ✅ Manejo robusto de errores (un repo fallido no para los demás)
- ✅ Fácil cambiar estrategia de paralelización

---

### 5. **Tipos de Resultado** (Data Transfer Objects)

```rust
struct FetchInfo { ... }       // Info del fetch
enum MergeType { ... }         // Tipo de merge realizado
struct MergeInfo { ... }       // Info del merge
struct UpdateResult { ... }    // Resultado de un repo
struct BatchUpdateResults { ... }  // Resultados totales
```

**Ventajas**:
- ✅ Serializables a JSON automáticamente
- ✅ Tipado fuerte (no strings mágicos)
- ✅ Fácil de extender sin romper API

---

## 🔄 Flujo de Ejecución (OOP)

```
main()
  ├─> Parsear CLI args
  ├─> Crear UpdateConfig
  ├─> Crear BatchUpdater
  │     └─> Internamente crea CredentialsManager
  │
  └─> BatchUpdater.update_all(repos)
        │
        └─> Rayon paraleliza sobre repos
              │
              └─> Para cada repo:
                    ├─> Crear RepoUpdater
                    ├─> RepoUpdater.update()
                    │     ├─> get_current_branch()
                    │     ├─> fetch() → usa CredentialsManager
                    │     └─> merge()
                    │
                    └─> Devolver UpdateResult
```

---

## 🆚 Comparación: OOP vs Procedural

### Tu archivo original (`git-update.rs`) - Estilo **Procedural**:
```rust
// Todo en funciones sueltas
fn do_fetch(...) { ... }
fn do_merge(...) { ... }
fn run(...) { ... }

// Lógica de credentials inline en un closure
cb.credentials(move |url, user, types| {
    // Código de auth aquí mezclado
});
```

**Características**:
- ❌ Difícil reutilizar lógica de credentials
- ❌ Difícil testear partes individuales
- ❌ Difícil escalar a múltiples repos en paralelo
- ✅ Más simple para casos pequeños

### Nuevo archivo (`parallel-git-update.rs`) - Estilo **OOP**:
```rust
// Clases con responsabilidades claras
struct CredentialsManager { ... }
struct RepoUpdater { ... }
struct BatchUpdater { ... }

// Lógica encapsulada en métodos
impl RepoUpdater {
    fn fetch(&self, ...) { ... }
    fn merge(&self, ...) { ... }
}
```

**Características**:
- ✅ Alta reutilización (cada struct es modular)
- ✅ Fácil testear (puedes mockear `CredentialsManager`)
- ✅ Escalable a N repos con paralelización
- ✅ Más fácil de mantener a largo plazo
- ❌ Más código inicial (pero más flexible)

---

## 🚀 Cómo usar

### Compilar:
```bash
cd /home/andres/.zshpc/.config/zsh/zsh-mgr-rs
cargo build --release --bin parallel-git-update
```

### Usar:
```bash
# Actualizar un solo repo
./target/release/parallel-git-update --repos /path/to/repo1

# Actualizar múltiples repos en paralelo
./target/release/parallel-git-update \
  --repos /path/to/repo1 /path/to/repo2 /path/to/repo3

# Solo fetch (sin merge)
./target/release/parallel-git-update \
  --repos /path/to/repo1 /path/to/repo2 \
  --fetch-only

# Control de paralelismo (4 jobs)
./target/release/parallel-git-update \
  --repos repo1 repo2 repo3 repo4 repo5 \
  --jobs 4

# Output JSON pretty
./target/release/parallel-git-update \
  --repos repo1 repo2 \
  --pretty

# Verbose logging
./target/release/parallel-git-update \
  --repos repo1 repo2 \
  --verbose
```

### Ejemplo de output:
```json
{
  "total": 3,
  "successful": 2,
  "failed": 1,
  "results": [
    {
      "repo_path": "/home/user/repo1",
      "branch": "main",
      "success": true,
      "fetch_info": {
        "objects_received": 5,
        "bytes_received": 12345
      },
      "merge_info": {
        "merge_type": "FastForward",
        "conflicts": false
      },
      "duration": 1.234,
      "error": null
    },
    ...
  ]
}
```

---

## 🎓 Conceptos de OOP en Rust

### 1. **Encapsulación**
Cada struct tiene sus propios campos privados y métodos públicos:
```rust
struct CredentialsManager {
    home_dir: PathBuf,  // Privado por defecto
}

impl CredentialsManager {
    pub fn new() -> Result<Self> { ... }  // Público
    pub fn get_ssh_credentials(...) { ... }  // Público
}
```

### 2. **Composición sobre herencia**
Rust no tiene herencia clásica, usa composición:
```rust
struct RepoUpdater {
    config: Arc<UpdateConfig>,         // Contiene config
    credentials: Arc<CredentialsManager>,  // Contiene credentials
}
```

### 3. **Traits (Interfaces)**
Aunque no se usan explícitamente aquí, podrías crear:
```rust
trait Updater {
    fn update(&self) -> Result<UpdateResult>;
}

impl Updater for RepoUpdater {
    fn update(&self) -> Result<UpdateResult> { ... }
}
```

### 4. **Arc<T> (Atomic Reference Counting)**
Permite compartir datos inmutables entre threads de forma segura:
```rust
let config = Arc::new(UpdateConfig::new(...));
// Múltiples threads pueden clonar el Arc y acceder
let config_clone = Arc::clone(&config);
```

---

## 📊 Ventajas de Paralelización con Rayon

```rust
repo_paths
    .par_iter()  // ← Automáticamente paralelo!
    .map(|path| {
        // Cada repo se procesa en un thread diferente
        updater.update()
    })
    .collect()
```

**Rayon automáticamente**:
- ✅ Distribuye trabajo entre CPUs
- ✅ Balancea carga
- ✅ Gestiona thread pool
- ✅ Es seguro (Rust previene race conditions)

**Speedup esperado**:
- 1 repo: ~igual que versión secuencial
- 10 repos en 8 cores: ~6-7x más rápido
- 100 repos: limitado por red, pero mucho mejor throughput

---

## 🔧 Próximos pasos sugeridos

1. **Añadir tests unitarios**:
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_credentials_manager() {
        let mgr = CredentialsManager::new().unwrap();
        // Test con repos ficticios
    }
}
```

2. **Crear trait `Updater`** para poder mockear en tests

3. **Añadir retry logic** en `RepoUpdater::fetch()`

4. **Implementar cache de `Repository`** para daemon (futuro)

5. **Añadir métricas detalladas** (tiempo por fase, etc.)

---

## 📚 Recursos de aprendizaje

- [The Rust Book - Ch 17: OOP in Rust](https://doc.rust-lang.org/book/ch17-00-oop.html)
- [Rayon Documentation](https://docs.rs/rayon/latest/rayon/)
- [Arc<T> Documentation](https://doc.rust-lang.org/std/sync/struct.Arc.html)

---

**Creado**: 2025-11-06  
**Autor**: GitHub Copilot + amt911
