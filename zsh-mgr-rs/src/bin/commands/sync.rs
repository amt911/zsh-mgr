use anyhow::Result;
use colored::Colorize;
use zsh_mgr_rs::config::{Config, PluginList};

pub fn run(force: bool) -> Result<()> {
    let config = Config::load()?;
    let plugin_list_file = config.plugin_list_file();
    
    // Check if plugins.json already exists
    if plugin_list_file.exists() && !force {
        println!("{} {} already exists", "ℹ️".cyan(), plugin_list_file.display());
        println!("Use --force to regenerate it");
        println!("\nCurrent plugins:");
        
        let plugin_list = PluginList::load(&config)?;
        for plugin in plugin_list.list() {
            println!("  {} {}", "•".green(), plugin.name);
        }
        
        return Ok(());
    }
    
    println!("{} Scanning {} for Git repositories...", "🔍".cyan(), config.plugin_dir.display());
    
    let plugin_list = PluginList::sync_from_directory(&config)?;
    
    if plugin_list.list().is_empty() {
        println!("{} No Git repositories found", "⚠️".yellow());
        println!("Install plugins with: zsh-mgr add <user/repo>");
        return Ok(());
    }
    
    println!("{} Synced {} to {}", "✓".green(), 
        format!("{} plugins", plugin_list.list().len()).bold(),
        plugin_list_file.display());
    
    println!("\n{}", "Found plugins:".bright_cyan());
    for plugin in plugin_list.list() {
        let flags_str = if let Some(ref flags) = plugin.flags {
            format!(" ({})", flags.bright_black())
        } else {
            String::new()
        };
        println!("  {} {}{}", "•".green(), plugin.name, flags_str);
    }
    
    println!("\n{} Run 'zsh-mgr init' to update your .zshrc", "💡".bright_cyan());
    
    Ok(())
}
