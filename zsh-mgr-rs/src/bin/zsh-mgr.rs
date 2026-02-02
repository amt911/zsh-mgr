use anyhow::Result;
use clap::{Parser, Subcommand};

mod commands;
use commands::*;

#[derive(Parser)]
#[command(name = "zsh-mgr")]
#[command(about = "ZSH Plugin Manager written in Rust", long_about = None)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Add a new plugin
    Add {
        /// Plugin in format "user/repo"
        plugin: String,
        
        /// Git clone flags
        #[arg(short, long)]
        flags: Option<String>,
        
        /// Private repository (use SSH)
        #[arg(short, long)]
        private: bool,
    },
    
    /// Update all plugins
    Update {
        /// Update only specific plugins
        #[arg(short, long)]
        only: Option<Vec<String>>,
        
        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
        
        /// Parallel jobs
        #[arg(short, long)]
        jobs: Option<usize>,
    },
    
    /// Check next update dates
    Check {
        /// Show only plugins
        #[arg(short, long)]
        plugins: bool,
        
        /// Show only manager
        #[arg(short, long)]
        manager: bool,
        
        /// Output as JSON
        #[arg(short, long)]
        json: bool,
    },
    
    /// List installed plugins
    List {
        /// Output as JSON
        #[arg(short, long)]
        json: bool,
    },
    
    /// Remove a plugin
    Remove {
        /// Plugin name
        plugin: String,
        
        /// Force removal without confirmation
        #[arg(short, long)]
        force: bool,
    },
    
    /// Install zsh-mgr for the first time
    Install {
        /// Plugin directory
        #[arg(short, long)]
        plugin_dir: Option<String>,
        
        /// Update interval in seconds
        #[arg(short = 't', long, default_value = "604800")]
        time_threshold: u64,
        
        /// Manager update interval in seconds
        #[arg(short = 'm', long, default_value = "604800")]
        mgr_time_threshold: u64,
        
        /// Quiet mode (no prompts)
        #[arg(short, long)]
        quiet: bool,
    },
}

fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    
    let cli = Cli::parse();
    
    match cli.command {
        Commands::Add { plugin, flags, private } => {
            add::run(plugin, flags, private)
        }
        Commands::Update { only, verbose, jobs } => {
            update::run(only, verbose, jobs)
        }
        Commands::Check { plugins, manager, json } => {
            check::run(plugins, manager, json)
        }
        Commands::List { json } => {
            list::run(json)
        }
        Commands::Remove { plugin, force } => {
            remove::run(plugin, force)
        }
        Commands::Install { plugin_dir, time_threshold, mgr_time_threshold, quiet } => {
            install::run(plugin_dir, time_threshold, mgr_time_threshold, quiet)
        }
    }
}
