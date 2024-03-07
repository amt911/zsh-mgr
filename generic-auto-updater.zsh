#!/bin/zsh

# Debería comprobar si los directorios existen?

if [ "$GENERIC_AUTO_UPDATER_ZSH" != yes ]; then
    GENERIC_AUTO_UPDATER_ZSH=yes
else
    return 0
fi 

source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-common-variables.zsh"
source "$ZSH_CONFIG_DIR/zsh-mgr/zsh-mgr-common-functions.zsh"

# Converts the repo folder input to the timestamp file.
# 
# $1: Repo folder location (including folder itself).
# $2 (Optional): File timestamp location. If left unused will use
# the environment variable $ZSH_PLUGIN_DIR
# 
# return: The path to the timestamp file.
_from_repo_to_time_file(){
    local -r REPO_LOC=$(_sanitize_location "$1")
    local TIME_LOC

    # If there is no file location available, exit the function
    if [ -z "$ZSH_PLUGIN_DIR" ] && [ "$#" -lt "2" ]; then
        return 1
    fi

    if [ "$#" -eq "2" ]; then
        TIME_LOC=$(_sanitize_location "$2")
    else
        TIME_LOC=$(_sanitize_location "$ZSH_PLUGIN_DIR")
    fi
    # Gets the component name
    local -r REPO_NAME=$(basename "$REPO_LOC")

    local -r DATE_FN="$TIME_LOC/.$REPO_NAME"

    echo "$DATE_FN"    
}

# A generic git updater for a variety of projects
# 
# $1: Component name to be printed. It should be just the name
# of the plugin/component. Example: $1="zsh" -> Output: Updating zsh
# 
# $2: Location where the repo resides (including the repo folder)
# 
# $3 (Optional): Location where the timestamp file will be added.
# If this argument is not used, the file will be located at $ZSH_PLUGIN_DIR
# 
# post: A timestamp file will be added to control auto-update shedule.
# 
# return: 0 if everything went ok, 1 in any other case
_generic_updater(){
    local -r RAW_MSG="Updating $1"     # Raw message to count character length
    local -r MSG="Updating ${GREEN}$1${NO_COLOR}"      # Message formatted with colors
    local -r LOCATION=$(_sanitize_location "$2")
    local TIMESTAMP_LOC
    
    # If there is no file location available, exit the function
    if [ -z "$ZSH_PLUGIN_DIR" ] && [ "$#" -lt "3" ]; then
        echo "${RED}Error, missing argument and no environment variable set."
        return 1
    fi

    # Setting the timestamp file location
    if [ "$#" -eq "3" ];then
        TIMESTAMP_LOC=$(_sanitize_location "$3")
        # echo "Using arg $TIMESTAMP_LOC"
    else
        TIMESTAMP_LOC=$(_sanitize_location "$ZSH_PLUGIN_DIR")
        # echo "Using env var $TIMESTAMP_LOC"
    fi

    print_message "$MSG" "$((COLUMNS - 4))" "$BRIGHT_CYAN#$NO_COLOR" "${#RAW_MSG}"

    # We pull the latest commit from the repository
    git -C "$LOCATION" pull
    local -r ERR_CODE="$?"

    if [ $ERR_CODE -ne "0" ]; then
        local -r RAW_ERR_MSG="Error updating $1"
        local -r ERR_MSG="${RED}Error updating $1${NO_COLOR}"

        print_message "$ERR_MSG" "$((COLUMNS - 4))" "$RED#$NO_COLOR" "${#RAW_ERR_MSG}"

        return 1
    fi

    # Creates the path to the timestamp file
    local -r DATE_FN=$(_from_repo_to_time_file "$LOCATION" "$TIMESTAMP_LOC")    
    
    # echo "$DATE_FN"

    # Adds a timestamp
    date +%s > "$DATE_FN"

    return 0
}


# A generic auto-updater, which updates the given repository.
# 
# $1: Component name to be printed. It should be just the name
# of the plugin/component. Example: $1="zsh" -> Output: Updating zsh
# 
# $2: Location where the repo resides (including the repo folder)
# 
# $3: Time threshold measured in seconds.
# 
# $4 (Optional): Location where the timestamp file is located. 
# If this argument is not used, it will the environment variable
# $ZSH_PLUGIN_DIR
_generic_auto_updater(){
    local TIMESTAMP_LOC
    local -r LOCATION=$(_sanitize_location "$2")
    local -r TIME_THRESHOLD="$3"

    # If there is no file location available, exit the function
    if [ -z "$ZSH_PLUGIN_DIR" ] && [ "$#" -lt "4" ]; then
        echo "${RED}Error, missing argument and no environment variable set."
        return 1
    fi

    # Setting the timestamp file location
    if [ "$#" -eq "4" ];then
        TIMESTAMP_LOC=$(_sanitize_location "$4")
        # echo "Using arg $TIMESTAMP_LOC"
    else
        TIMESTAMP_LOC=$(_sanitize_location "$ZSH_PLUGIN_DIR")
        # echo "Using env var $TIMESTAMP_LOC"
    fi    


    local -r DATE_FN=$(_from_repo_to_time_file "$LOCATION" "$TIMESTAMP_LOC")

    if [ ! -f "$DATE_FN" ] || [ $(($(date +%s) - $(cat "$DATE_FN"))) -ge "$TIME_THRESHOLD" ]; then
        # echo "Tengo que actualizar"
        _generic_updater "$1" "$LOCATION" "$TIME_THRESHOLD" "$TIMESTAMP_LOC"
    fi  
}


# $1: Row. The date must be on the last column and in seconds since epoch.
# Also, the date must represent the last update done.
# 
# $2: Delimiter.
# 
# $3: Time threshold.
# 
# lejos: verde, mediano: amarillo, cerca: rojo
# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"
# date +%s
# _color_row_on_date "hola#adiois#prueba#1699696478" "#" "100"
_color_row_on_date(){
    local -r ROW="$1"
    local -r DELIM="$2"
    local -r THRESHOLD="$3"
    local -r DATE_TODAY=$(date +%s)
    local -r COL_NUM=$(_get_column_length "$ROW" "$DELIM")
    local -r DATE_ROW=$(_get_column_text_at "$ROW" "$COL_NUM" "$DELIM")
    local -r DATE_DIFF=$(( DATE_TODAY - DATE_ROW ))
    local -r NEXT_DATE=$(( DATE_ROW + THRESHOLD ))
    local color_res
    local output_row

    # If bc does not exist, then we leave the output the same
    if ! check_cmd_exists "bc";
    then
        output_row=$(_change_column_entry "$ROW" "$COL_NUM" "$(date -d @"$NEXT_DATE" "+%d-%m-%Y %H:%M:%S")" "$DELIM")
        echo "$output_row"
        return 1
    fi

    if (( $(echo "$DATE_DIFF < $(echo "0.25*$THRESHOLD" | bc -l)" | bc -l) ));
    then
        color_res="$GREEN"    
    elif (( $(echo "$DATE_DIFF < $(echo "0.75*$THRESHOLD" | bc -l)" | bc -l) ));
    then
        color_res="$YELLOW"
    else
        color_res="$RED"
    fi

    # IT NEEDS TO ADD THE THRESHOLD TO THE CURRENT DATE
    output_row=$(_color_row "$(_change_column_entry "$ROW" "$COL_NUM" "$(date -d @"$NEXT_DATE" "+%d-%m-%Y %H:%M:%S")" "$DELIM")" "$DELIM" "$color_res")

    echo "$output_row"
}

# $1: 
_display_color_legend(){
    local -r RAW_MSG="RED#Less than 25% left to update.\nYELLOW#Less than 75%, but more than 25% left to update.\nGREEN#Less than 100%, but more than 75% left to update."
    local -r COLORED_MSG="${RED}RED${NO_COLOR}#Less than 25% left to update.\n${YELLOW}YELLOW${NO_COLOR}#Less than 75%, but more than 25% left to update.\n${GREEN}GREEN${NO_COLOR}#Less than 100%, but more than 75% left to update."

    _create_table "$RAW_MSG" "#" "" "$COLORED_MSG"
}

# $1: Component name to be printed.
# $2: Repository location.
# $3: Time threshold.
# $4: First row name separated by "#". Example: Hello#Bye Bye
# $5 (Optional): Table color. Leave empty string for no color.
# $6 (Optional yes/no): Display color legend? Default: yes
# $7 (Optional): Timestamp file location. If not set it will use $ZSH_PLUGIN_DIR.
_check_comp_update_date(){
    local -r COMP_NAME="$1"
    local -r REPO_LOC="$2"
    local -r THRESHOLD="$3"
    local -r FIRST_ROW="$4"
    local -r TABLE_COLOR="${5:-""}"
    local -r LEGEND="${6:-yes}"
    local -r TST_DIR="${7:-$ZSH_PLUGIN_DIR}"
    local -r TST_FILE_LOC="$(_from_repo_to_time_file "$REPO_LOC" "$TST_DIR")"
    local raw_msg
    local colored_msg

    if [ ! -f "$TST_FILE_LOC" ];
    then
        raw_msg="$COMP_NAME#unknown"        
        colored_msg="$raw_msg"
    else
        raw_msg="$COMP_NAME#$(date -d @"$(( $(cat "$TST_FILE_LOC") + THRESHOLD ))" "+%d-%m-%Y %H:%M:%S" )"
        colored_msg=$(_color_row_on_date "$COMP_NAME#$(cat "$TST_FILE_LOC")" "#" "$THRESHOLD")
    fi

    _create_table "$FIRST_ROW\n$raw_msg" "#" "$TABLE_COLOR" "$FIRST_ROW\n$colored_msg"

    [ "$LEGEND" = "yes" ] && _display_color_legend 

    return 0    
}