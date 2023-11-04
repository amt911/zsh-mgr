#!/bin/zsh

# DEBUG FOR PAK USER: sudo cp -r /home/andres/zsh-mgr . && sudo chown -R pak:pak zsh-mgr; touch .zshrc && chmod +x .zshrc && sudo cp -r ~andres/.ssh . && sudo chown -R pak:pak .ssh
# Colors
RED='\033[0;31m'
NO_COLOR='\033[0m'
GREEN='\033[0;32m'
BRIGHT_CYAN='\033[0;96m'

# Default plugin manager locations
ZSH_PLUGIN_DIR="$HOME/.zsh-plugins"
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# Expands possibles aliases to home
# $1: Path
# return: Returns an expanded string

_expand_home() {
    echo "${1//(\~|\$HOME)/"$HOME"}"    
}

_interactive_install() {
    local plugin_dir

    # Then, we add new lines to the config file to install the package manager
    echo -n "Plugins FULL directory (Can use \$HOME and ~) (empty for default directory): " 
    read -r plugin_dir

    # Expands home variables
    plugin_dir=$(_expand_home "$plugin_dir")

    if [ "$plugin_dir" != "" ]; then
        ZSH_PLUGIN_DIR="$plugin_dir"
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
    local plugin_dir="export ZSH_PLUGIN_DIR=\"$ZSH_PLUGIN_DIR\""
    local config_dir="export ZSH_CONFIG_DIR=\"\$HOME/.config/zsh\""
    local source_file="source \$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr.zsh"

    # _prepend_to_file .zshrc "hola que tal\n"
    _prepend_to_file "$HOME/.zshrc" "$plugin_dir\n$config_dir\n\n$source_file\n\n"
}

# Creates a symbolic link to the package manager file
_create_symlink() {

    # bash version
    # local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    # zsh version
    local script_dir="$( cd -- "$( dirname -- "${(%):-%x}" )" &> /dev/null && pwd )"

    ln -sf "$script_dir/zsh-mgr.zsh" "$ZSH_CONFIG_DIR/zsh-mgr.zsh" 
}



# _success_message() {

# }

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

# elif [ "$1" = "-zshpc" ]; then
#     echo "Special flag for personal config..."
#     exit
else
    echo "Unrecognized parameter"
    exit 1
fi


# Create the directories and prepend the lines to the config file
_create_directories
_prepend_to_config
# _create_symlink