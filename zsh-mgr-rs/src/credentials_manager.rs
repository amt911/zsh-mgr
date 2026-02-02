use git2::{Cred, CredentialType, RemoteCallbacks, Repository};
use std::env;
use std::path::PathBuf;

/// Manages authentication credentials for Git operations
/// Follows OOP principles with encapsulated credential logic
#[derive(Clone)]
pub struct CredentialManager {
    home_dir: PathBuf,
}

impl CredentialManager {
    /// Create a new CredentialManager instance
    pub fn new() -> Result<Self, String> {
        let home_dir = env::var("HOME")
            .map_err(|_| "HOME environment variable not set".to_string())?
            .into();
        Ok(Self { home_dir })
    }

    /// Create RemoteCallbacks configured with credential handlers
    pub fn create_callbacks<'a>(&self, repo: &Repository) -> RemoteCallbacks<'a> {
        // Capture owned Config so the closure does not borrow `repo`
        let config = repo.config().ok();
        let home_dir = self.home_dir.clone();

        let mut callbacks = RemoteCallbacks::new();

        callbacks.credentials(move |_url, username_from_url, _allowed_types| {
            // SSH Key authentication
            if _allowed_types.contains(CredentialType::SSH_KEY) {
                let username = username_from_url.unwrap_or("git");

                // Try id_ed25519 first (more modern and secure)
                let ssh_key_ed = home_dir.join(".ssh/id_ed25519");
                if ssh_key_ed.exists() {
                    eprintln!("🔑 Trying SSH key: {}", ssh_key_ed.display());
                    match Cred::ssh_key(username, None, &ssh_key_ed, None) {
                        Ok(c) => {
                            eprintln!("✓ Using SSH key: {}", ssh_key_ed.display());
                            return Ok(c);
                        }
                        Err(e) => eprintln!("✗ Failed to load {}: {}", ssh_key_ed.display(), e),
                    }
                }

                // Fallback to id_rsa
                let ssh_key_rsa = home_dir.join(".ssh/id_rsa");
                if ssh_key_rsa.exists() {
                    eprintln!("🔑 Trying SSH key: {}", ssh_key_rsa.display());
                    match Cred::ssh_key(username, None, &ssh_key_rsa, None) {
                        Ok(c) => {
                            eprintln!("✓ Using SSH key: {}", ssh_key_rsa.display());
                            return Ok(c);
                        }
                        Err(e) => eprintln!("✗ Failed to load {}: {}", ssh_key_rsa.display(), e),
                    }
                }

                // Try SSH agent as last resort
                eprintln!("🔑 Trying SSH agent");
                match Cred::ssh_key_from_agent(username) {
                    Ok(c) => {
                        eprintln!("✓ Using SSH agent");
                        return Ok(c);
                    }
                    Err(e) => eprintln!("✗ SSH agent failed: {}", e),
                }
            }

            // Username/Password authentication
            if _allowed_types.contains(CredentialType::USER_PASS_PLAINTEXT) {
                eprintln!("🔑 Attempting username/password authentication");
                if let Some(ref cfg) = config {
                    if let Ok(c) = Cred::credential_helper(cfg, _url, username_from_url) {
                        eprintln!("✓ Using credential helper");
                        return Ok(c);
                    }
                }
            }

            eprintln!("✗ No valid credentials found");
            Err(git2::Error::from_str("No valid credentials available"))
        });

        callbacks
    }
}

impl Default for CredentialManager {
    fn default() -> Self {
        Self::new().expect("Failed to initialize CredentialManager")
    }
}
