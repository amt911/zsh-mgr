#!/bin/zsh

# Colors

if [ "$ZSH_COMMON_VARIABLES" != yes ]; then
    ZSH_COMMON_VARIABLES=yes
else
    return 0
fi 

readonly RED='\033[0;31m'
readonly NO_COLOR='\033[0m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BRIGHT_CYAN='\033[0;96m'
readonly CYAN='\033[0;36m'

# INFO about color scheme:
# Blue: Information about anything but errors.
# Red: Errors.
# Yellow: Input message (read from stdin).
# Green: Success messages.

# echo "${GRAY}hola${NO_COLOR}"

_print_colors(){
    local i
    for i in {1..255}
    do
        echo -e "\033[0;${i}m$i$NO_COLOR"
    done
    unset i
}