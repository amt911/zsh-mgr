#!/bin/bash

# Colors
# readonly RED='\033[0;31m'
# readonly NO_COLOR='\033[0m'
# readonly GREEN='\033[0;32m'
# readonly BRIGHT_CYAN='\033[0;96m'


# Prints a message given a max length. It fills the remaining space with "#"
# $1: Message to be printed
# $2: Max length of the message (including the message itself)
# $3: Character to fill the remaining space. It can be colored
# $4 (optional): Message length. Useful when it has ANSI escape codes, since it detects them as characters.
print_message() {
    local MSG_LENGTH=${#1}
    echo "tengo $# parametros"

    [ $# -eq 4 ] && MSG_LENGTH="$4"

    local -r MAX_LENGTH="$2"
    local -r HASHTAG_NRO=$(((MAX_LENGTH - MSG_LENGTH - 2) / 2))
    
    printf "\n"
    printf "%0.s$3" $(seq 1 "$2")
    printf "\n"
    printf "%0.s$3" $(seq 1 "$HASHTAG_NRO")

    if [ $((MSG_LENGTH % 2)) -ne 0 ]; then
        printf " %b  " "$1"
    else
        printf " %b " "$1"
    fi

    printf "%0.s$3" $(seq 1 "$HASHTAG_NRO")
    printf "\n"
    printf "%0.s$3" $(seq 1 "$2")
    printf "\n"    
}

# Expands possible aliases to home. Also included in install script.
# $1: Path
# return: Returns an expanded string
_expand_home() {
    echo "${1//(\~|\$HOME)/"$HOME"}"
}

# Converts a path to file to an absolute one.
# 
# $1: The path to file to be converted.
# 
# return: Just the absolute path to the file, without the filename.
# 
# note: The given path does not have to exist in order to work.
_absolute_dirname(){
    local dirname_var
    local -r FILENAME=$(basename "$1")
    
    dirname_var=$(_expand_home "$1")            # Expands all home references
    
    dirname_var=${dirname_var/%\//}             # Strips the last "/"

    dirname_var=${dirname_var/%"\/$FILENAME"/}  # Removes the filename

    [ "$dirname_var" = "" ] && dirname_var="/"  # Adds back the root directory

    echo "$dirname_var"
}

_sanitize_location(){
    local dirname_var
    local -r FILENAME=$(basename "$1")
    
    dirname_var=$(_expand_home "$1")            # Expands all home references
    
    dirname_var=${dirname_var/%\//}             # Strips the last "/"

    [ "$dirname_var" = "" ] && dirname_var="/"  # Adds back the root directory

    echo "$dirname_var"   
}

# A generic git updater for a variety of projects
# 
# $1: Component name to be printed. It should be just the name
# of the plugin/component. Example: $1="zsh" -> Output: Updating zsh
# 
# $2: Location where the repo resides (including the repo folder)
# 
# $3 (Optional): Location where the timestamp file will be added.
# If this argument is not used, the file will be located at $SZH_PLUGIN_DIR
# 
# post: A timestamp file will be added to control auto-update shedule.
# 
# return: 0 if everything went ok, 1 in any other case
_generic_updater(){
    local -r RAW_MSG="Updating $1"     # Raw message to count character length
    local -r MSG="Updating ${GREEN}$1${NO_COLOR}"      # Message formatted with colors
    local -r LOCATION=$(_expand_home "$2")
    local TIMESTAMP_LOC
    
    # If there is no file location available, exit the function
    if [ -z "$ZSH_PLUGIN_DIR" ] && [ "$#" -lt "3" ]; then
        echo "${RED}Error, missing argument and no environment variable set."
        return 1
    fi

    # Setting the timestamp file location
    if [ "$#" -eq "3" ];then
        TIMESTAMP_LOC=$(_sanitize_location "$3")
        echo "Using arg $TIMESTAMP_LOC"
    else
        TIMESTAMP_LOC=$(_sanitize_location "$ZSH_PLUGIN_DIR")
        echo "Using env var $TIMESTAMP_LOC"
    fi

    print_message "$MSG" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#RAW_MSG}"

    # We pull the latest commit from the repository
    # git -C "$LOCATION" pull
    # local -r ERR_CODE="$?"

    # if [ $ERR_CODE -ne "0" ]; then
    #     local -r RAW_ERR_MSG="Error updating $1"
    #     local -r ERR_MSG="${RED}Error updating $1${NO_COLOR}"

    #     print_message "$ERR_MSG" "$((COLUMNS - 4))" "$RED#$NO_COLOR" "${#RAW_ERR_MSG}"

    #     return 1
    # fi

    # Gets the component name
    local -r COMP_NAME=$(basename "$LOCATION")

    # local -r DATE_FN="$COMP_LOC/.$COMP_NAME"
    local -r DATE_FN="$TIMESTAMP_LOC/.$COMP_NAME"
    echo "$DATE_FN"

    # Adds a timestamp
    # date +%s > "$DATE_FN"

    return 0
}

# # Updates the plugin manager to the latest main commit.
# update_mgr(){
#     local -r RAW_MSG="Updating zsh-mgr"     # Raw message to count character length
#     local -r MSG="Updating ${GREEN}zsh-mgr${NO_COLOR}"      # Message formatted with colors

#     print_message "$MSG" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#RAW_MSG}"

#     if ! git -C "$ZSH_CONFIG_DIR/zsh-mgr" pull; then
#         local -r RAW_ERR_MSG="Error updating zsh-mgr"
#         local -r ERR_MSG="${RED}Error updating zsh-mgr${NO_COLOR}"

#         print_message "$ERR_MSG" "$((COLUMNS - 4))" "$RED#$NO_COLOR" "${#RAW_ERR_MSG}"

#         return 1
#     fi

#     date +%s >"$ZSH_PLUGIN_DIR/.zsh-mgr"

#     return 0
# }

# # FIX THIS
# # Auto-updates the manager when a week has passed
# _auto_updater_mgr(){
#     if [ ! -f "$ZSH_PLUGIN_DIR/.zsh-mgr" ]; then
#         date +%s > "$ZSH_PLUGIN_DIR/.zsh-mgr"
#     fi
    
#     if [ $(($(date +%s) - $(cat "$ZSH_PLUGIN_DIR/.zsh-mgr"))) -ge $MGR_TIME_THRESHOLD ]; then
#         update_mgr
#     fi
# }