use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

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
        let home = dirs::home_dir().context("Cannot determine HOME directory")?;
        
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
    pub fn plugin_list_file(&self) -> PathBuf {
        self.config_dir.join("zsh-mgr").join("plugins.json")
    }
    
    /// Get timestamp file for a plugin
    pub fn timestamp_file(&self, plugin_name: &str) -> PathBuf {
        self.plugin_dir.join(format!(".{}", plugin_name))
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
            Vec::new()
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
}
