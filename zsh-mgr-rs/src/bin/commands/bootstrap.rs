use anyhow::Result;
use colored::Colorize;
use std::fs;
use std::path::PathBuf;

pub fn run(plugins_file: Option<String>) -> Result<()> {
    // Determine plugins file path
    let file_path = if let Some(path) = plugins_file {
        PathBuf::from(shellexpand::tilde(&path).to_string())
    } else {
        // Default locations to search
        let candidates = vec![
            dirs::config_dir().map(|p| p.join("zsh/default-plugins.txt")),
            dirs::home_dir().map(|p| p.join(".config/zsh/default-plugins.txt")),
        ];
        
        candidates
            .into_iter()
            .flatten()
            .find(|p| p.exists())
            .ok_or_else(|| anyhow::anyhow!("No default-plugins.txt found"))?
    };
    
    if !file_path.exists() {
        anyhow::bail!("Plugins file not found: {}", file_path.display());
    }
    
    println!("{} Reading plugins from {}", "📋".cyan(), file_path.display());
    
    let content = fs::read_to_string(&file_path)?;
    let mut installed = 0;
    let mut skipped = 0;
    let mut failed = 0;
    
    for line in content.lines() {
        let line = line.trim();
        
        // Skip empty lines and comments
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        
        // Parse plugin and flags
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }
        
        let plugin = parts[0];
        let flags = if parts.len() > 1 {
            Some(parts[1..].join(" "))
        } else {
            None
        };
        
        println!("\n{} {}", "Installing".cyan(), plugin);
        
        // Use the add command
        match super::add::run(plugin.to_string(), flags, false) {
            Ok(_) => {
                installed += 1;
            }
            Err(e) => {
                // Check if it's because plugin already exists
                let err_msg = e.to_string();
                if err_msg.contains("already installed") {
                    println!("{} Already installed", "⚠️".yellow());
                    skipped += 1;
                } else {
                    eprintln!("{} Failed: {}", "✗".red(), e);
                    failed += 1;
                }
            }
        }
    }
    
    println!("\n{}", "═".repeat(50));
    println!("{}", "Bootstrap Summary".bright_cyan().bold());
    println!("{}", "═".repeat(50));
    println!("{} Installed: {}", "✓".green(), installed);
    println!("{} Skipped: {}", "⚠".yellow(), skipped);
    if failed > 0 {
        println!("{} Failed: {}", "✗".red(), failed);
    }
    println!("{}", "═".repeat(50));
    
    if installed > 0 || skipped > 0 {
        println!("\n{} Run 'zsh-mgr init' to update your .zshrc", "💡".bright_cyan());
    }
    
    Ok(())
}
