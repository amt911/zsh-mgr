# zsh-mgr-rs

Modern ZSH plugin manager written in Rust - Fast, parallel, and efficient.

## Features

- **Parallel Updates**: Update all plugins simultaneously using Rayon
- **Beautiful Tables**: Display update information with comfy-table
- **Smart Authentication**: Automatic SSH key and agent detection
- **Clean CLI**: Intuitive commands using Clap
- **Fast**: Compiled binary, no interpreter overhead
- **Auto-Recovery**: Automatically recreates plugins.json if deleted (19ms)
- **Manual Loading**: Control exactly which plugins load in .zshrc
- **Cross-platform**: Works on Linux, macOS (with adjustments)

## Building

### Development Build

```bash
cargo build
```

### Release Build (Optimized)

```bash
cargo build --release
```

The binary will be at `target/release/zsh-mgr`.

### Install Locally

```bash
make install PREFIX=$HOME/.local
```

Or system-wide (requires sudo):

```bash
sudo make install
```

## Creating Packages

### Debian/Ubuntu

```bash
cargo install cargo-deb
cargo deb
```

Package will be in `target/debian/`.

### Fedora/RHEL

```bash
cargo install cargo-generate-rpm
cargo generate-rpm
```

### Arch Linux

```bash
makepkg -si
```

## Usage

See main [README](../README.md) for usage instructions.

## Architecture

- `src/lib.rs`: Library exports
- `src/config.rs`: Configuration management
- `src/updater.rs`: Parallel update engine
- `src/git_update.rs`: Git operations
- `src/credentials_manager.rs`: Authentication
- `src/bin/zsh-mgr.rs`: Main CLI binary
- `src/bin/commands/`: Command implementations
  - `add.rs`: Add plugins
  - `update.rs`: Update plugins
  - `check.rs`: Check update status
  - `list.rs`: List plugins
  - `remove.rs`: Remove plugins
  - `install.rs`: Initial installation
  - `init.rs`: Generate .zshrc plugin loading code
  - `sync.rs`: Sync plugins.json from Git repositories

## Configuration

- **plugins.json location**: `~/.zsh-plugins/plugins.json`
- **Auto-recovery**: If `plugins.json` is deleted, it's automatically recreated by scanning `~/.zsh-plugins/` for Git repositories
- **Performance**: Auto-recovery takes ~19ms for 7 plugins

## Dependencies

See [Cargo.toml](Cargo.toml) for full dependency list.

Key dependencies:
- `git2`: Git operations
- `rayon`: Parallel processing
- `clap`: CLI parsing
- `colored`: Terminal colors
- `comfy-table`: Table rendering
- `chrono`: Date/time handling

## License

MIT - See LICENSE file in repository root.
