use anyhow::{Context, Result};
use colored::Colorize;
use std::process::Command;
use zsh_mgr_rs::config::{Config, PluginInfo, PluginList};

pub fn run(plugin: String, flags: Option<String>, private: bool) -> Result<()> {
    let config = Config::load()?;
    let mut plugin_list = PluginList::load(&config)?;
    
    // Check if plugin already exists
    if plugin_list.get(&plugin).is_some() {
        eprintln!("{} Plugin '{}' is already installed", "⚠️".yellow(), plugin);
        return Ok(());
    }
    
    // Build URL
    let url = if private {
        format!("git@github.com:{}.git", plugin)
    } else {
        format!("https://github.com/{}.git", plugin)
    };
    
    // Plugin directory
    let plugin_dir = config.plugin_dir.join(&plugin);
    
    // Clone repository
    println!("{} Cloning {}...", "📦".cyan(), plugin);
    
    let mut cmd = Command::new("git");
    cmd.arg("clone");
    
    if let Some(ref f) = flags {
        for flag in f.split_whitespace() {
            cmd.arg(flag);
        }
    }
    
    cmd.arg(&url).arg(&plugin_dir);
    
    let status = cmd.status().context("Failed to execute git clone")?;
    
    if !status.success() {
        anyhow::bail!("Git clone failed for {}", plugin);
    }
    
    // Add to plugin list
    let plugin_info = PluginInfo::new(plugin.clone(), url, private, flags);
    plugin_list.add(plugin_info);
    plugin_list.save()?;
    
    // Create timestamp file
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    
    std::fs::write(config.timestamp_file(&plugin), now.to_string())?;
    
    println!("{} Plugin '{}' installed successfully", "✓".green(), plugin);
    println!("{} Add this to your .zshrc:", "💡".bright_cyan());
    println!("   source {}", plugin_dir.join("*.plugin.zsh").display());
    
    Ok(())
}
