#!/bin/zsh

if [ "$ZSH_MGR_ZSH" != yes ]; then
    ZSH_MGR_ZSH=yes
else
    return 0
fi 

export REPO_URL="https://github.com/"
export PRIVATE_REPO_URL="git@github.com:"

PLUGIN_LIST=()  # Empty array for plugins

source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/generic-auto-updater.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr-common-functions.zsh"

# Adds a plugin and updates periodically.
# $1: user/plugin. If it is a private repo, input the whole URL
# $2 (optional): extra git params (like --depth)
add_plugin() {
    local -r PARAMS="${2:-}"
    local -r URL="$REPO_URL"

    _generic_add_plugin "$1" "$URL" "$PARAMS"
}

# Adds a plugin from a private repo and updates it periodically.
# $1: user/plugin. If it is a private repo, input the whole URL
# $2 (optional): extra git params (like --depth)
add_plugin_private(){
    local -r PARAMS="${2:-}"
    local -r URL="$PRIVATE_REPO_URL"

    _generic_add_plugin "$1" "$URL" "$PARAMS"
}


# Updates a plugin given as input.
# $1: The name of the plugin. It must be set before calling the function.
# pre: The plugin must be installed or else the function will error out.
_update_plugin(){
    local -r PLUGIN_NAME="$1"
    _generic_updater "$PLUGIN_NAME" "$ZSH_PLUGIN_DIR/$PLUGIN_NAME"   
}

#\\033\[0;?[0-9]*m to find ansi escape codes

# Updates all loaded plugins
update_plugins(){
    if [ "${#PLUGIN_LIST[@]}" -ne "0" ]; then
        local i
        for i in "${PLUGIN_LIST[@]}"
        do
            _update_plugin "$i"
        done    
        unset i

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}


# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"

# $1 (Optional yes/no): Output legend? Default: yes
check_plugins_update_date() {
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
    # local raw_msg="zsh-mgr#$(date -d @"$(( $(cat "$ZSH_PLUGIN_DIR"/.zsh-mgr) + MGR_TIME_THRESHOLD ))" "+%d-%m-%Y %H:%M:%S" )"
    # local colored_msg=$(_color_row_on_date "zsh-mgr#$(cat "$ZSH_PLUGIN_DIR"/.zsh-mgr)" "#" "$MGR_TIME_THRESHOLD")

    # _create_table "Manager#Next update\n$raw_msg" "#" "${GREEN}" "Manager#Next update\n$colored_msg"

    # [ "${1:-yes}" = "yes" ] && _display_color_legend 

    # return 0

    _check_comp_update_date "zsh-mgr" "$ZSH_CONFIG_DIR/zsh-mgr" "$MGR_TIME_THRESHOLD" "Manager#Next update" "${GREEN}" "${1:-yes}"
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
        local i

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
        unset i
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

# Recreates plugin directory if it does not exist anymore
_check_plugin_dir_exists(){
    [ ! -d "$ZSH_PLUGIN_DIR" ] && mkdir "$ZSH_PLUGIN_DIR"
}

# Checks if the plugin directory exists
_check_plugin_dir_exists

# Calls the auto-updater for the plugin manager
_auto_update_mgr