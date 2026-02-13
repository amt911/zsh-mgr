use anyhow::{Context, Result};
use colored::Colorize;
use std::fs;
use std::io::{self, Write};
use zsh_mgr_rs::config::{Config, real_home_dir};

pub fn run(
    plugin_dir: Option<String>,
    time_threshold: u64,
    mgr_time_threshold: u64,
    quiet: bool,
) -> Result<()> {
    println!("{}", "╔══════════════════════════════════════════════╗".cyan());
    println!("{}", "║     ZSH Manager - Installation Wizard       ║".cyan());
    println!("{}", "╚══════════════════════════════════════════════╝".cyan());
    println!();
    
    // Check if installed via package manager
    let installed_via_package = is_installed_via_package()?;
    
    if installed_via_package {
        println!("{} Detected system package installation", "ℹ️".blue());
        println!("{} Using system-wide configuration", "✓".green());
    }
    
    // Determine plugin directory
    let home = real_home_dir().context("Cannot determine HOME directory")?;
    let plugin_dir = if let Some(dir) = plugin_dir {
        std::path::PathBuf::from(shellexpand::tilde(&dir).to_string())
    } else if quiet || installed_via_package {
        home.join(".zsh-plugins")
    } else {
        prompt_plugin_directory(&home)?
    };
    
    // Create directories
    let config_dir = home.join(".config/zsh");
    fs::create_dir_all(&config_dir)?;
    fs::create_dir_all(&plugin_dir)?;
    
    // Create config
    let config = Config {
        plugin_dir: plugin_dir.clone(),
        config_dir: config_dir.clone(),
        time_threshold,
        mgr_time_threshold,
    };
    
    let config_file = config_dir.join("zsh-mgr").join("config.json");
    fs::create_dir_all(config_file.parent().unwrap())?;
    config.save(&config_file)?;
    
    // Add to .zshrc
    add_to_zshrc(&home, &config, installed_via_package)?;
    
    println!();
    println!("{} zsh-mgr installed successfully!", "✓".green());
    println!();
    println!("{} Next steps:", "📝".bright_cyan());
    println!("   1. Restart your terminal or run: source ~/.zshrc");
    println!("   2. Add plugins: zsh-mgr add <user/repo>");
    println!("   3. Check status: zsh-mgr check");
    
    Ok(())
}

fn is_installed_via_package() -> Result<bool> {
    // Check if binary is in /usr/bin or /usr/local/bin
    if let Ok(exe_path) = std::env::current_exe() {
        let path_str = exe_path.to_string_lossy();
        Ok(path_str.starts_with("/usr/bin") || path_str.starts_with("/usr/local/bin"))
    } else {
        Ok(false)
    }
}

fn prompt_plugin_directory(home: &std::path::Path) -> Result<std::path::PathBuf> {
    print!("{} Plugin directory (press Enter for default: ~/.zsh-plugins): ", "?".yellow());
    io::stdout().flush()?;
    
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    
    let input = input.trim();
    if input.is_empty() {
        Ok(home.join(".zsh-plugins"))
    } else {
        Ok(std::path::PathBuf::from(shellexpand::tilde(input).to_string()))
    }
}

fn add_to_zshrc(home: &std::path::Path, config: &Config, system_install: bool) -> Result<()> {
    let zshrc = home.join(".zshrc");
    
    if !zshrc.exists() {
        fs::write(&zshrc, "")?;
    }
    
    let content = fs::read_to_string(&zshrc)?;
    
    // Check if already configured
    if content.contains("zsh-mgr") {
        println!("{} .zshrc already configured", "ℹ️".blue());
        return Ok(());
    }
    
    let init_code = if system_install {
        format!(
            r#"
# zsh-mgr configuration (system package)
export ZSH_PLUGIN_DIR="{}"
export ZSH_CONFIG_DIR="{}"
export TIME_THRESHOLD={}
export MGR_TIME_THRESHOLD={}

# Initialize zsh-mgr if installed
if command -v zsh-mgr &> /dev/null; then
    # Source installed plugins
    for plugin in "$ZSH_PLUGIN_DIR"/*/*.plugin.zsh; do
        [ -f "$plugin" ] && source "$plugin"
    done
fi
"#,
            config.plugin_dir.display(),
            config.config_dir.display(),
            config.time_threshold,
            config.mgr_time_threshold
        )
    } else {
        format!(
            r#"
# zsh-mgr configuration
export ZSH_PLUGIN_DIR="{}"
export ZSH_CONFIG_DIR="{}"
export TIME_THRESHOLD={}
export MGR_TIME_THRESHOLD={}

# Source installed plugins
for plugin in "$ZSH_PLUGIN_DIR"/*/*.plugin.zsh; do
    [ -f "$plugin" ] && source "$plugin"
done
"#,
            config.plugin_dir.display(),
            config.config_dir.display(),
            config.time_threshold,
            config.mgr_time_threshold
        )
    };
    
    // Append to .zshrc
    fs::write(&zshrc, format!("{}\n{}", content, init_code))?;
    
    println!("{} Added configuration to ~/.zshrc", "✓".green());
    
    Ok(())
}
