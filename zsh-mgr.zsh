#!/bin/zsh

export REPO_URL="https://github.com"

# Time threshold
export TIME_THRESHOLD=604800    # 1 week in seconds
export MGR_TIME_THRESHOLD=10    # 1 week in seconds
# TIME_THRESHOLD=10 # 20 hours in seconds

# Colors
readonly RED='\033[0;31m'
readonly NO_COLOR='\033[0m'
readonly GREEN='\033[0;32m'
readonly BRIGHT_CYAN='\033[0;96m'

#Sources a plugin to load it on the shell
#$1: Plugin's author
#$2: Plugin name
_source_plugin() {
    if [ -f "$ZSH_PLUGIN_DIR/$2/$2.plugin.zsh" ]; then
        source "$ZSH_PLUGIN_DIR/$2/$2.plugin.zsh"

    elif [ -f "$ZSH_PLUGIN_DIR/$2/$2.zsh" ]; then
        source "$ZSH_PLUGIN_DIR/$2/$2.zsh"

    #Este ultimo para powerlevel10k
    elif [ -f "$ZSH_PLUGIN_DIR/$2/$2.zsh-theme" ]; then
        source "$ZSH_PLUGIN_DIR/$2/$2.zsh-theme"

    else
        echo -e "${RED}Error adding plugin${NO_COLOR} $2"
    fi
}

# Adds a plugin and updates it every week. Then it sources it.
# $1: user/plugin (that is the expected format)
# $2: extra git params (like --depth)
add_plugin() {
    local -r AUTHOR=$(echo "$1" | cut -d "/" -f 1)
    local -r PLUGIN_NAME=$(echo "$1" | cut -d "/" -f 2)
    local error=0 # By default, there are no errors

    #Se comprueba si existe el directorio, indicando que se ha descargado
    if [ ! -d "$ZSH_PLUGIN_DIR/$PLUGIN_NAME" ]; then
        local -r raw_msg="Installing $PLUGIN_NAME"
        print_message "Installing $GREEN$PLUGIN_NAME$NO_COLOR" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#raw_msg}"

        # Si se pide algun comando extra a git, se pone como entrada a la funcion
        if [ "$#" -eq 2 ]; then
            git clone "$2" "$REPO_URL/$1" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"
        else
            git clone "$REPO_URL/$1" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"
        fi

        #Solo en caso de que haya tenido exito el clonado
        if [ "$?" -eq 0 ]; then
            #Se le añade una marca de tiempo para que cuando pase un tiempo determinado haga pull al plugin indicado
            date +%s >"$ZSH_PLUGIN_DIR/.$PLUGIN_NAME"
        else
            error=1
            echo -e "${RED}Error installing $PLUGIN_NAME${NO_COLOR}"
        fi

    # En caso de haberse pasado esa marca de tiempo, se le hace un pull al plugin para obtener los cambios
    elif [ $(($(date +%s) - $(cat "$ZSH_PLUGIN_DIR/.$PLUGIN_NAME"))) -ge $TIME_THRESHOLD ]; then
        _update_plugin "$PLUGIN_NAME"
    fi

    if [ $error -eq 0 ]; then
        _source_plugin "$AUTHOR" "$PLUGIN_NAME"
    fi
}

# Updates a plugin given as input.
# $1: The name of the plugin. It must be set before calling the function.
# pre: The plugin must be installed or else the function will error out.
_update_plugin() {
    local -r raw_msg="Updating $1"
    local error=0

    print_message "Updating $GREEN$1$NO_COLOR" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#raw_msg}"

    cd "$ZSH_PLUGIN_DIR/$1" || exit
    git pull

    # We save the output code of the previous command
    error="$?"

    cd "$HOME" || exit # JUST IN CASE

    if [ "$error" -eq 0 ]; then
        date +%s >"$ZSH_PLUGIN_DIR/.$1"    
    else
        echo -e "${RED}Error updating $1${NO_COLOR}"
    fi
}

#\\033\[0;?[0-9]*m to find ansi escape codes

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

# Lists all loaded plugins
list_plugins() {
    cd "$ZSH_PLUGIN_DIR" || exit
    local -r res=$(find . -maxdepth 1 -type f -name ".*" | sed 's/^\.\/\.//')
    cd "$HOME" || exit

    echo "$res"
}


# Updates all loaded plugins
update_plugins(){
    # First we check if the output is empty
    local -r PLUGINS_LIST=$(list_plugins)

    if [ "$PLUGINS_LIST" != "" ]; then
        # Then we insert them inside an array to iterate over them
        local -r LOADED_PLUGINS=("${(@f)$(list_plugins)}")

        for i in "${LOADED_PLUGINS[@]}"
        do
            _update_plugin "$i"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}


# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"

check_plugins_update_date() {
    local -r PLUGINS_LIST=$(list_plugins)

    if [ "$PLUGINS_LIST" != "" ]; then
        # Then we insert them inside an array to iterate over them
        local -r LOADED_PLUGINS=("${(@f)$(list_plugins)}")

        for i in "${LOADED_PLUGINS[@]}"
        do
            # It needs to be writable since it updates in every iteration
            local NEXT_DATE=$(cat "$ZSH_PLUGIN_DIR"/."$i")
            echo -e "${BRIGHT_CYAN}$i:${NO_COLOR} $(date -d @$((NEXT_DATE+TIME_THRESHOLD)) "+%d-%m-%Y %H:%M:%S")"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}

# Updates the plugin manager to the latest main commit.
update_mgr(){
    local -r RAW_MSG="Updating zsh-mgr"     # Raw message to count character length
    local -r MSG="Updating ${GREEN}zsh-mgr${NO_COLOR}"      # Message formatted with colors

    print_message "$MSG" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#RAW_MSG}"

    if ! git -C "$ZSH_CONFIG_DIR/zsh-mgr" pull; then
        local -r RAW_ERR_MSG="Error updating zsh-mgr"
        local -r ERR_MSG="${RED}Error updating zsh-mgr${NO_COLOR}"

        print_message "$ERR_MSG" "$((COLUMNS - 4))" "$RED#$NO_COLOR" "${#RAW_ERR_MSG}"

        return 1
    fi

    date +%s >"$ZSH_PLUGIN_DIR/.zsh-mgr"

    return 0
}

# Auto-updates the manager when a week has passed
_auto_updater(){
    if [ ! -f "$ZSH_PLUGIN_DIR/.zsh-mgr" ]; then
        date +%s > "$ZSH_PLUGIN_DIR/.zsh-mgr"
    fi
    
    if [ $(($(date +%s) - $(cat "$ZSH_PLUGIN_DIR/.zsh-mgr"))) -ge $MGR_TIME_THRESHOLD ]; then
        if update_mgr; then
            date +%s > "$ZSH_PLUGIN_DIR/.zsh-mgr"
        fi
    fi
}

_auto_updater