# Colors

if [ "$ZSH_COMMON_VARIABLES" != yes ]; then
    ZSH_COMMON_VARIABLES=yes
    echo "no sourceado"
else
    echo "sourceado"
    return 0
fi 

readonly RED='\033[0;31m'
readonly NO_COLOR='\033[0m'
readonly GREEN='\033[0;32m'
readonly BRIGHT_CYAN='\033[0;96m'