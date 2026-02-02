# zsh-mgr

A modern, fast plugin manager for ZSH written entirely in Rust. Features:

- ✅ **Parallel updates** - Update all plugins simultaneously
- ✅ **Real-time progress** - See what's happening with each plugin
- ✅ **Automatic management** - Auto-updates on schedule
- ✅ **Clean CLI** - Simple, intuitive commands
- ✅ **Fast** - Written in Rust for maximum performance
- ✅ **Smart detection** - Works with system packages or local builds

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

### Add a plugin

```console
zsh-mgr add zsh-users/zsh-autosuggestions
```

### Add with custom flags

```console
zsh-mgr add zsh-users/zsh-syntax-highlighting --flags="--depth=1"
```

### Add a plugin from a private repository

```console
zsh-mgr add your-user/private-repo --private
```

### Update all plugins

```console
zsh-mgr update
```

Updates all plugins in parallel. The system will show real-time progress for each repository.

### Update specific plugins

```console
zsh-mgr update --only plugin1 --only plugin2
```

### Check next update dates

```console
zsh-mgr check
```

Shows a beautiful table with update information:

```
╔════════════════════════════════════════════════════════════╗
║ Name                    │ Next Update        │ Status      ║
╠════════════════════════════════════════════════════════════╣
║ zsh-autosuggestions     │ 2024-01-30 10:00   │ ✓ Current   ║
║ zsh-syntax-highlighting │ 2024-01-29 15:30   │ ⏰ Soon     ║
║ powerlevel10k           │ 2024-01-25 08:00   │ ⚠ Update   ║
╚════════════════════════════════════════════════════════════╝
```

### List installed plugins

```console
zsh-mgr list
```

### Remove a plugin

```console
zsh-mgr remove plugin-name
```

## Performance

zsh-mgr uses Rust and parallel processing to update multiple repositories simultaneously. This provides:

- **Fast updates**: All plugins update in parallel
- **Efficient**: Uses system resources optimally
- **Safe**: Proper error handling and stash management
- **Reliable**: Handles authentication (SSH keys, agents) automatically

## Configuration

Configuration is automatically created during installation. You can customize:

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