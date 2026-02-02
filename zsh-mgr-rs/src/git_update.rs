use clap::Parser;
use log::info;
use std::path::PathBuf;
use git2::{AutotagOption, Error, FetchOptions, Remote, Repository};
use anyhow::Result;
use std::sync::Arc;

use crate::credentials_manager::CredentialManager;

// Taken from https://github.com/rust-lang/git2-rs/blob/master/examples/pull.rs

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Route to the repository to update
    #[arg(short, long, value_name = "PATH")]
    repo: PathBuf
}


pub struct RepoUpdater {
    // repo_path: PathBuf,
    credentials: Arc<CredentialManager>,
    repo: Repository,
}

impl RepoUpdater {
    pub fn new(repo_path: PathBuf, credentials: Arc<CredentialManager>) -> Result<Self, git2::Error> {
        let repo = Repository::open(&repo_path)?;
        Ok(Self { credentials, repo })
    }

    fn do_fetch<'repo>(
        &'repo self,
        refs: &[&str],
        remote: &mut Remote<'repo>,
    ) -> Result<git2::AnnotatedCommit<'repo>, git2::Error> {
        // Print out our transfer progress.
        // cb.transfer_progress(|stats| {
        //     if stats.received_objects() == stats.total_objects() {
        //         print!(
        //             "Resolving deltas {}/{}\r",
        //             stats.indexed_deltas(),
        //             stats.total_deltas()
        //         );
        //     } else if stats.total_objects() > 0 {
        //         print!(
        //             "Received {}/{} objects ({}) in {} bytes\r",
        //             stats.received_objects(),
        //             stats.total_objects(),
        //             stats.indexed_objects(),
        //             stats.received_bytes()
        //         );
        //     }
        //     io::stdout().flush().unwrap();
        //     true
        // });

        let callbacks = self.credentials.create_callbacks(&self.repo);

        let mut fo = FetchOptions::new();
        fo.remote_callbacks(callbacks);
        // Always fetch all tags.
        // Perform a download and also update tips
        fo.download_tags(AutotagOption::All);
        println!("Fetching {} for repo", remote.name().unwrap());
        remote.fetch(refs, Some(&mut fo), None)?;

        // If there are local objects (we got a thin pack), then tell the user
        // how many objects we saved from having to cross the network.
        let stats = remote.stats();
        if stats.local_objects() > 0 {
            println!(
                "\rReceived {}/{} objects in {} bytes (used {} local \
                objects)",
                stats.indexed_objects(),
                stats.total_objects(),
                stats.received_bytes(),
                stats.local_objects()
            );
        } else {
            println!(
                "\rReceived {}/{} objects in {} bytes",
                stats.indexed_objects(),
                stats.total_objects(),
                stats.received_bytes()
            );
        }

        let fetch_head = self.repo.find_reference("FETCH_HEAD")?;
        Ok(self.repo.reference_to_annotated_commit(&fetch_head)?)
    }

    fn fast_forward(
        &self,
        lb: &mut git2::Reference,
        rc: &git2::AnnotatedCommit,
    ) -> Result<(), git2::Error> {
        let name = match lb.name() {
            Some(s) => s.to_string(),
            _none => String::from_utf8_lossy(lb.name_bytes()).to_string(),
        };
        let msg = format!("Fast-Forward: Setting {} to id: {}", name, rc.id());
        println!("{}", msg);
        lb.set_target(rc.id(), &msg)?;
        self.repo.set_head(&name)?;
        self.repo.checkout_head(Some(
            git2::build::CheckoutBuilder::default()
                // For some reason the force is required to make the working directory actually get updated
                // I suspect we should be adding some logic to handle dirty working directory states
                // but this is just an example so maybe not.
                .force(),
        ))?;
        Ok(())
    }

    fn normal_merge(
        &self,
        local: &git2::AnnotatedCommit,
        remote: &git2::AnnotatedCommit,
    ) -> Result<(), git2::Error> {
        let local_tree = self.repo.find_commit(local.id())?.tree()?;
        let remote_tree = self.repo.find_commit(remote.id())?.tree()?;
        let ancestor = self.repo
            .find_commit(self.repo.merge_base(local.id(), remote.id())?)?
            .tree()?;
        let mut idx = self.repo.merge_trees(&ancestor, &local_tree, &remote_tree, None)?;

        if idx.has_conflicts() {
            println!("Merge conflicts detected...");
            self.repo.checkout_index(Some(&mut idx), None)?;
            return Ok(());
        }
        let result_tree = self.repo.find_tree(idx.write_tree_to(&self.repo)?)?;
        // now create the merge commit
        let msg = format!("Merge: {} into {}", remote.id(), local.id());
        let sig = self.repo.signature()?;
        let local_commit = self.repo.find_commit(local.id())?;
        let remote_commit = self.repo.find_commit(remote.id())?;
        // Do our merge commit and set current branch head to that commit.
        let _merge_commit = self.repo.commit(
            Some("HEAD"),
            &sig,
            &sig,
            &msg,
            &result_tree,
            &[&local_commit, &remote_commit],
        )?;
        // Set working tree to match head.
        self.repo.checkout_head(None)?;
        Ok(())
    }

    fn do_merge<'repo>(
        &self,
        remote_branch: &str,
        fetch_commit: git2::AnnotatedCommit<'repo>,
    ) -> Result<(), git2::Error> {
        // 1. do a merge analysis
        let analysis = self.repo.merge_analysis(&[&fetch_commit])?;

        // 2. Do the appropriate merge
        if analysis.0.is_fast_forward() {
            println!("Doing a fast forward");
            // do a fast forward
            let refname = format!("refs/heads/{}", remote_branch);
            match self.repo.find_reference(&refname) {
                Ok(mut r) => {
                    self.fast_forward(&mut r, &fetch_commit)?;
                }
                Err(_) => {
                    // The branch doesn't exist so just set the reference to the
                    // commit directly. Usually this is because you are pulling
                    // into an empty repository.
                    self.repo.reference(
                        &refname,
                        fetch_commit.id(),
                        true,
                        &format!("Setting {} to {}", remote_branch, fetch_commit.id()),
                    )?;
                    self.repo.set_head(&refname)?;
                    self.repo.checkout_head(Some(
                        git2::build::CheckoutBuilder::default()
                            .allow_conflicts(true)
                            .conflict_style_merge(true)
                            .force(),
                    ))?;
                }
            };
        } else if analysis.0.is_normal() {
            // For shallow repos, normal merge may fail because there's no merge base.
            // In that case, force-reset the branch to the fetched commit.
            if self.is_shallow() {
                println!("Shallow repository detected — force-resetting to fetched commit");
                let refname = format!("refs/heads/{}", remote_branch);
                match self.repo.find_reference(&refname) {
                    Ok(mut r) => {
                        let msg = format!("Shallow update: resetting {} to {}", refname, fetch_commit.id());
                        r.set_target(fetch_commit.id(), &msg)?;
                        self.repo.set_head(&refname)?;
                        self.repo.checkout_head(Some(
                            git2::build::CheckoutBuilder::default().force(),
                        ))?;
                    }
                    Err(e) => {
                        eprintln!("Failed to find reference {}: {}", refname, e);
                        return Err(e);
                    }
                }
            } else {
                // do a normal merge
                let head_commit = self.repo.reference_to_annotated_commit(&self.repo.head()?)?;
                self.normal_merge(&head_commit, &fetch_commit)?;
            }
        } else {
            println!("Nothing to do...");
        }
        Ok(())
    }

    /// Check if the repository is a shallow clone
    fn is_shallow(&self) -> bool {
        self.repo.is_shallow()
    }

    fn get_current_branch(&self) -> Result<String, Error> {
        let head = self.repo.head()?;
        let branch = head
            .shorthand()
            .ok_or_else(|| git2::Error::from_str("HEAD has no shorthand (detached)"))?
            .to_string();

        info!("Current branch shorthand: {}", branch);

        Ok(branch)
    }

    fn is_stash_needed(&self) -> Result<bool, Error> {
        let statuses = self.repo.statuses(None)?;
        let dirty = statuses.iter().any(|entry| {
            let s = entry.status();
            s.is_wt_modified()
                || s.is_wt_new()
                || s.is_wt_deleted()
                || s.is_wt_renamed()
                || s.is_wt_typechange()
                || s.is_index_modified()
                || s.is_index_deleted()
                || s.is_index_renamed()
                || s.is_index_new()
        });
        Ok(dirty)
    }

    fn stash_working_directory(&mut self) -> Result<Option<git2::Oid>, Error> {
        let sig = self.repo.signature()?;
        let msg = "autostash by git-update";
        match self.repo.stash_save(&sig, msg, Some(git2::StashFlags::INCLUDE_UNTRACKED)) {
            Ok(oid) => Ok(Some(oid)),
            Err(e) => {
                eprintln!("Failed to create stash: {} — continuing without stashing", e);
                Ok(None)
            }
        }
    }

    fn stash_pop(&mut self, stashed_oid: git2::Oid) -> Result<(), Error> {
        let mut found_index: Option<usize> = None;
        // Iterate stash list to find the oid -> get its index
        let _ = self.repo.stash_foreach(|i, _name, oid| {
            if oid == &stashed_oid {
                found_index = Some(i);
                return false; // stop iteration
            }
            true
        });

        if let Some(idx) = found_index {
            match self.repo.stash_pop(idx, None) {
                Ok(_) => {
                    eprintln!("Restored stashed changes (popped stash index {})", idx);
                    Ok(())
                },
                Err(e) => {
                    eprintln!("Failed to pop stash index {}: {}. You can restore manually with 'git stash list'", idx, e);
                    Err(e)
                },
            }
        } else {
            eprintln!("Could not find stash corresponding to oid {}. You can inspect with 'git stash list'", stashed_oid);
            Ok(())
        }
    }

    pub fn run(&mut self) -> Result<(), Error> {
        let current_branch = self.get_current_branch()?;

        info!("Current branch: {}", current_branch);

        let mut stashed_oid: Option<git2::Oid> = None;
        if self.is_stash_needed()? {
            eprintln!("Local changes detected — creating stash (include untracked)");
            stashed_oid = self.stash_working_directory()?;
        }

        let remote_name = "origin";
        let mut remote = self.repo.find_remote(remote_name)?;
        let fetch_commit = self.do_fetch(&[current_branch.as_str()], &mut remote)?;
        let result = self.do_merge(&current_branch, fetch_commit);

        // Ensure working tree matches HEAD (force) so it's clean after merge
        let _ = self.repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()));

        // Drop remote before performing mutable stash operations to avoid borrow conflicts
        drop(remote);

        // If we stashed, try to pop the stash now
        if let Some(oid) = stashed_oid {
            self.stash_pop(oid)?;
        }

        // Return merge result
        result
    }
}

fn main() -> Result<()> {
    env_logger::init();

    let args = Args::parse();

    // Check whether a repository path is provided
    anyhow::ensure!(args.repo.exists(), "No repository specified");

    let credentials = Arc::new(CredentialManager::default());
    let mut repo_updater = RepoUpdater::new(args.repo, credentials)?;
    repo_updater.run()?;
    Ok(())
}


