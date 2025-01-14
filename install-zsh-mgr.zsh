#!/bin/zsh

# Default plugin manager locations and time intervals
ZSH_PLUGIN_DIR="$HOME/.zsh-plugins"
readonly ZSH_CONFIG_DIR="$HOME/.config/zsh"
time_plugin_sec="604800"
time_mgr_sec="604800"

# Source neccesary functions and exports
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr-common-functions.zsh"

_interactive_install() {
    local plugin_dir

    # Then, we add new lines to the config file to install the package manager
    echo -n "${YELLOW}Plugins FULL directory (Can use \$HOME and ~) (empty for default directory):${NO_COLOR} " 
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

# $1: Time formatted using s,m,h,d,w as seconds, minutes, hours, days and weeks.
# return: The time in seconds, an error code the format is wrong.
_parse_time(){
    local -r TIME="$1"

    # Check if the format is incorrect
    ! echo "$TIME" | grep -iE "^[1-9]+[0-9]*[smhdw]{1}$" > /dev/null && return 1

    # ${var:offset:length} for substring expansion
    local -r TIME_MOD="${TIME: -1}"
    local -r TIME_NUM="${TIME: 0 : -1}"

    local result
    echo "$TIME_MOD" | grep -iE "[smhdw]" > /dev/null && result="$TIME_NUM"
    echo "$TIME_MOD" | grep -iE "[mhdw]"  > /dev/null && result=$((result*60))
    echo "$TIME_MOD" | grep -iE "[hdw]"   > /dev/null && result=$((result*60))
    echo "$TIME_MOD" | grep -iE "[dw]"    > /dev/null && result=$((result*24))
    echo "$TIME_MOD" | grep -iE "[w]"     > /dev/null && result=$((result*7))

    echo "$result"
}

_ask_for_update_interval(){
    echo "${BRIGHT_CYAN}┌───────────────────────┐${NO_COLOR}"
    echo "${BRIGHT_CYAN}│ Time format examples  │${NO_COLOR}"
    echo "${BRIGHT_CYAN}├──────────┬────────────┤${NO_COLOR}"
    echo "${BRIGHT_CYAN}│ 1 second │     1s     │${NO_COLOR}"
    echo "${BRIGHT_CYAN}│ 1 minute │     1m     │${NO_COLOR}"
    echo "${BRIGHT_CYAN}│  1 hour  │     1h     │${NO_COLOR}"
    echo "${BRIGHT_CYAN}│  1 week  │     1w     │${NO_COLOR}"
    echo -e "${BRIGHT_CYAN}└───────────────────────┘${NO_COLOR}\n"    

    local error="1"
    while [ "$error" -ne "0" ]
    do
        echo -n "${YELLOW}Please input time interval to update plugins:${NO_COLOR} "
        read -r time_plugin
        time_plugin_sec=$(_parse_time "$time_plugin")
        error="$?"
    done

    error="1"
    while [ "$error" -ne "0" ]
    do
        echo -n "${YELLOW}Please input time interval to update the manager:${NO_COLOR} "
        read -r time_mgr
        time_mgr_sec=$(_parse_time "$time_mgr")
        error="$?"
    done
}

# $1: Plugin time interval
# $2: Manager time interval
_prepend_to_config() {
    local -r PLUGIN_DIR="export ZSH_PLUGIN_DIR=\"$ZSH_PLUGIN_DIR\""
    local -r CONFIG_DIR="export ZSH_CONFIG_DIR=\"\$HOME/.config/zsh\""
    local -r TIME1="export TIME_THRESHOLD=$1"
    local -r TIME2="export MGR_TIME_THRESHOLD=$2"
    local -r SOURCE_FILE="source \$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr.zsh"

    _prepend_to_file "$HOME/.zshrc" "$PLUGIN_DIR\n$CONFIG_DIR\n$TIME1\n$TIME2\n\n$SOURCE_FILE\n\n"
}

# Detects if zsh-mgr has been installed.
# return: 0 if it is installed (no errors), 1 otherwise.
_is_mgr_installed(){
    local -r WORDS=("export ZSH_PLUGIN_DIR=" "export ZSH_CONFIG_DIR" "export TIME_THRESHOLD=" "export MGR_TIME_THRESHOLD=" "source \$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr.zsh")

    local result=1

    # Iterates over all the lines this scripts creates on .zshrc
    local i
    for i in "${WORDS[@]}"
    do
        if grep -E "^$i" "$HOME/.zshrc" > /dev/null;
        then
            result=0
            break
        fi
    done
    unset i

    return "$result"
}

main(){
    # Check check wether .zshrc exists
    if [ ! -f "$HOME/.zshrc" ]; then
        echo "${BRIGHT_CYAN}Creating .zshrc file...${NO_COLOR}"
        touch "$HOME/.zshrc"
    fi

    if _is_mgr_installed;
    then
        echo "${RED}zsh-mgr has been installed or partially installed, exiting...${NO_COLOR}"
        exit 1
    fi

    # Check if the package manager is going to be installed silently with default options
    if [ "$#" -eq 0 ]; then
        echo "Installing interactively..."
        
        # Interactive install
        _interactive_install
        _ask_for_update_interval

    # Quiet installation
    elif [ "$1" = "-q" ]; then
        echo "Installing quietly..."
    else
        echo "${RED}Unrecognized parameter${NO_COLOR}"
        exit 1
    fi

    # Create the directories and prepend the lines to the config file
    _create_directories
    _prepend_to_config "$time_plugin_sec" "$time_mgr_sec"

    echo -e "\n${GREEN}zsh-mgr installed successfully!${NO_COLOR}\nYou can now add plugins to your .zshrc file.\n"
}

main "$@"