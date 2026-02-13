# zsh-mgr

A modern, fast plugin manager for ZSH written entirely in Rust.

- ✅ **Parallel updates** — Update all plugins simultaneously using Rayon
- ✅ **Real-time progress** — Beautiful tables showing update status
- ✅ **Non-blocking auto-updates** — Runs in background, won't slow shell startup
- ✅ **Auto-recovery** — Recreates `plugins.json` if deleted (~19ms)
- ✅ **Manual control** — Explicit `plugin` loading in `.zshrc`
- ✅ **Bootstrap** — Install default plugins automatically
- ✅ **Smart sync** — Detects plugins from Git repositories
- ✅ **Lazy auto-install** — Missing plugins are cloned in background on first `plugin` call
- ✅ **Clean CLI** — Simple, intuitive commands
- ✅ **Fast** — Written in Rust for maximum performance

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

After installing the package, run the initial setup:
```console
zsh-mgr install
```

### From Source

If you have Rust installed:

```console
git clone --recurse-submodules "https://github.com/amt911/zsh-mgr.git" ~/.config/zsh/zsh-mgr
cd ~/.config/zsh/zsh-mgr/zsh-mgr-rs
cargo build --release
mkdir -p ~/.local/bin
cp target/release/zsh-mgr ~/.local/bin/
zsh-mgr install
```

## Standalone integration (without zsh-personal-config)

If you want to use `zsh-mgr` on its own (without the full [zsh-personal-config](https://github.com/amt911/zsh-personal-config) setup), follow these steps.

### 1. Install zsh-mgr

Install via system package or build from source (see above).

### 2. Run the install wizard

```console
zsh-mgr install
```

This will:
- Ask for the plugin directory (defaults to `~/.zsh-plugins`)
- Create `~/.config/zsh/zsh-mgr/config.json` with your settings
- Add configuration and a basic plugin-loading loop to your `~/.zshrc`

If your `.zshrc` didn't have any `zsh-mgr` configuration yet, the wizard appends something like:

```zsh
# zsh-mgr configuration
export ZSH_PLUGIN_DIR="$HOME/.zsh-plugins"
export ZSH_CONFIG_DIR="$HOME/.config/zsh"
export TIME_THRESHOLD=604800
export MGR_TIME_THRESHOLD=604800

# Source installed plugins
for plugin in "$ZSH_PLUGIN_DIR"/*/*.plugin.zsh; do
    [ -f "$plugin" ] && source "$plugin"
done
```

### 3. Add plugins

```console
zsh-mgr add zsh-users/zsh-autosuggestions
zsh-mgr add zdharma-continuum/fast-syntax-highlighting
zsh-mgr add romkatv/powerlevel10k --flags="--depth 1"
```

### 4. (Optional) Use a default plugins file for bootstrap

Create `~/.config/zsh/default-plugins.txt`:

```
# Plugins to install — one per line, format: user/repo [flags]
zsh-users/zsh-autosuggestions
zdharma-continuum/fast-syntax-highlighting
romkatv/powerlevel10k --depth 1
```

Then install them all at once:

```console
zsh-mgr bootstrap
```

### 5. (Optional) Generate plugin loading code

If you want `zsh-mgr` to write `plugin` declarations into your `.zshrc`:

```console
zsh-mgr init
```

> **Note:** `zsh-mgr init` generates `plugin user/repo` lines for your `.zshrc`. The `plugin` shell function is defined in `zsh-mgr-init.zsh` which is part of [zsh-personal-config](https://github.com/amt911/zsh-personal-config). For standalone use, the generic loop added by `zsh-mgr install` (step 2) is sufficient.

### 6. (Optional) Set up auto-updates

Add the following to your `.zshrc` for non-blocking background auto-updates:

```zsh
# Auto-update plugins in the background
_zsh_mgr_auto_update() {
    local threshold="${TIME_THRESHOLD:-604800}"
    local timestamp_file="$ZSH_PLUGIN_DIR/.zsh-mgr-last-update"

    [ ! -d "$ZSH_PLUGIN_DIR" ] && mkdir -p "$ZSH_PLUGIN_DIR"

    if [ -f "$timestamp_file" ]; then
        local last_update=$(cat "$timestamp_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local diff=$((now - last_update))
        if [ $diff -lt $threshold ]; then
            return 0
        fi
    fi

    {
        (
            zsh-mgr update > "$ZSH_PLUGIN_DIR/.update-log" 2>&1
            if [ $? -eq 0 ]; then
                date +%s > "$timestamp_file" 2>/dev/null
            fi
        ) &
        disown &>/dev/null
    } &>/dev/null
}

_zsh_mgr_auto_update &!
```

This checks the timestamp on every shell startup and runs `zsh-mgr update` in the background if enough time has passed. It **never blocks** shell startup.

## CLI reference

```
zsh-mgr <COMMAND>

Commands:
  install    Install zsh-mgr for the first time (interactive wizard)
  add        Add a new plugin
  remove     Remove a plugin
  update     Update all plugins (parallel)
  check      Check next update dates
  list       List installed plugins
  bootstrap  Install plugins from default-plugins.txt
  init       Generate plugin loading code for .zshrc
  sync       Rebuild plugins.json from installed Git repositories
  help       Print help for a command
```

### `zsh-mgr install`

Interactive first-time setup. Creates directories, writes `config.json`, and configures `.zshrc`.

```console
zsh-mgr install [OPTIONS]
  -p, --plugin-dir <DIR>                 Plugin directory (default: ~/.zsh-plugins)
  -t, --time-threshold <SECS>            Update interval in seconds (default: 604800)
  -m, --mgr-time-threshold <SECS>        Manager update interval in seconds (default: 604800)
  -q, --quiet                            Skip interactive prompts
```

### `zsh-mgr add`

Clone a plugin repository and register it.

```console
zsh-mgr add <user/repo> [OPTIONS]
  -f, --flags <FLAGS>   Git clone flags (e.g. "--depth 1")
  -p, --private         Use SSH URL (for private repositories)
```

### `zsh-mgr remove`

Delete a plugin from disk and unregister it.

```console
zsh-mgr remove <plugin-name> [OPTIONS]
  -f, --force           Skip confirmation prompt
```

### `zsh-mgr update`

Update all (or specific) plugins in parallel.

```console
zsh-mgr update [OPTIONS]
  -o, --only <NAME>     Update only specific plugins (repeatable)
  -v, --verbose         Verbose output
  -j, --jobs <N>        Number of parallel jobs
```

### `zsh-mgr check`

Show a table with last/next update dates and status for each plugin and the manager.

```console
zsh-mgr check [OPTIONS]
  -p, --plugins         Show only plugins
  -m, --manager         Show only manager
  -j, --json            Output as JSON
```

Example output:

```
┌─────────────────────────┬─────────────────────┬─────────────────────┬─────────────────┐
│ Name                    │ Last Update         │ Next Update         │ Status          │
├─────────────────────────┼─────────────────────┼─────────────────────┼─────────────────┤
│ zsh-autosuggestions     │ 2026-02-07 10:00:00 │ 2026-02-14 10:00:00 │ ✓ Up to date    │
│ fast-syntax-high…       │ 2026-02-07 10:00:00 │ 2026-02-14 10:00:00 │ ✓ Up to date    │
│ powerlevel10k           │ 2026-02-01 08:00:00 │ 2026-02-08 08:00:00 │ ⚠ Update needed │
│ zsh-mgr                 │ 2026-02-06 15:30:00 │ 2026-02-13 15:30:00 │ ⏰ Update in 2h │
└─────────────────────────┴─────────────────────┴─────────────────────┴─────────────────┘
```

### `zsh-mgr list`

List all registered plugins.

```console
zsh-mgr list [OPTIONS]
  -j, --json            Output as JSON
  -n, --names-only      Output only plugin names (one per line)
```

### `zsh-mgr bootstrap`

Install all plugins listed in a text file (one `user/repo` per line).

```console
zsh-mgr bootstrap [OPTIONS]
  -f, --file <PATH>     Path to plugins file (default: ~/.config/zsh/default-plugins.txt)
```

### `zsh-mgr init`

Generate `plugin user/repo` lines and insert them into `.zshrc`.

```console
zsh-mgr init [OPTIONS]
  -z, --zshrc <PATH>    Path to .zshrc file (default: ~/.zshrc)
```

### `zsh-mgr sync`

Scan the plugin directory for Git repositories and rebuild `plugins.json`.

```console
zsh-mgr sync [OPTIONS]
  -f, --force           Regenerate even if plugins.json already exists
```

## Configuration

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `ZSH_PLUGIN_DIR` | `~/.zsh-plugins` | Directory where plugins are cloned |
| `ZSH_CONFIG_DIR` | `~/.config/zsh` | Configuration directory |
| `TIME_THRESHOLD` | `604800` (1 week) | Seconds between automatic plugin updates |
| `MGR_TIME_THRESHOLD` | `604800` (1 week) | Seconds between automatic manager updates |

These variables are read by `zsh-mgr` at runtime. Set them in your `.zshrc` before any `zsh-mgr` commands.

### Common threshold values

| Interval | Seconds |
|---|---|
| 1 day | `86400` |
| 3 days | `259200` |
| 1 week | `604800` |
| 2 weeks | `1209600` |
| 1 month | `2592000` |

### Files

| File | Description |
|---|---|
| `~/.config/zsh/zsh-mgr/config.json` | Configuration created by `zsh-mgr install` |
| `~/.zsh-plugins/plugins.json` | Plugin database (auto-recoverable via `zsh-mgr sync`) |
| `~/.zsh-plugins/.<plugin-name>` | Timestamp file for each plugin (last update epoch) |
| `~/.zsh-plugins/.zsh-mgr` | Timestamp file for the manager itself |
| `~/.zsh-plugins/.zsh-mgr-last-update` | Timestamp used by the auto-update shell function |
| `~/.config/zsh/default-plugins.txt` | Default plugins list for `zsh-mgr bootstrap` |

## Performance

- **Parallel updates**: All plugins update simultaneously using Rayon
- **Non-blocking**: Auto-updates run in a detached background process
- **Fast recovery**: `plugins.json` recreation takes ~19ms for 7 plugins
- **Efficient**: Optimal resource usage with thread pools
- **Safe**: Proper error handling and Git stash management
- **Smart auth**: Automatic SSH key and agent detection

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

- ~~Updater for the plugin manager itself~~ ✅
- ~~Auto-update for the plugin manager~~ ✅
- ~~Parallel updates using Rust~~ ✅
- ~~Complete CLI in Rust~~ ✅
- Delete unused plugins via CLI
- Configuration management via CLI:
  - Disable auto-update
  - Change update frequency
- Plugin dependency management

## Finding bugs

If you encounter a bug, please open an issue or create a pull request to solve it. I speak both Spanish and English.