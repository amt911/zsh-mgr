use anyhow::Result;
use colored::Colorize;
use std::io::{self, Write};
use zsh_mgr_rs::config::{Config, PluginList};

pub fn run(plugin: String, force: bool) -> Result<()> {
    let config = Config::load()?;
    let mut plugin_list = PluginList::load(&config)?;
    
    // Check if plugin exists
    if plugin_list.get(&plugin).is_none() {
        eprintln!("{} Plugin '{}' is not installed", "⚠️".yellow(), plugin);
        return Ok(());
    }
    
    // Confirm removal if not forced
    if !force {
        print!("{} Are you sure you want to remove '{}'? [y/N] ", "?".yellow(), plugin);
        io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("{} Removal cancelled", "ℹ️".blue());
            return Ok(());
        }
    }
    
    // Remove from list
    plugin_list.remove(&plugin);
    plugin_list.save()?;
    
    // Remove directory
    let plugin_dir = config.plugin_dir.join(&plugin);
    if plugin_dir.exists() {
        std::fs::remove_dir_all(&plugin_dir)?;
    }
    
    // Remove timestamp file
    let timestamp_file = config.timestamp_file(&plugin);
    if timestamp_file.exists() {
        std::fs::remove_file(&timestamp_file)?;
    }
    
    println!("{} Plugin '{}' removed successfully", "✓".green(), plugin);
    
    Ok(())
}
