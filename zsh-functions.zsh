#!/bin/zsh

if [ "$ZSH_FUNCTIONS_ZSH" != yes ]; then
    ZSH_FUNCTIONS_ZSH=yes
else
    return 0
fi 

# Prints a message given a max length. It fills the remaining space with "#"
# $1: Message to be printed
# $2: Max length of the message (including the message itself)
# $3: Character to fill the remaining space. It can be colored
# $4 (optional): Message length. Useful when it has ANSI escape codes, since it detects them as characters.
print_message() {
    local MSG_LENGTH=${#1}

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
    
    dirname_var=$(_expand_home "$1")            # Expands all home references
    
    dirname_var=${dirname_var/%\//}             # Strips the last "/"

    [ "$dirname_var" = "" ] && dirname_var="/"  # Adds back the root directory

    echo "$dirname_var"   
}

