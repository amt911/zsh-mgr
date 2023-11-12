# zsh-mgr

A simple plugin manager for zsh. Features:

- Auto-updates all plugins.

## Installation

### Automatic

First, clone the repository and execute the installation script using the following command:

```console
git clone "git@github.com:amt911/zsh-mgr.git" ~/.config/zsh/zsh-mgr && cp ~/.config/zsh/zsh-mgr/install-zsh-mgr.zsh ~ && ~/install-zsh-mgr.zsh && rm ~/install-zsh-mgr.zsh
```

If the installation failed for some reason, execute the script again using:

```console
~/install-zsh-mgr.zsh && rm ~/install-zsh-mgr.zsh
```

**Note:** You can add your own scripts to the following location: ```~/.config/zsh/``` and source them in your zsh config file.

### Manual

You can manually clone the repo to your desired location and add the following lines to your ```.zshrc``` file:

```console
export ZSH_CONFIG_DIR="parent/folder/from/repo"
export ZSH_PLUGIN_DIR="your/desired/location"

source parent/folder/from/repo/zsh-mgr/zsh-mgr.zsh
```

**IMPORTANT:** If you want to use the tilde ("~"), DON'T put it between double quotes, otherwise the scripts will fail.

## Configuration

### Adding plugins

You can add your favourite plugins adding this line to your ```.zshrc``` file:

```console
add_plugin "author/plugin-name"
```

And you can add extra flags to the plugin in this way:

```console
add_plugin "author/plugin-name" "--flag1 --flag2"
```

### Plugins updater

Every week, when a new terminal is opened, the plugin manager will update all installed plugins.

You can force the update process by issuing the following command: ```update_plugins```

Additionally, you can check the next update date by using the command: ```check_plugins_update_date```

And to see zsh-mgr's update date, type: ```check_mgr_update_date```

Finally, to see both update dates at the same time, use: ```ck_mgr_plugin```

## TODO

The following features are planned to be implemented in the following commits:

- <del>Updater for the plugin manager itself.</del>
- <del>Auto-update for the plugin manager.</del>
- Delete unused plugins.
- Change update settings:
  - Disable auto-update.
  - Change updates frequency.
