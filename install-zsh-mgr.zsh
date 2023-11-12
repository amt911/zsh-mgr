#!/bin/zsh

# DEBUG FOR PAK USER: mkdir -p .config/zsh && sudo cp -r /home/andres/zsh-mgr .config/zsh && sudo chown -R pak:pak .config/zsh/zsh-mgr; touch .zshrc && chmod +x .zshrc && sudo cp -r ~andres/.ssh . && sudo chown -R pak:pak .ssh

# Default plugin manager locations
ZSH_PLUGIN_DIR="$HOME/.zsh-plugins"
readonly ZSH_CONFIG_DIR="$HOME/.config/zsh"

# Source neccesary functions and exports
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr-common-functions.zsh"

_interactive_install() {
    local plugin_dir

    # Then, we add new lines to the config file to install the package manager
    echo -n "Plugins FULL directory (Can use \$HOME and ~) (empty for default directory): " 
    read -r plugin_dir

    if [ "$plugin_dir" != "" ]; then
        ZSH_PLUGIN_DIR="$(_sanitize_location "$plugin_dir")"
    fi
}

_create_directories() {
    # Create the directory where the package manager file resides
    [ ! -d "$ZSH_CONFIG_DIR" ] && mkdir -p "$ZSH_CONFIG_DIR"

    # Create the plugin directory if it does not exist
    [ ! -d "$ZSH_PLUGIN_DIR" ] && mkdir -p "$ZSH_PLUGIN_DIR"
}


# Prepends the message passed as input to the file also passed as input
# $1: Path to file to be modified
# $2: Message to prepend
# note: This function is safe to use on empty files
_prepend_to_file() {
    { printf "%b" "$2"; cat "$1"; } > "$1".new
    mv "$1"{.new,}
}

_prepend_to_config() {
    local -r PLUGIN_DIR="export ZSH_PLUGIN_DIR=\"$ZSH_PLUGIN_DIR\""
    local -r CONFIG_DIR="export ZSH_CONFIG_DIR=\"\$HOME/.config/zsh\""
    local -r SOURCE_FILE="source \$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr.zsh"

    _prepend_to_file "$HOME/.zshrc" "$PLUGIN_DIR\n$CONFIG_DIR\n\n$SOURCE_FILE\n\n"
}

# Creates a symbolic link to the package manager file
_create_symlink() {

    # bash version
    # local SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    # zsh version
    local -r SCRIPT_DIR="$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )"

    ln -sf "$SCRIPT_DIR/zsh-mgr.zsh" "$ZSH_CONFIG_DIR/zsh-mgr.zsh" 
}


# Check check wether .zshrc exists
if [ ! -f "$HOME/.zshrc" ]; then
    echo -e "$RED.zshrc file does not exist!$NO_COLOR \nPlease, create one."
    exit 1
fi


# Check if the package manager is going to be installed silently with default options
if [ "$#" -eq 0 ]; then
    echo "Installing interactively..."
    
    # Interactive install
    _interactive_install

# Quiet installation
elif [ "$1" = "-q" ]; then
    echo "Installing quietly..."
else
    echo "Unrecognized parameter"
    exit 1
fi


# Create the directories and prepend the lines to the config file
_create_directories
_prepend_to_config
# _create_symlink