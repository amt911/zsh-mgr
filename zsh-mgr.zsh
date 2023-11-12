#!/bin/zsh

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
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-functions.zsh"

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

# $1: 
_display_color_legend(){
    local -r RAW_MSG="RED#Less than 25% left to update.\nYELLOW#Less than 75%, but more than 25% left to update.\nGREEN#Less than 100%, but more than 75% left to update."
    local -r COLORED_MSG="${RED}RED${NO_COLOR}#Less than 25% left to update.\n${YELLOW}YELLOW${NO_COLOR}#Less than 75%, but more than 25% left to update.\n${GREEN}GREEN${NO_COLOR}#Less than 100%, but more than 75% left to update."

    _create_table "$RAW_MSG" "#" "" "$COLORED_MSG"
}

# $1 (Optional yes/no): Output legend? Default: yes
check_plugins_update_date() {
    echo "${1-foo}"
    if [ "${#PLUGIN_LIST[@]}" -ne "0" ]; then  
        local RAW_TABLE=("${(@f)$(_plugin_update_to_table no)}")
        local COLORED_TABLE=("${(@f)$(_plugin_update_to_table yes)}")
        
        RAW_TABLE=("Plugin name#Next update" "${RAW_TABLE[@]}")
        COLORED_TABLE=("Plugin name#Next update" "${COLORED_TABLE[@]}")

        RAW_TABLE=$(printf "%s\n" "${RAW_TABLE[@]}")
        COLORED_TABLE=$(printf "%s\n" "${COLORED_TABLE[@]}")

        _create_table "$RAW_TABLE" "#" "${CYAN}" "$COLORED_TABLE"

        [ "${1:-yes}" = "yes" ] && _display_color_legend 
    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}

# Displays a colored table with the next update date for the plugin manager.
# $1 (Optional yes/no): Display legend? Default: yes
check_mgr_update_date(){
    local raw_msg="zsh-mgr#$(date -d @"$(( $(cat "$ZSH_PLUGIN_DIR"/.zsh-mgr) + MGR_TIME_THRESHOLD ))" "+%d-%m-%Y %H:%M:%S" )"
    local colored_msg=$(_color_row_on_date "zsh-mgr#$(cat "$ZSH_PLUGIN_DIR"/.zsh-mgr)" "#" "$MGR_TIME_THRESHOLD")

    _create_table "Manager#Next update\n$raw_msg" "#" "${GREEN}" "Manager#Next update\n$colored_msg"

    [ "${1:-yes}" = "yes" ] && _display_color_legend 

    return 0
}

# Displays a colored table with the next update date for the plugins and the plugin manager itself.
# $1 (Optional yes/no): Display legend? Default: yes
ck_mgr_plugin(){
    check_mgr_update_date no
    check_plugins_update_date no

    [ "${1:-yes}" = "yes" ] && _display_color_legend
}

# Makes a table of every plugin and its update date.
# $1 (yes/no): Color the output?
_plugin_update_to_table(){
    if [ "${#PLUGIN_LIST[@]}" -ne "0" ]; then
        # Unique to zsh
        local next_date

        for i in "${PLUGIN_LIST[@]}"
        do
            if [ "$1" = yes ];
            then
                _color_row_on_date "$i#$(cat "$ZSH_PLUGIN_DIR"/."$i")" "#" "$TIME_THRESHOLD"
            else
                next_date=$(( $(cat "$ZSH_PLUGIN_DIR"/."$i") + TIME_THRESHOLD ))
                next_date=$(date -d @"$next_date" "+%d-%m-%Y %H:%M:%S")
                
                echo "$i#$next_date"
            fi
        done
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