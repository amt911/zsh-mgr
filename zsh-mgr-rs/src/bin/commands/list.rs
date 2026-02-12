use anyhow::Result;
use colored::Colorize;
use zsh_mgr_rs::config::{Config, PluginList};

pub fn run(json: bool, names_only: bool) -> Result<()> {
    let config = Config::load()?;
    let plugin_list = PluginList::load(&config)?;
    
    let plugins = plugin_list.list();
    
    if plugins.is_empty() {
        eprintln!("{} No plugins installed", "ℹ️".blue());
        return Ok(());
    }
    
    if names_only {
        // Output only the plugin names (repo name after last '/')
        for plugin in plugins {
            let repo_name = plugin.name.split('/').last().unwrap_or(&plugin.name);
            println!("{}", repo_name);
        }
    } else if json {
        println!("{}", serde_json::to_string_pretty(&plugins)?);
    } else {
        println!("{} Installed plugins:", "📦".cyan());
        println!();
        for plugin in plugins {
            let private_marker = if plugin.private { "🔒" } else { "  " };
            println!("  {} {}", private_marker, plugin.name.bright_white());
            println!("     URL: {}", plugin.url.dimmed());
            if let Some(ref flags) = plugin.flags {
                println!("     Flags: {}", flags.dimmed());
            }
            println!();
        }
        println!("{} Total: {} plugins", "✓".green(), plugins.len());
    }
    
    Ok(())
}
