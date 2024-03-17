# zsh-mgr

A simple plugin manager for zsh. Features:

- Auto-updates all plugins.
- Auto-updates itself.
- Configurable time interval for both auto-updaters.

## Installation

### Automatic

First, clone the repository and execute the installation script using the following command:

```console
git clone "https://github.com/amt911/zsh-mgr.git" ~/.config/zsh/zsh-mgr && ~/.config/zsh/zsh-mgr/install-zsh-mgr.zsh
```

If the installation failed for some reason, execute the script again using:

```console
~/.config/zsh/zsh-mgr/install-zsh-mgr.zsh
```

**Note:** You can add your own scripts to the following location: ```~/.config/zsh/``` and source them in your zsh config file.

### Manual

You can manually clone the repo to your desired location and add the following lines to your ```.zshrc``` file:

```console
export ZSH_CONFIG_DIR="parent/folder/from/repo"
export ZSH_PLUGIN_DIR="your/desired/location"
export TIME_THRESHOLD="your desired time in seconds"
export MGR_TIME_THRESHOLD="your desired time in seconds"

source parent/folder/from/repo/zsh-mgr/zsh-mgr.zsh
```

**IMPORTANT:** If you want to use the tilde ("~"), DON'T put it between double quotes, otherwise the scripts will fail.

## Configuration

### Adding plugins

You can add your favourite plugins adding this line to your ```.zshrc``` file:

```console
add_plugin "author/plugin-name"
```

You can add extra flags to the plugin in this way:

```console
add_plugin "author/plugin-name" "--flag1 --flag2"
```

You can add a plugin from a private repository like this:

```console
add_plugin_private "author/plugin-name" "--flag1 --flag2"
```

### Checking ```zsh-mgr``` next update date

To check for the next zsh-mgr update date, use ```check_mgr_update_date```, or simply use ```ck_mgr_plugin``` to check both zsh-mgr and plugins update date.

### Checking plugins next update date

To check for the next update date of plugins, use ```check_plugins_update_date```, or (once again) use ```ck_mgr_plugin``` to check both.



## Plugins updater

Every week (or at your set time interval), when a new terminal is opened, the plugin manager will update all installed plugins.

You can force the update process by issuing the following command: ```update_plugins```

## TODO

The following features are planned to be implemented in the following commits:

- <del>Updater for the plugin manager itself.</del>
- <del>Auto-update for the plugin manager.</del>
- Delete unused plugins.
- Change update settings:
  - Disable auto-update.
  - Change updates frequency.

## Finding bugs

If you encounter a bug, please open an issue or create a pull request to solve it. I speak both spanish and english.