use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

/// Get the real home directory of the current user from the system's passwd database.
/// This ignores `$HOME`, which `sudo` can preserve incorrectly (pointing to
/// another user's home).  We look up the effective UID and resolve it through
/// `getent passwd <uid>`.
pub fn real_home_dir() -> Option<PathBuf> {
    use std::process::Command;

    // 1. Obtain the current effective UID
    let uid_output = Command::new("id").arg("-u").output().ok()?;
    if !uid_output.status.success() {
        return dirs::home_dir();
    }
    let uid = String::from_utf8_lossy(&uid_output.stdout);
    let uid = uid.trim();

    // 2. Look up the passwd entry for that UID
    let pw_output = Command::new("getent")
        .args(["passwd", uid])
        .output()
        .ok()?;
    if pw_output.status.success() {
        let line = String::from_utf8_lossy(&pw_output.stdout);
        // Format: name:x:uid:gid:gecos:home:shell
        if let Some(home) = line.split(':').nth(5) {
            let home = home.trim();
            if !home.is_empty() {
                return Some(PathBuf::from(home));
            }
        }
    }

    // Fallback to dirs::home_dir() (uses $HOME)
    dirs::home_dir()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub plugin_dir: PathBuf,
    pub config_dir: PathBuf,
    pub time_threshold: u64,
    pub mgr_time_threshold: u64,
}

impl Config {
    /// Load configuration from environment or defaults
    pub fn load() -> Result<Self> {
        let home = real_home_dir().context("Cannot determine HOME directory")?;
        
        let plugin_dir = std::env::var("ZSH_PLUGIN_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| home.join(".zsh-plugins"));
        
        let config_dir = std::env::var("ZSH_CONFIG_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| home.join(".config/zsh"));
        
        let time_threshold = std::env::var("TIME_THRESHOLD")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(604800); // 1 week
        
        let mgr_time_threshold = std::env::var("MGR_TIME_THRESHOLD")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(604800);
        
        Ok(Self {
            plugin_dir,
            config_dir,
            time_threshold,
            mgr_time_threshold,
        })
    }
    
    /// Save configuration to file
    pub fn save(&self, path: &Path) -> Result<()> {
        let json = serde_json::to_string_pretty(self)?;
        fs::write(path, json)?;
        Ok(())
    }
    
    /// Load configuration from file
    pub fn from_file(path: &Path) -> Result<Self> {
        let contents = fs::read_to_string(path)?;
        let config = serde_json::from_str(&contents)?;
        Ok(config)
    }
    
    /// Get plugin list file path
    /// Get plugin list file path
    pub fn plugin_list_file(&self) -> PathBuf {
        self.plugin_dir.join("plugins.json")
    }
    
    /// Get timestamp file for a plugin
    pub fn timestamp_file(&self, plugin_name: &str) -> PathBuf {
        // Extract just the repo name (after last '/')
        let repo_name = plugin_name.split('/').last().unwrap_or(plugin_name);
        self.plugin_dir.join(format!(".{}", repo_name))
    }
    
    /// Get manager timestamp file
    pub fn manager_timestamp_file(&self) -> PathBuf {
        self.plugin_dir.join(".zsh-mgr")
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginInfo {
    pub name: String,
    pub url: String,
    pub private: bool,
    pub flags: Option<String>,
    pub installed_at: u64,
    pub last_updated: u64,
}

impl PluginInfo {
    pub fn new(name: String, url: String, private: bool, flags: Option<String>) -> Self {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        Self {
            name,
            url,
            private,
            flags,
            installed_at: now,
            last_updated: now,
        }
    }
}

/// Plugin list manager
pub struct PluginList {
    plugins: Vec<PluginInfo>,
    file_path: PathBuf,
}

impl PluginList {
    pub fn load(config: &Config) -> Result<Self> {
        let file_path = config.plugin_list_file();
        
        let plugins = if file_path.exists() {
            let contents = fs::read_to_string(&file_path)?;
            serde_json::from_str(&contents)?
        } else {
            // Auto-sync if plugins.json doesn't exist
            eprintln!("ℹ️  plugins.json not found, auto-syncing from directory...");
            return Self::sync_from_directory(config);
        };
        
        Ok(Self { plugins, file_path })
    }
    
    pub fn save(&self) -> Result<()> {
        // Create parent directory if it doesn't exist
        if let Some(parent) = self.file_path.parent() {
            fs::create_dir_all(parent)?;
        }
        
        let json = serde_json::to_string_pretty(&self.plugins)?;
        fs::write(&self.file_path, json)?;
        Ok(())
    }
    
    pub fn add(&mut self, plugin: PluginInfo) {
        self.plugins.push(plugin);
    }
    
    pub fn remove(&mut self, name: &str) -> Option<PluginInfo> {
        if let Some(index) = self.plugins.iter().position(|p| p.name == name) {
            Some(self.plugins.remove(index))
        } else {
            None
        }
    }
    
    pub fn get(&self, name: &str) -> Option<&PluginInfo> {
        self.plugins.iter().find(|p| p.name == name)
    }
    
    pub fn list(&self) -> &[PluginInfo] {
        &self.plugins
    }
    
    pub fn update_timestamp(&mut self, name: &str, timestamp: u64) {
        if let Some(plugin) = self.plugins.iter_mut().find(|p| p.name == name) {
            plugin.last_updated = timestamp;
        }
    }
    
    /// Sync plugins.json from directories in plugin_dir
    pub fn sync_from_directory(config: &Config) -> Result<Self> {
        use std::collections::HashSet;
        
        let file_path = config.plugin_list_file();
        let mut plugins = Vec::new();
        let mut seen = HashSet::new();
        
        // Scan plugin directory for git repositories
        if config.plugin_dir.exists() {
            for entry in fs::read_dir(&config.plugin_dir)? {
                let entry = entry?;
                let path = entry.path();
                
                if !path.is_dir() {
                    continue;
                }
                
                // Skip hidden directories and plugins.json
                let dir_name = path.file_name().unwrap().to_string_lossy();
                if dir_name.starts_with('.') || dir_name == "plugins.json" {
                    continue;
                }
                
                // Check if it's a git repository
                let git_dir = path.join(".git");
                if git_dir.exists() {
                    // It's a flat structure plugin (e.g., fzf-tab/)
                    if let Some(plugin_info) = Self::extract_plugin_info(&path)? {
                        if seen.insert(plugin_info.name.clone()) {
                            plugins.push(plugin_info);
                        }
                    }
                } else {
                    // Maybe it's a user/repo structure, check subdirectories
                    if let Ok(subdirs) = fs::read_dir(&path) {
                        for subentry in subdirs {
                            if let Ok(subentry) = subentry {
                                let subpath = subentry.path();
                                if subpath.is_dir() && subpath.join(".git").exists() {
                                    if let Some(plugin_info) = Self::extract_plugin_info(&subpath)? {
                                        if seen.insert(plugin_info.name.clone()) {
                                            plugins.push(plugin_info);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let plugin_list = Self { plugins, file_path };
        plugin_list.save()?;
        Ok(plugin_list)
    }
    
    fn extract_plugin_info(repo_path: &std::path::Path) -> Result<Option<PluginInfo>> {
        use std::process::Command;
        
        // Get remote URL
        let output = Command::new("git")
            .arg("-C")
            .arg(repo_path)
            .arg("remote")
            .arg("get-url")
            .arg("origin")
            .output()?;
        
        if !output.status.success() {
            return Ok(None);
        }
        
        let url = String::from_utf8_lossy(&output.stdout).trim().to_string();
        
        // Parse user/repo from URL
        // Formats: https://github.com/user/repo.git or git@github.com:user/repo.git
        let name = if let Some(caps) = url.strip_prefix("https://github.com/") {
            caps.trim_end_matches(".git").to_string()
        } else if let Some(caps) = url.strip_prefix("git@github.com:") {
            caps.trim_end_matches(".git").to_string()
        } else {
            // Can't parse, use directory name as fallback
            repo_path.file_name()
                .unwrap()
                .to_string_lossy()
                .to_string()
        };
        
        let private = url.starts_with("git@");
        
        // Get last update timestamp
        let timestamp_file = repo_path.parent()
            .unwrap()
            .join(format!(".{}", repo_path.file_name().unwrap().to_string_lossy()));
        
        let last_updated = if timestamp_file.exists() {
            fs::read_to_string(&timestamp_file)
                .ok()
                .and_then(|s| s.trim().parse().ok())
                .unwrap_or_else(|| {
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_secs()
                })
        } else {
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        };
        
        // Check for depth flag in .git/config
        let git_config = repo_path.join(".git/config");
        let flags = if git_config.exists() {
            if let Ok(config_content) = fs::read_to_string(&git_config) {
                if config_content.contains("depth = 1") {
                    Some("--depth 1".to_string())
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        };
        
        Ok(Some(PluginInfo {
            name,
            url,
            private,
            flags,
            installed_at: last_updated,  // Use same timestamp for both
            last_updated,
        }))
    }
}
