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
# $3 (Optional): Number to be added to final result.
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
    local extra="0"

    [ "$#" -eq "3" ] && extra="$3"

    # echo -e "${TABLE[1]}\nY su tamaño es: $FIL\nY el otro es: $COL"

    local j
    local i
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
        unset i

        max=$((max+extra))

        if [ "$j" -eq "$COL" ]; then
            res+="$max"
        else
            res+="$max$DELIM"
        fi
    done
    unset j

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

    local i
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
    unset i

    echo -e "$res"
}

# Changes column entry to specified string.
# 
# $1: Row to be changed.
# 
# $2: Column position.
# 
# $3: New string.
# 
# $4: Delimiter.
_change_column_entry(){
    local -r ROW="$1"
    local -r COL_POS="$2"
    local -r NEW_STR="$3"
    local -r DELIM="$4"
    local -r COL_NUM=$(_get_column_length "$ROW" "$DELIM")
    local res

    if [ "$COL_POS" -gt "$COL_NUM" ];
    then
        echo "$ROW"
        return 0
    fi

    local i
    for i in {1..$COL_NUM}
    do
        if [ "$i" -eq "$COL_POS" ];
        then
            res+="$NEW_STR"
        else
            res+=$(_get_column_text_at "$ROW" "$i" "$DELIM")
        fi

        if [ "$i" -ne "$COL_NUM" ];
        then
            res+="$DELIM"
        fi
    done
    unset i

    echo "$res"
}

# Creates a table with the array passed as input. It can be colored.
# 
# $1: Array with every entry separated by a delimiter and newlines. 
# Example: (hello:hola:bonjour bye:adios:aurevoir)
# 
# $2: Delimiter
# 
# $3: Table color. Leave empty or empty string to paint it in the default terminal color.
# 
# $4 (Optional): Same array as $1, but colored. It only needs to be used when you want color in the output.
# 
# _create_table "hola:queso:adios" ":" ""
# _create_table "hola:queso:adios\nhola:bola:cola" ":" ""
# _create_table "hola:queso:adios\nhola:bola:colaxddasdasdd" ":" ""
_create_table(){
    local -r RAW_TABLE=("${(@f)$(echo "$1")}")
    local -r DELIM="$2"
    local -r MAX_CHAR_COL=$(_max_char_table "$1" "$DELIM" "2")
    local -r COL_NUM=$(_get_column_length "${RAW_TABLE[1]}" "$DELIM")
    local i

    if [ "${#RAW_TABLE[@]}" -eq "0" ];
    then
        echo "${RED}No array found${NO_COLOR}"
        return 1
    fi

    local -r COLOR="${3:-"${NO_COLOR}"}"  

    # Check if there is colored text
    if [ "$#" -eq "4" ];
    then
        local -r TABLE=("${(@f)$(echo "$4")}")
    else
        local -r TABLE=("${RAW_TABLE[@]}")
    fi

    # Top of table
    printf "${COLOR}┌${NO_COLOR}"

    for i in {1..$COL_NUM}
    do
        printf "%0.s${COLOR}─${NO_COLOR}" $(seq 1 "$(_get_column_text_at "$MAX_CHAR_COL" "$i" "$DELIM")")

        [ "$COL_NUM" -gt "1" ] && [ "$i" -lt "$COL_NUM" ] && printf "${COLOR}┬${NO_COLOR}"
    done
    unset i
    printf "${COLOR}┐${NO_COLOR}\n"

    # Content of table
    local spaces="0"
    local max_length="0"
    local msg_length="0"
    local -r SPACE_CHAR=" "
    local j
    local k

    for i in {1..${#TABLE[@]}}
    do
        printf "${COLOR}│${NO_COLOR}"
        for j in {1..$COL_NUM}
        do
            # Max character length of this column
            max_length=$(_get_column_text_at "$MAX_CHAR_COL" "$j" "$DELIM" )

            # Message length for this cell
            msg_length=$(_get_column_text_at "${RAW_TABLE[$i]}" "$j" "$DELIM")

            msg_length=${#msg_length}

            # Number of spaces needed
            spaces=$(( ( max_length - msg_length) / 2 ))


            printf "%0.s$SPACE_CHAR" $(seq 1 $spaces)
            
            printf "%b" "$(_get_column_text_at "${TABLE[$i]}" "$j" "$DELIM")"

            # If there was a remainder, we add 1 to the number of spaces
            (( (( max_length - msg_length) % 2) != 0 )) && spaces=$(( spaces + 1 ))

            printf "%0.s$SPACE_CHAR" $(seq 1 $spaces)

            printf "${COLOR}│${NO_COLOR}"
        done
        unset j

        # Print the middle line
        printf "\n"

        if [ "$i" -lt "${#TABLE[@]}" ];
        then
            printf "${COLOR}├${NO_COLOR}"

            for k in {1..$COL_NUM}
            do
                printf "%0.s${COLOR}─${NO_COLOR}" $(seq 1 "$(_get_column_text_at "$MAX_CHAR_COL" "$k" "$DELIM")")

                [ "$COL_NUM" -gt "1" ] && [ "$k" -lt "$COL_NUM" ] && printf "${COLOR}┼${NO_COLOR}"
            done
            unset k
            printf "${COLOR}┤${NO_COLOR}\n"    
        fi
    done
    unset i


    # Bottom of table
    printf "${COLOR}└${NO_COLOR}"

    for i in {1..$COL_NUM}
    do
        printf "%0.s${COLOR}─${NO_COLOR}" $(seq 1 "$(_get_column_text_at "$MAX_CHAR_COL" "$i" "$DELIM")")

        [ "$COL_NUM" -gt "1" ] && [ "$i" -lt "$COL_NUM" ] && printf "${COLOR}┴${NO_COLOR}"
    done
    unset i
    printf "${COLOR}┘${NO_COLOR}\n"
}