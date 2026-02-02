use anyhow::Result;
use colored::Colorize;
use std::sync::Arc;
use zsh_mgr_rs::config::{Config, PluginList};
use zsh_mgr_rs::updater::{BatchUpdater, UpdateConfig};

pub fn run(only: Option<Vec<String>>, verbose: bool, jobs: Option<usize>) -> Result<()> {
    let config = Config::load()?;
    let mut plugin_list = PluginList::load(&config)?;
    
    // Configure thread pool
    if let Some(j) = jobs {
        rayon::ThreadPoolBuilder::new()
            .num_threads(j)
            .build_global()?;
    }
    
    // Get plugins to update
    let plugins: Vec<_> = if let Some(filter) = only {
        plugin_list
            .list()
            .iter()
            .filter(|p| filter.contains(&p.name))
            .cloned()
            .collect()
    } else {
        plugin_list.list().to_vec()
    };
    
    if plugins.is_empty() {
        eprintln!("{} No plugins to update", "ℹ️".blue());
        return Ok(());
    }
    
    // Build repository paths
    let repo_paths: Vec<_> = plugins
        .iter()
        .map(|p| config.plugin_dir.join(&p.name))
        .collect();
    
    // Create updater
    let update_config = UpdateConfig::new(false, verbose);
    let updater = BatchUpdater::new(Arc::new(update_config), &repo_paths)?;
    
    // Update repositories
    println!("{} Updating {} plugins...", "🔄".cyan(), plugins.len());
    let results = updater.update_all(&repo_paths);
    
    // Update timestamps
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    
    for (plugin, result) in plugins.iter().zip(results.results.iter()) {
        if result.success {
            std::fs::write(config.timestamp_file(&plugin.name), now.to_string())?;
            plugin_list.update_timestamp(&plugin.name, now);
        }
    }
    
    plugin_list.save()?;
    
    // Print summary
    eprintln!();
    eprintln!("══════════════════════════════════════════════════════════");
    if results.failed == 0 {
        eprintln!(
            "{} Updated {} repositories in {:.2}s",
            "✓".green(),
            results.total,
            results.results.iter().map(|r| r.duration).sum::<f64>() / results.total as f64
        );
    } else {
        eprintln!(
            "{} Updated repositories: {} successful, {} failed",
            "⚠".yellow(),
            results.successful.to_string().green(),
            results.failed.to_string().red()
        );
    }
    eprintln!("══════════════════════════════════════════════════════════");
    
    Ok(())
}
