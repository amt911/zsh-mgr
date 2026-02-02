use anyhow::Result;
use chrono::{DateTime, Local, TimeZone};
use comfy_table::{presets::UTF8_FULL, Cell, Color, ContentArrangement, Table};
use serde::{Deserialize, Serialize};
use zsh_mgr_rs::config::{Config, PluginList};

#[derive(Debug, Serialize, Deserialize)]
struct UpdateInfo {
    name: String,
    last_update: u64,
    next_update: u64,
    time_until_update: i64,
    status: UpdateStatus,
}

#[derive(Debug, Serialize, Deserialize)]
enum UpdateStatus {
    Current,
    UpdateSoon,
    UpdateNeeded,
}

pub fn run(plugins: bool, manager: bool, json: bool) -> Result<()> {
    let config = Config::load()?;
    let plugin_list = PluginList::load(&config)?;
    
    let mut updates = Vec::new();
    
    // Check plugins
    if !manager {
        for plugin in plugin_list.list() {
            if let Ok(timestamp_str) = std::fs::read_to_string(config.timestamp_file(&plugin.name)) {
                if let Ok(last_update) = timestamp_str.trim().parse::<u64>() {
                    let next_update = last_update + config.time_threshold;
                    let now = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)?
                        .as_secs();
                    
                    let time_until = next_update as i64 - now as i64;
                    
                    let status = if time_until > 86400 {
                        UpdateStatus::Current
                    } else if time_until > 0 {
                        UpdateStatus::UpdateSoon
                    } else {
                        UpdateStatus::UpdateNeeded
                    };
                    
                    updates.push(UpdateInfo {
                        name: plugin.name.clone(),
                        last_update,
                        next_update,
                        time_until_update: time_until,
                        status,
                    });
                }
            }
        }
    }
    
    // Check manager
    if !plugins {
        let mgr_timestamp_file = config.manager_timestamp_file();
        if mgr_timestamp_file.exists() {
            if let Ok(timestamp_str) = std::fs::read_to_string(&mgr_timestamp_file) {
                if let Ok(last_update) = timestamp_str.trim().parse::<u64>() {
                    let next_update = last_update + config.mgr_time_threshold;
                    let now = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)?
                        .as_secs();
                    
                    let time_until = next_update as i64 - now as i64;
                    
                    let status = if time_until > 86400 {
                        UpdateStatus::Current
                    } else if time_until > 0 {
                        UpdateStatus::UpdateSoon
                    } else {
                        UpdateStatus::UpdateNeeded
                    };
                    
                    updates.push(UpdateInfo {
                        name: "zsh-mgr".to_string(),
                        last_update,
                        next_update,
                        time_until_update: time_until,
                        status,
                    });
                }
            }
        }
    }
    
    // Output
    if json {
        println!("{}", serde_json::to_string_pretty(&updates)?);
    } else {
        print_table(&updates);
    }
    
    Ok(())
}

fn print_table(updates: &[UpdateInfo]) {
    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic)
        .set_header(vec!["Name", "Last Update", "Next Update", "Status"]);
    
    for update in updates {
        let last = format_timestamp(update.last_update);
        let next = format_timestamp(update.next_update);
        
        let (status_text, color) = match update.status {
            UpdateStatus::Current => ("✓ Up to date".to_string(), Color::Green),
            UpdateStatus::UpdateSoon => {
                let hours = update.time_until_update / 3600;
                (
                    format!("⏰ Update in {}h", hours),
                    Color::Yellow,
                )
            }
            UpdateStatus::UpdateNeeded => ("⚠ Update needed".to_string(), Color::Red),
        };
        
        table.add_row(vec![
            Cell::new(&update.name),
            Cell::new(last),
            Cell::new(next),
            Cell::new(&status_text).fg(color),
        ]);
    }
    
    println!("{}", table);
}

fn format_timestamp(timestamp: u64) -> String {
    let datetime: DateTime<Local> = Local.timestamp_opt(timestamp as i64, 0).unwrap();
    datetime.format("%Y-%m-%d %H:%M:%S").to_string()
}
