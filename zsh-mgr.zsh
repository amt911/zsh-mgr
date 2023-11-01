#!/bin/bash

export REPO_URL="https://github.com"

# Time threshold
export TIME_THRESHOLD=604800    # 1 week in seconds
# TIME_THRESHOLD=10 # 20 hours in seconds

# Colors
RED='\033[0;31m'
NO_COLOR='\033[0m'
GREEN='\033[0;32m'
BRIGHT_CYAN='\033[0;96m'

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
    AUTHOR=$(echo "$1" | cut -d "/" -f 1)
    PLUGIN_NAME=$(echo "$1" | cut -d "/" -f 2)
    error=0 # By default, there are no errors

    #Se comprueba si existe el directorio, indicando que se ha descargado
    if [ ! -d "$ZSH_PLUGIN_DIR/$PLUGIN_NAME" ]; then
        raw_msg="Installing $PLUGIN_NAME"
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

    PLUGIN_NAME=""
}

#Updates a plugin given as input.
#$1: The name of the plugin. It must be set before calling the function.
#pre: The plugin must be installed or else the function will error out.
_update_plugin() {
    raw_msg="Updating $1"
    print_message "Updating $GREEN$1$NO_COLOR" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#raw_msg}"
    error=0

    cd "$ZSH_PLUGIN_DIR/$1" || exit
    git pull

    #We save the output code of the previous command
    error="$?"

    cd "$HOME" || exit # JUST IN CASE

    if [ "$error" -eq 0 ]; then
        date +%s >"$ZSH_PLUGIN_DIR/.$1"    
    else
        echo -e "${RED}Error updating $PLUGIN_NAME${NO_COLOR}"
    fi
}

#\\033\[0;?[0-9]*m to find ansi escape codes

#Prints a message given a max length. It fills the remaining space with "#"
#$1: Message to be printed
#$2: Max length of the message (including the message itself)
#$3: Character to fill the remaining space. It can be colored
#$4 (optional): Message length. Useful when it has ANSI escape codes, since it detects them as characters.
print_message() {
    msg_length=${#1}

    if [ $# -eq 4 ]; then
        msg_length=$4
    fi

    max_length="$2"
    hashtag_nro=$(((max_length - msg_length - 2) / 2))
    #echo "hash: $hashtag_nro"
    
    printf "\n"
    printf "%0.s$3" $(seq 1 "$2")
    printf "\n"
    printf "%0.s$3" $(seq 1 "$hashtag_nro")

    if [ $((msg_length % 2)) -ne 0 ]; then
        printf " %b  " "$1"
    else
        printf " %b " "$1"
    fi

    printf "%0.s$3" $(seq 1 "$hashtag_nro")
    printf "\n"
    printf "%0.s$3" $(seq 1 "$2")
    printf "\n"    
}

#Lists all loaded plugins
list_plugins() {
    cd "$ZSH_PLUGIN_DIR" || exit
    res=$(find . -maxdepth 1 -type f -name ".*" | sed 's/^\.\/\.//')
    cd "$HOME" || exit

    echo "$res"
}


#Updates all loaded plugins
update_plugins(){
    #First we check if the output is empty
    plugins_list=$(list_plugins)

    if [ "$plugins_list" != "" ]; then
        #Then we insert them inside an array to iterate over them
        loaded_plugins=("${(@f)$(list_plugins)}")

        for i in "${loaded_plugins[@]}"
        do
            _update_plugin "$i"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}


# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"

check_plugins_update_date() {
    plugins_list=$(list_plugins)

    if [ "$plugins_list" != "" ]; then
        #Then we insert them inside an array to iterate over them
        loaded_plugins=("${(@f)$(list_plugins)}")

        for i in "${loaded_plugins[@]}"
        do
            # _update_plugin "$i"
            next_date=$(cat "$ZSH_PLUGIN_DIR"/."$i")
            echo -e "${BRIGHT_CYAN}$i:${NO_COLOR} $(date -d @$((next_date+TIME_THRESHOLD)) "+%d-%m-%Y %H:%M:%S")"
        done    

    else
        echo -e "${RED}No plugins loaded/installed${NO_COLOR}"
    fi
}