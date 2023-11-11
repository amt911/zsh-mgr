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

# Gets the column length from character separated string.
# 
# $1: String.
# 
# $2: Delimiter used in  $1.
# 
# return: The number of of columns necessary.
# 
# Example of entry: hello:hola:bonjour
_get_column_length(){
    local -r DELIM="$2"
    local -r RES=$((${#${1//[^$DELIM]/}} + 1))

    echo $RES
}

# Gets the string saved at column number.
# 
# $1: Text separated by delimiter.
# 
# $2: Column number.
# 
# $3: Delimiter.
# 
# Example of entry: hello:hola:bonjour
_get_column_text_at(){
    local -r TEXT="$1"
    local -r COL_NUM="$2"
    local -r DELIM="$3"

    echo "$TEXT" | cut -d "$DELIM" -f "$COL_NUM"
}

# Gets the highest character count on every column.
#
# $1: Table, encoded using delimiter for columns and newlines for rows.
# 
# $2: Delimiter for columns.
# 
# return: The maximum character length of every column. Using the same delimiter.
# 
# Output example fro 3 columns: 1:2:3
# 
# example: 1:2:3\n11:22:33\ncomo:1:4\n33:testing:33
# _max_char_table "1:2:3\n11:22:33\ncomo:1:4\n33:testing:33" ":"
# 
# 
_max_char_table(){
    # Only works in zsh
    local -r DELIM="$2"
    # local -r TABLE=("${(@f)$(echo "$1")}")
    TABLE=("${(@f)$(echo "$1")}")
    local -r FIL="${#TABLE[@]}"
    local -r COL=$(_get_column_length "${TABLE[1]}" "$DELIM")
    local max
    local res=""
    local entry
    local entry_len

    # echo -e "${TABLE[1]}\nY su tamaño es: $FIL\nY el otro es: $COL"

    # {1..$FIL}: Only works in zsh 
    for j in {1..$COL}
    do
        max="-1"
        entry_len="-1"
        for i in {1..$FIL}
        do
            entry=$(_get_column_text_at "${TABLE[$i]}" "$j" "$DELIM")
            entry_len=${#entry}
            
            [ "$entry_len" -gt "$max" ] && max="$entry_len"
        done

        if [ "$j" -eq $COL ]; then
            res+="$max"
        else
            res+="$max$DELIM"
        fi
    done

    echo "$res"
}


# Colors a row with the given color.
# 
# $1: String to be colored.
# 
# $2: Delimiter.
# 
# $3: Color.
# _color_row "123:33:try me:fecha" ":" "$RED"
_color_row(){
    local -r ROW="$1"
    local -r DELIM="$2"
    local -r COLOR="$3"
    local -r COL_NUM=$(_get_column_length "$ROW" "$DELIM")
    local res=""
    local aux

    for i in {1..$COL_NUM}
    do
        if [ "$i" -eq "$COL_NUM" ];then
            aux=$(_get_column_text_at "$ROW" "$i" "$DELIM")
            res+="${COLOR}$aux${NO_COLOR}"

        else
            aux=$(_get_column_text_at "$ROW" "$i" "$DELIM")
            res+="${COLOR}$aux${NO_COLOR}$DELIM"
        fi
    done

    echo -e "$res"
}



# Creates a table with the array passed as input. It can be colored.
# 
# $1: Array with every entry separated by a delimiter. 
# Example: (hello:hola:bonjour bye:adios:aurevoir)
# 
# $2: Delimiter
# 
# $3: Same array as $1, but colored. It only needs to be used when you want color in the output.
# 
# lejos: cyan, mediano: verde, cerca: rojo
# date -d @1679524012 "+%d-%m-%Y %H:%M:%S"
# date +%s
# _create_table(){

# }
