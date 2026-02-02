# zsh-mgr

A modern, fast plugin manager for ZSH written entirely in Rust. Features:

- ✅ **Parallel updates** - Update all plugins simultaneously using Rayon
- ✅ **Real-time progress** - Beautiful tables showing update status  
- ✅ **Non-blocking auto-updates** - Runs in background, won't slow shell startup
- ✅ **Auto-recovery** - Recreates plugins.json if deleted (~19ms)
- ✅ **Manual control** - Explicit plugin loading in .zshrc
- ✅ **Bootstrap** - Install default plugins automatically
- ✅ **Smart sync** - Detects plugins from Git repositories
- ✅ **Clean CLI** - Simple, intuitive commands
- ✅ **Fast** - Written in Rust for maximum performance

## Installation

### System Package (Recommended)

#### Arch Linux (AUR)
```console
yay -S zsh-mgr
```

#### Debian/Ubuntu
```console
wget https://github.com/amt911/zsh-mgr/releases/latest/download/zsh-mgr_amd64.deb
sudo dpkg -i zsh-mgr_amd64.deb
```

#### Fedora/RHEL
```console
wget https://github.com/amt911/zsh-mgr/releases/latest/download/zsh-mgr.rpm
sudo rpm -i zsh-mgr.rpm
```

After installing the package, run:
```console
zsh-mgr install
```

### From Source

If you have Rust installed:

```console
git clone --recurse-submodules "https://github.com/amt911/zsh-mgr.git" ~/.config/zsh/zsh-mgr
cd ~/.config/zsh/zsh-mgr/zsh-mgr-rs
cargo build --release
make install PREFIX=$HOME/.local
zsh-mgr install
```

**Note:** You can add your own scripts to: `~/.config/zsh/` and source them in your `.zshrc` file.

## Usage

### Bootstrap default plugins

Install all plugins from `~/.config/zsh/default-plugins.txt`:

```console
zsh-mgr bootstrap
```

### Generate .zshrc plugin loading code

```console
zsh-mgr init
```

Automatically adds `load_plugin` lines to your .zshrc based on installed plugins.

### Sync plugins.json from Git repositories

If plugins.json is deleted or corrupted, recreate it:

```console
zsh-mgr sync
```

This scans `~/.zsh-plugins/` for Git repositories and rebuilds the database (~19ms).

### Add a plugin

```console
zsh-mgr add zsh-users/zsh-autosuggestions
```

### Add with custom flags

```console
zsh-mgr add romkatv/powerlevel10k --flags="--depth 1"
```

### Add a plugin from a private repository

```console
zsh-mgr add your-user/private-repo --private
```

### Update all plugins

```console
zsh-mgr update
```

Updates all plugins in parallel using Rayon. Non-blocking when run via auto-update.

### Update specific plugins

```console
zsh-mgr update --only plugin1 --only plugin2
```

### Check next update dates

```console
zsh-mgr check
```

Shows a beautiful table with update information using comfy-table.

### List installed plugins

```console
zsh-mgr list
```

### Remove a plugin

```console
zsh-mgr remove plugin-name
```

## Performance

- **Parallel updates**: All plugins update simultaneously using Rayon
- **Non-blocking**: Auto-updates run in background without blocking shell startup
- **Fast recovery**: plugins.json recreation takes ~19ms for 7 plugins
- **Efficient**: Optimal resource usage with thread pools
- **Safe**: Proper error handling and Git stash management
- **Smart auth**: Automatic SSH key and agent detection

## Configuration

- **plugins.json**: Located at `~/.zsh-plugins/plugins.json`
- **Auto-recovery**: Automatically recreated if deleted
- **Default plugins**: Define in `~/.config/zsh/default-plugins.txt`
- **Update threshold**: Default 7 days (604800 seconds)

- `ZSH_PLUGIN_DIR`: Where plugins are installed (default: `~/.zsh-plugins`)
- `ZSH_CONFIG_DIR`: Configuration directory (default: `~/.config/zsh`)
- `TIME_THRESHOLD`: Update interval in seconds (default: 604800 = 1 week)
- `MGR_TIME_THRESHOLD`: Manager update interval (default: 604800)

## Building Packages

### Debian/Ubuntu (.deb)

```console
cd zsh-mgr-rs
cargo install cargo-deb
cargo deb
```

### Fedora/RHEL (.rpm)

```console
cd zsh-mgr-rs
cargo install cargo-generate-rpm
cargo generate-rpm
```

### Arch Linux (PKGBUILD)

```console
cd zsh-mgr-rs
makepkg -si
```

## TODO

The following features are planned:

- <del>Updater for the plugin manager itself</del> ✅
- <del>Auto-update for the plugin manager</del> ✅
- <del>Parallel updates using Rust</del> ✅
- <del>Complete CLI in Rust</del> ✅
- Delete unused plugins via CLI
- Configuration management via CLI:
  - Disable auto-update
  - Change update frequency
- Plugin dependency management

## Finding bugs

If you encounter a bug, please open an issue or create a pull request to solve it. I speak both Spanish and English.