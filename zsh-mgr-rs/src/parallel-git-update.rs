use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use git2::{Cred, CredentialType, Repository};
use log::{debug, info, warn};
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

// ============================================================================
// CLI ARGUMENTS
// ============================================================================

#[derive(Parser, Debug)]
#[command(author, version, about = "Parallel Git Repository Updater", long_about = None)]
struct Args {
    /// List of repository paths to update
    #[arg(short, long, value_name = "PATHS", num_args = 1..)]
    repos: Vec<PathBuf>,

    /// Number of parallel jobs (default: number of CPUs)
    #[arg(short, long)]
    jobs: Option<usize>,

    /// Only fetch, don't merge
    #[arg(short, long)]
    fetch_only: bool,

    /// Pretty print JSON output
    #[arg(short, long)]
    pretty: bool,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,

    /// Quiet mode - don't output JSON (only summary)
    #[arg(short, long)]
    quiet: bool,
}

// ============================================================================
// CONFIGURATION (OOP: Encapsulated configuration object)
// ============================================================================

/// Configuration for updating repositories
#[derive(Debug, Clone)]
struct UpdateConfig {
    /// Whether to only fetch without merging
    fetch_only: bool,
    /// Verbose logging
    #[allow(dead_code)]
    verbose: bool,
}

impl UpdateConfig {
    fn new(fetch_only: bool, verbose: bool) -> Self {
        Self {
            fetch_only,
            verbose,
        }
    }
}

// ============================================================================
// CREDENTIALS MANAGER (OOP: Single responsibility for authentication)
// ============================================================================

/// Manages SSH credentials for git operations
struct CredentialsManager {
    home_dir: PathBuf,
}

impl CredentialsManager {
    fn new() -> Result<Self> {
        let home_dir = std::env::var("HOME")
            .context("HOME environment variable not set")?
            .into();
        Ok(Self { home_dir })
    }

    /// Try to get SSH credentials, attempting multiple key files
    fn get_ssh_credentials(&self, username: Option<&str>) -> Result<Cred, git2::Error> {
        let username = username.unwrap_or("git");

        // Try id_ed25519 first (more modern)
        let ed25519_key = self.home_dir.join(".ssh/id_ed25519");
        if ed25519_key.exists() {
            debug!("Trying SSH key: {}", ed25519_key.display());
            match Cred::ssh_key(username, None, &ed25519_key, None) {
                Ok(cred) => {
                    info!("Using SSH key: {}", ed25519_key.display());
                    return Ok(cred);
                }
                Err(e) => warn!("Failed to load {}: {}", ed25519_key.display(), e),
            }
        }

        // Fallback to id_rsa
        let rsa_key = self.home_dir.join(".ssh/id_rsa");
        if rsa_key.exists() {
            debug!("Trying SSH key: {}", rsa_key.display());
            match Cred::ssh_key(username, None, &rsa_key, None) {
                Ok(cred) => {
                    info!("Using SSH key: {}", rsa_key.display());
                    return Ok(cred);
                }
                Err(e) => warn!("Failed to load {}: {}", rsa_key.display(), e),
            }
        }

        // Try SSH agent as last resort
        debug!("Trying SSH agent");
        Cred::ssh_key_from_agent(username)
    }
}

// ============================================================================
// REPOSITORY UPDATER (OOP: Core business logic)
// ============================================================================

/// Handles updating a single git repository
struct RepoUpdater {
    repo_path: PathBuf,
    config: Arc<UpdateConfig>,
    credentials: Arc<CredentialsManager>,
    progress: Arc<ProgressDisplay>,
    repo_name: String,
}

impl RepoUpdater {
    fn new(
        repo_path: PathBuf,
        config: Arc<UpdateConfig>,
        credentials: Arc<CredentialsManager>,
        progress: Arc<ProgressDisplay>,
        repo_name: String,
    ) -> Self {
        Self {
            repo_path,
            config,
            credentials,
            progress,
            repo_name,
        }
    }

    /// Main update method - orchestrates fetch and merge
    fn update(&self) -> Result<UpdateResult> {
        let start = Instant::now();
        
        info!("Processing: {}", self.repo_path.display());

        // Open repository
        let repo = Repository::open(&self.repo_path)
            .with_context(|| format!("Failed to open repository: {}", self.repo_path.display()))?;

        // Get current branch
        let branch = self.get_current_branch(&repo)?;
        info!("Current branch: {}", branch);

        // Fetch from remote
        let fetch_result = self.fetch(&repo, &branch)?;

        // Merge if not fetch-only
        let merge_result = if !self.config.fetch_only {
            Some(self.merge(&repo, &branch, &fetch_result)?)
        } else {
            None
        };

        let duration = start.elapsed();

        Ok(UpdateResult {
            repo_path: self.repo_path.clone(),
            branch,
            success: true,
            fetch_info: Some(fetch_result),
            merge_info: merge_result,
            duration,
            error: None,
        })
    }

    /// Get the current branch name
    fn get_current_branch(&self, repo: &Repository) -> Result<String> {
        let head = repo.head().context("Failed to get HEAD")?;
        let branch = head
            .shorthand()
            .ok_or_else(|| anyhow::anyhow!("HEAD has no shorthand (detached)"))?
            .to_string();
        Ok(branch)
    }

    /// Fetch from remote
    fn fetch(&self, repo: &Repository, branch: &str) -> Result<FetchInfo> {
        info!("Fetching from origin/{}", branch);

        let mut remote = repo
            .find_remote("origin")
            .context("Failed to find remote 'origin'")?;

        // Setup callbacks
        let mut callbacks = git2::RemoteCallbacks::new();
        let credentials = Arc::clone(&self.credentials);

        callbacks.credentials(move |url, username_from_url, allowed_types| {
            debug!("Credentials requested for: {}", url);

            if allowed_types.contains(CredentialType::SSH_KEY) {
                return credentials.get_ssh_credentials(username_from_url);
            }

            if allowed_types.contains(CredentialType::USER_PASS_PLAINTEXT) {
                // Try credential helper
                if let Ok(config) = Repository::open_from_env().and_then(|r| r.config()) {
                    if let Ok(cred) = Cred::credential_helper(&config, url, username_from_url) {
                        return Ok(cred);
                    }
                }
            }

            Err(git2::Error::from_str("No valid credentials available"))
        });

        let mut fetch_options = git2::FetchOptions::new();
        fetch_options.remote_callbacks(callbacks);

        // Fetch
        remote
            .fetch(&[branch], Some(&mut fetch_options), None)
            .context("Fetch failed")?;

        let stats = remote.stats();
        
        Ok(FetchInfo {
            objects_received: stats.received_objects(),
            bytes_received: stats.received_bytes(),
        })
    }

    /// Merge fetched changes
    fn merge(&self, repo: &Repository, branch: &str, _fetch_info: &FetchInfo) -> Result<MergeInfo> {
        // Update progress to merging
        self.progress.update_status(&self.repo_name, RepoStatus::Merging);
        
        let fetch_head = repo
            .find_reference("FETCH_HEAD")
            .context("FETCH_HEAD not found")?;
        
        let fetch_commit = repo
            .reference_to_annotated_commit(&fetch_head)
            .context("Failed to convert FETCH_HEAD to annotated commit")?;

        let analysis = repo.merge_analysis(&[&fetch_commit])?;

        if analysis.0.is_fast_forward() {
            info!("Fast-forward merge");
            self.do_fast_forward(repo, branch, &fetch_commit)?;
            Ok(MergeInfo {
                merge_type: MergeType::FastForward,
                conflicts: false,
            })
        } else if analysis.0.is_normal() {
            warn!("Normal merge required");
            self.do_normal_merge(repo, &fetch_commit)?;
            Ok(MergeInfo {
                merge_type: MergeType::Normal,
                conflicts: false,
            })
        } else if analysis.0.is_up_to_date() {
            info!("Already up to date");
            Ok(MergeInfo {
                merge_type: MergeType::UpToDate,
                conflicts: false,
            })
        } else {
            Ok(MergeInfo {
                merge_type: MergeType::None,
                conflicts: false,
            })
        }
    }

    /// Perform fast-forward merge
    fn do_fast_forward(
        &self,
        repo: &Repository,
        branch: &str,
        fetch_commit: &git2::AnnotatedCommit,
    ) -> Result<()> {
        let refname = format!("refs/heads/{}", branch);
        
        match repo.find_reference(&refname) {
            Ok(mut r) => {
                r.set_target(fetch_commit.id(), "Fast-forward")?;
                repo.set_head(&refname)?;
                repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))?;
            }
            Err(_) => {
                repo.reference(&refname, fetch_commit.id(), true, "Fast-forward")?;
                repo.set_head(&refname)?;
                repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))?;
            }
        }
        
        Ok(())
    }

    /// Perform normal merge
    fn do_normal_merge(&self, repo: &Repository, remote: &git2::AnnotatedCommit) -> Result<()> {
        let head_commit = repo.reference_to_annotated_commit(&repo.head()?)?;
        
        let local_tree = repo.find_commit(head_commit.id())?.tree()?;
        let remote_tree = repo.find_commit(remote.id())?.tree()?;
        let ancestor = repo
            .find_commit(repo.merge_base(head_commit.id(), remote.id())?)?
            .tree()?;

        let mut idx = repo.merge_trees(&ancestor, &local_tree, &remote_tree, None)?;

        if idx.has_conflicts() {
            warn!("Merge conflicts detected");
            repo.checkout_index(Some(&mut idx), None)?;
            return Ok(());
        }

        let result_tree = repo.find_tree(idx.write_tree_to(repo)?)?;
        let msg = format!("Merge: {} into {}", remote.id(), head_commit.id());
        let sig = repo.signature()?;
        let local_commit = repo.find_commit(head_commit.id())?;
        let remote_commit = repo.find_commit(remote.id())?;

        repo.commit(
            Some("HEAD"),
            &sig,
            &sig,
            &msg,
            &result_tree,
            &[&local_commit, &remote_commit],
        )?;

        repo.checkout_head(None)?;
        Ok(())
    }
}

// ============================================================================
// PROGRESS DISPLAY (OOP: Manages console output for parallel updates)
// ============================================================================

/// Status of a repository update
#[derive(Debug, Clone)]
enum RepoStatus {
    Pending,
    Fetching,
    Merging,
    Success,
    Failed(String),
}

impl RepoStatus {
    fn to_string(&self, repo_name: &str) -> String {
        match self {
            RepoStatus::Pending => format!("⏳ {} {} {}", "[".bright_black(), format!("{:<50}", repo_name).bright_black(), "]".bright_black()),
            RepoStatus::Fetching => format!("🔄 {} {} {}", "[".cyan(), format!("{:<50}", repo_name).cyan(), "]".cyan()),
            RepoStatus::Merging => format!("⬇️  {} {} {}", "[".yellow(), format!("{:<50}", repo_name).yellow(), "]".yellow()),
            RepoStatus::Success => format!("✓ {} {} {}", "[".green(), format!("{:<50}", repo_name).green(), "]".green()),
            RepoStatus::Failed(err) => format!("✗ {} {} {} - {}", "[".red(), format!("{:<50}", repo_name).red(), "]".red(), err.red()),
        }
    }
}

/// Manages real-time progress display for parallel updates
struct ProgressDisplay {
    statuses: Arc<Mutex<Vec<(String, RepoStatus)>>>,
}

impl ProgressDisplay {
    fn new(repo_paths: &[PathBuf]) -> Self {
        let statuses = repo_paths
            .iter()
            .map(|path| {
                let name = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
                    .to_string();
                (name, RepoStatus::Pending)
            })
            .collect();

        Self {
            statuses: Arc::new(Mutex::new(statuses)),
        }
    }

    fn update_status(&self, repo_name: &str, status: RepoStatus) {
        if let Ok(mut statuses) = self.statuses.lock() {
            if let Some(entry) = statuses.iter_mut().find(|(name, _)| name == repo_name) {
                entry.1 = status;
            }
            self.redraw(&statuses);
        }
    }

    fn redraw(&self, statuses: &[(String, RepoStatus)]) {
        // Move cursor up to the beginning of our progress section
        print!("\r");
        for (i, (_name, _status)) in statuses.iter().enumerate() {
            if i > 0 {
                print!("\x1B[1A"); // Move cursor up one line
            }
            print!("\r\x1B[2K"); // Clear line
        }
        
        // Move cursor back to top
        if !statuses.is_empty() {
            print!("\x1B[{}A", statuses.len() - 1);
        }

        // Redraw all lines
        for (name, status) in statuses {
            println!("\r{}", status.to_string(name));
        }
        
        io::stdout().flush().ok();
    }

    fn initial_draw(&self) {
        if let Ok(statuses) = self.statuses.lock() {
            for (name, status) in statuses.iter() {
                println!("{}", status.to_string(name));
            }
        }
    }
}

// ============================================================================
// BATCH UPDATER (OOP: Orchestrates parallel updates)
// ============================================================================

/// Manages parallel updates of multiple repositories
struct BatchUpdater {
    config: Arc<UpdateConfig>,
    credentials: Arc<CredentialsManager>,
    progress: Arc<ProgressDisplay>,
}

impl BatchUpdater {
    fn new(config: UpdateConfig, repo_paths: &[PathBuf]) -> Result<Self> {
        let credentials = Arc::new(CredentialsManager::new()?);
        let progress = Arc::new(ProgressDisplay::new(repo_paths));
        Ok(Self {
            config: Arc::new(config),
            credentials,
            progress,
        })
    }

    /// Update multiple repositories in parallel
    fn update_all(&self, repo_paths: &[PathBuf]) -> BatchUpdateResults {
        // Draw initial progress display
        self.progress.initial_draw();
        eprintln!(); // Add blank line after progress
        
        let progress = Arc::clone(&self.progress);
        let results: Vec<UpdateResult> = repo_paths
            .par_iter()
            .map(|path| {
                let repo_name = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
                    .to_string();
                
                // Update status to Fetching
                progress.update_status(&repo_name, RepoStatus::Fetching);
                
                let updater = RepoUpdater::new(
                    path.clone(),
                    Arc::clone(&self.config),
                    Arc::clone(&self.credentials),
                    Arc::clone(&progress),
                    repo_name.clone(),
                );

                match updater.update() {
                    Ok(result) => {
                        progress.update_status(&repo_name, RepoStatus::Success);
                        result
                    }
                    Err(e) => {
                        let error_msg = format!("{:#}", e);
                        progress.update_status(&repo_name, RepoStatus::Failed(error_msg.clone()));
                        UpdateResult {
                            repo_path: path.clone(),
                            branch: String::from("unknown"),
                            success: false,
                            fetch_info: None,
                            merge_info: None,
                            duration: Duration::ZERO,
                            error: Some(error_msg),
                        }
                    }
                }
            })
            .collect();

        let successful = results.iter().filter(|r| r.success).count();
        let failed = results.len() - successful;

        BatchUpdateResults {
            total: results.len(),
            successful,
            failed,
            results,
        }
    }
}

// ============================================================================
// RESULT TYPES (OOP: Clear data structures)
// ============================================================================

#[derive(Debug, Serialize, Deserialize)]
struct FetchInfo {
    objects_received: usize,
    bytes_received: usize,
}

#[derive(Debug, Serialize, Deserialize)]
enum MergeType {
    FastForward,
    Normal,
    UpToDate,
    None,
}

#[derive(Debug, Serialize, Deserialize)]
struct MergeInfo {
    merge_type: MergeType,
    conflicts: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct UpdateResult {
    repo_path: PathBuf,
    branch: String,
    success: bool,
    fetch_info: Option<FetchInfo>,
    merge_info: Option<MergeInfo>,
    #[serde(with = "humantime_serde")]
    duration: Duration,
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct BatchUpdateResults {
    total: usize,
    successful: usize,
    failed: usize,
    results: Vec<UpdateResult>,
}

// ============================================================================
// MAIN
// ============================================================================

fn main() -> Result<()> {
    // Print initial newline for better prompt spacing
    eprintln!();
    
    let args = Args::parse();

    // Initialize logger
    if args.verbose {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn")).init();
    }

    // Validate repositories
    for repo in &args.repos {
        anyhow::ensure!(
            repo.exists(),
            "Repository does not exist: {}",
            repo.display()
        );
    }

    // Configure thread pool
    if let Some(jobs) = args.jobs {
        rayon::ThreadPoolBuilder::new()
            .num_threads(jobs)
            .build_global()
            .context("Failed to build thread pool")?;
    }

    info!("Updating {} repositories...", args.repos.len());
    let start = Instant::now();

    // Create updater and run
    let config = UpdateConfig::new(args.fetch_only, args.verbose);
    let updater = BatchUpdater::new(config, &args.repos)?;
    let results = updater.update_all(&args.repos);

    let total_duration = start.elapsed();

    // Print summary to stderr
    eprintln!("\n{}", "=".repeat(60).blue());
    eprintln!(
        "{} {} repositories in {:.2}s",
        "✓".green().bold(),
        "Updated".green().bold(),
        total_duration.as_secs_f64()
    );
    eprintln!(
        "  {} successful, {} failed",
        results.successful.to_string().green(),
        if results.failed > 0 {
            results.failed.to_string().red()
        } else {
            results.failed.to_string().normal()
        }
    );
    eprintln!("{}", "=".repeat(60).blue());

    // Output JSON to stdout (unless quiet mode)
    if !args.quiet {
        if args.pretty {
            println!("{}", serde_json::to_string_pretty(&results)?);
        } else {
            println!("{}", serde_json::to_string(&results)?);
        }
    }

    // Exit with error code if any failed
    if results.failed > 0 {
        std::process::exit(1);
    }

    Ok(())
}

// Helper module for duration serialization
mod humantime_serde {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    use std::time::Duration;

    pub fn serialize<S>(duration: &Duration, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        duration.as_secs_f64().serialize(serializer)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Duration, D::Error>
    where
        D: Deserializer<'de>,
    {
        let secs = f64::deserialize(deserializer)?;
        Ok(Duration::from_secs_f64(secs))
    }
}
