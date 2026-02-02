# Arquitectura OOP - ZSH Manager en Rust

## 📐 Diagrama de Clases

```
┌─────────────────────────────────────────────────────────────────┐
│                         BatchUpdater                             │
├─────────────────────────────────────────────────────────────────┤
│ - config: Arc<UpdateConfig>                                     │
│ - credentials: Arc<CredentialsManager>                          │
│ - progress: Arc<ProgressDisplay>                                │
├─────────────────────────────────────────────────────────────────┤
│ + new(config, repos) -> Result<Self>                            │
│ + update_all(&repos) -> BatchUpdateResults                      │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ usa
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                        RepoUpdater                               │
├─────────────────────────────────────────────────────────────────┤
│ - repo_path: PathBuf                                            │
│ - config: Arc<UpdateConfig>                                     │
│ - credentials: Arc<CredentialsManager>                          │
│ - progress: Arc<ProgressDisplay>                                │
│ - repo_name: String                                             │
├─────────────────────────────────────────────────────────────────┤
│ + new(...) -> Self                                              │
│ + update() -> Result<UpdateResult>                              │
│ - fetch(&repo, &branch) -> Result<FetchInfo>                    │
│ - merge(&repo, &branch, fetch_info) -> Result<MergeInfo>        │
│ - do_fast_forward(...) -> Result<()>                            │
│ - do_normal_merge(...) -> Result<()>                            │
│ - get_current_branch(&repo) -> Result<String>                   │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ usa
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│UpdateConfig  │  │ Credentials  │  │ ProgressDisplay  │
│              │  │  Manager     │  │                  │
├──────────────┤  ├──────────────┤  ├──────────────────┤
│-fetch_only   │  │-home_dir     │  │-statuses: Arc<   │
│-verbose      │  │              │  │  Mutex<Vec<...>>>│
├──────────────┤  ├──────────────┤  ├──────────────────┤
│+new(...)     │  │+new()        │  │+new(repos)       │
└──────────────┘  │+get_ssh_     │  │+update_status()  │
                  │ credentials()│  │+redraw()         │
                  └──────────────┘  │+initial_draw()   │
                                    └──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Result Types                                │
├─────────────────────────────────────────────────────────────────┤
│ UpdateResult:                                                    │
│   - repo_path, branch, success, fetch_info, merge_info,         │
│     duration, error                                              │
│                                                                  │
│ FetchInfo:                                                       │
│   - objects_received, bytes_received                             │
│                                                                  │
│ MergeInfo:                                                       │
│   - merge_type (FastForward|Normal|UpToDate|None)                │
│   - conflicts: bool                                              │
│                                                                  │
│ BatchUpdateResults:                                              │
│   - total, successful, failed, results: Vec<UpdateResult>        │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Ejecución

```
1. main()
   ↓
2. Parse CLI args (clap)
   ↓
3. Create UpdateConfig
   ↓
4. Create BatchUpdater
   │  ├─ Initialize CredentialsManager
   │  └─ Initialize ProgressDisplay
   ↓
5. BatchUpdater::update_all()
   │  ├─ Draw initial progress
   │  └─ Parallel iteration (rayon)
   │      ↓
   │  ┌───┴────┐ (for each repo in parallel)
   │  │        │
   │  │  Create RepoUpdater
   │  │        │
   │  │  Update status: Fetching
   │  │        │
   │  │  RepoUpdater::update()
   │  │    ├─ Open repository
   │  │    ├─ Get current branch
   │  │    ├─ Fetch (with credentials)
   │  │    │   └─ CredentialsManager::get_ssh_credentials()
   │  │    ├─ Update status: Merging
   │  │    └─ Merge
   │  │        ├─ Fast-forward OR
   │  │        ├─ Normal merge OR
   │  │        └─ Already up-to-date
   │  │        │
   │  │  Update status: Success/Failed
   │  │        │
   │  └────────┘
   │
   ↓
6. Collect results
   ↓
7. Print summary (stderr)
   ↓
8. Output JSON (stdout)
```

## 🎯 Principios OOP Aplicados

### 1. **Encapsulación**
- Cada clase tiene responsabilidades claramente definidas
- Los datos internos son privados
- Acceso controlado mediante métodos públicos

### 2. **Composición**
- `BatchUpdater` compone `UpdateConfig`, `CredentialsManager`, y `ProgressDisplay`
- `RepoUpdater` recibe referencias a estos componentes compartidos
- Uso de `Arc<>` para compartir de forma segura entre threads

### 3. **Separación de Responsabilidades (SRP)**
- **UpdateConfig**: Solo configuración
- **CredentialsManager**: Solo autenticación
- **ProgressDisplay**: Solo visualización
- **RepoUpdater**: Solo lógica de actualización de un repo
- **BatchUpdater**: Solo orquestación paralela

### 4. **Reutilización**
- Los componentes pueden ser usados independientemente
- El `CredentialsManager` puede ser usado en otros contextos Git
- El `ProgressDisplay` es genérico para cualquier operación paralela

### 5. **Inmutabilidad y Thread-Safety**
- Uso de `Arc<>` para compartir entre threads
- `Mutex<>` para mutación segura del progreso
- Config es inmutable una vez creado

## 🔧 Patterns Utilizados

### 1. **Builder Pattern** (via clap)
```rust
#[derive(Parser)]
struct Args { ... }
```

### 2. **Strategy Pattern** (Credentials)
- Intenta múltiples estrategias de autenticación
- Fallback automático entre métodos

### 3. **Observer Pattern** (Progress)
- `ProgressDisplay` observa cambios de estado
- Actualización automática de la UI

### 4. **Repository Pattern** (Git Operations)
- `RepoUpdater` abstrae operaciones Git
- Interfaz consistente independiente del backend

## 📊 Concurrencia

### Arc (Atomic Reference Counting)
```rust
Arc<UpdateConfig>         // Compartido entre todos los threads
Arc<CredentialsManager>   // Compartido entre todos los threads
Arc<ProgressDisplay>      // Compartido entre todos los threads
```

### Mutex (Mutual Exclusion)
```rust
Arc<Mutex<Vec<...>>>  // En ProgressDisplay para actualización segura
```

### Rayon (Data Parallelism)
```rust
repo_paths.par_iter()  // Iteración paralela automática
```

## 🎨 Estados del Progreso

```rust
enum RepoStatus {
    Pending,           // ⏳ En cola
    Fetching,          // 🔄 Descargando
    Merging,           // ⬇️  Integrando
    Success,           // ✓ Completado
    Failed(String),    // ✗ Error
}
```

## 🚀 Optimizaciones

1. **Compilación Release**: LTO, opt-level=3
2. **Paralelización**: Uso de todos los cores CPU
3. **Zero-copy**: Referencias en lugar de clones cuando es posible
4. **Async SSH**: Callbacks no bloqueantes de git2
5. **Minimización de locks**: Mutex solo para actualización de UI
