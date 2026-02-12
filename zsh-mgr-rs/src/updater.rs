use anyhow::Result;
use colored::Colorize;
use rayon::prelude::*;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use crate::credentials_manager::CredentialManager;
use crate::git_update::RepoUpdater;

#[derive(Debug, Clone)]
pub struct UpdateConfig {
    pub quiet: bool,
    pub verbose: bool,
}

impl UpdateConfig {
    pub fn new(quiet: bool, verbose: bool) -> Self {
        Self { quiet, verbose }
    }
}

#[derive(Debug)]
pub struct UpdateResult {
    pub path: PathBuf,
    pub success: bool,
    pub message: String,
    pub duration: f64,
}

pub struct BatchUpdateResult {
    pub results: Vec<UpdateResult>,
    pub total: usize,
    pub successful: usize,
    pub failed: usize,
}

pub struct BatchUpdater {
    config: Arc<UpdateConfig>,
    credentials: Arc<CredentialManager>,
}

impl BatchUpdater {
    pub fn new(config: Arc<UpdateConfig>, _repo_paths: &[PathBuf]) -> Result<Self> {
        let credentials = Arc::new(CredentialManager::new()
            .map_err(|e| anyhow::anyhow!("Failed to create credential manager: {}", e))?);
        Ok(Self { config, credentials })
    }
    
    pub fn update_all(&self, repo_paths: &[PathBuf]) -> BatchUpdateResult {
        let results: Vec<UpdateResult> = repo_paths
            .par_iter()
            .map(|path| self.update_single(path))
            .collect();
        
        let successful = results.iter().filter(|r| r.success).count();
        let failed = results.len() - successful;
        
        BatchUpdateResult {
            total: results.len(),
            successful,
            failed,
            results,
        }
    }
    
    fn update_single(&self, repo_path: &Path) -> UpdateResult {
        let start = Instant::now();
        let path = repo_path.to_path_buf();
        
        if !self.config.quiet {
            eprintln!("{} Updating {}...", "🔄".cyan(), path.display());
        }
        
        match RepoUpdater::new(path.clone(), self.credentials.clone()) {
            Ok(mut updater) => {
                match updater.run() {
                    Ok(_) => {
                        let duration = start.elapsed().as_secs_f64();
                        if !self.config.quiet {
                            eprintln!("{} {} - Updated successfully", "✓".green(), path.display());
                        }
                        UpdateResult {
                            path,
                            success: true,
                            message: "Updated successfully".to_string(),
                            duration,
                        }
                    }
                    Err(e) => {
                        let duration = start.elapsed().as_secs_f64();
                        if !self.config.quiet {
                            eprintln!("{} {} - {}", "✗".red(), path.display(), e);
                        }
                        UpdateResult {
                            path,
                            success: false,
                            message: e.to_string(),
                            duration,
                        }
                    }
                }
            }
            Err(e) => {
                let duration = start.elapsed().as_secs_f64();
                if !self.config.quiet {
                    eprintln!("{} {} - Failed to open repository: {}", "✗".red(), path.display(), e);
                }
                UpdateResult {
                    path,
                    success: false,
                    message: format!("Failed to open repository: {}", e),
                    duration,
                }
            }
        }
    }
}
