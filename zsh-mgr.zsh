#!/bin/bash

if [ "$ZSH_MGR_ZSH" != yes ]; then
    ZSH_MGR_ZSH=yes
else
    return 0
fi 

export REPO_URL="https://github.com"

# Time threshold
export TIME_THRESHOLD=604800        # 1 week in seconds
export MGR_TIME_THRESHOLD=604800    # 1 week in seconds

PLUGIN_LIST=()  # Empty array for plugins

source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/generic-auto-updater.zsh"

# Sources a plugin to load it on the shell
# $1: Plugin's author
# $2: Plugin name
_source_plugin() {
    local directory

    if [ -f "$ZSH_PLUGIN_DIR/$2/$2.plugin.zsh" ]; then
        directory="$ZSH_PLUGIN_DIR/$2/$2.plugin.zsh"

    elif [ -f "$ZSH_PLUGIN_DIR/$2/$2.zsh" ]; then
        directory="$ZSH_PLUGIN_DIR/$2/$2.zsh"

    # This one is for powerlevel10k
    elif [ -f "$ZSH_PLUGIN_DIR/$2/$2.zsh-theme" ]; then
        directory="$ZSH_PLUGIN_DIR/$2/$2.zsh-theme"

    else
        echo -e "${RED}Error adding plugin $2:${NO_COLOR} Script not found"
        return 1
    fi

    if ! source "$directory"; then
        echo -e "${RED}Error adding plugin $2:${NO_COLOR} Unknown error"
        return 1
    fi


    # Adds the sourced plugin to the plugin list
    PLUGIN_LIST=("${PLUGIN_LIST[@]}" "$2")

    return 0
}

# Adds a plugin and updates it every week. Then it sources it.
# $1: user/plugin (that is the expected format)
# $2: extra git params (like --depth)
add_plugin() {
    local -r AUTHOR=$(echo "$1" | cut -d "/" -f 1)
    local -r PLUGIN_NAME=$(echo "$1" | cut -d "/" -f 2)
    # local error=0 # By default, there are no errors

    # Se comprueba si existe el directorio, indicando que se ha descargado
    if [ ! -d "$ZSH_PLUGIN_DIR/$PLUGIN_NAME" ]; then
        local -r raw_msg="Installing $PLUGIN_NAME"
        print_message "Installing $GREEN$PLUGIN_NAME$NO_COLOR" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#raw_msg}"

        # Si se pide algun comando extra a git, se pone como entrada a la funcion
        if [ "$#" -eq 2 ]; then
            git clone "$2" "$REPO_URL/$1" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"
        else
            git clone "$REPO_URL/$1" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"
        fi

        # Solo en caso de que haya tenido exito el clonado
        if [ "$?" -eq 0 ]; then
            # Se le añade una marca de tiempo para que cuando pase un tiempo determinado haga pull al plugin indicado
            date +%s >"$ZSH_PLUGIN_DIR/.$PLUGIN_NAME"
        else
            # error=1
            echo -e "${RED}Error installing $PLUGIN_NAME${NO_COLOR}"

            return 1
        fi
    fi

    _auto_update_plugin "$PLUGIN_NAME"
    _source_plugin "$AUTHOR" "$PLUGIN_NAME"
}


# Updates a plugin given as input.
# $1: The name of the plugin. It must be set before calling the function.
# pre: The plugin must be installed or else the function will error out.
_update_plugin(){
    local -r PLUGIN_NAME="$1"
    _generic_updater "$PLUGIN_NAME" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"   
}


# Auto-updater for plugins.
# 
# $1: The name of the plugin.
_auto_update_plugin(){
    local -r PLUGIN_NAME="$1"
    local -r REPO_LOC="$ZSH_PLUGIN_DIR/$PLUGIN_NAME"

    _generic_auto_updater "$PLUGIN_NAME" "$REPO_LOC" "$TIME_THRESHOLD"
}

#\\033\[0;?[0-9]*m to find ansi escape codes

# Updates all loaded plugins
update_plugins(){
    if [ "${#PLUGIN_LIST[@]}" -ne "0" ]; then
        for i in "${PLUGIN_LIST[@]}"
        do
            _update_plugin "$i"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}


# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"

check_plugins_update_date() {
    local NEXT_DATE
    if [ "${#PLUGIN_LIST[@]}" -ne "0" ]; then
        for i in "${PLUGIN_LIST[@]}"
        do
            # It needs to be writable since it updates in every iteration
            NEXT_DATE=$(cat "$ZSH_PLUGIN_DIR"/."$i")
            echo -e "${BRIGHT_CYAN}$i:${NO_COLOR} $(date -d @$((NEXT_DATE+TIME_THRESHOLD)) "+%d-%m-%Y %H:%M:%S")"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}

# Manually updates the plugin manager
update_mgr(){
    _generic_updater "zsh-mgr" "$ZSH_CONFIG_DIR/zsh-mgr"
}

# Auto-updater for the plugin manager
_auto_update_mgr(){
    _generic_auto_updater "zsh-mgr" "$ZSH_CONFIG_DIR/zsh-mgr" "$MGR_TIME_THRESHOLD"
}

# Calls the auto-updater for the plugin manager
_auto_update_mgr