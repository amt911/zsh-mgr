#!/bin/zsh

if [ "$ZSH_MGR_ZSH" != yes ]; then
    ZSH_MGR_ZSH=yes
    echo "no sourceado"
else
    echo "sourceado"
    return 0
fi 

export REPO_URL="https://github.com"

# Time threshold
export TIME_THRESHOLD=604800    # 1 week in seconds
export MGR_TIME_THRESHOLD=10    # 1 week in seconds
# TIME_THRESHOLD=10 # 20 hours in seconds


source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/generic-auto-updater.sh"

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
            local NEXT_DATE
            NEXT_DATE=$(cat "$ZSH_PLUGIN_DIR"/."$i")
            
            echo -e "${BRIGHT_CYAN}$i:${NO_COLOR} $(date -d @$((NEXT_DATE+TIME_THRESHOLD)) "+%d-%m-%Y %H:%M:%S")"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}

# _auto_updater_mgr