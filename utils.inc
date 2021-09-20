# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# display red collor text
function red {
    printf "${RED}$@${NC}\n"
}

# display green collor text
function green {
    printf "${GREEN}$@${NC}\n"
}

# display ryellow collor text
function yellow {
    printf "${YELLOW}$@${NC}\n"
}

# display blue collor text
function blue {
    printf "${BLUE}$@${NC}\n"
}

# check if specific package is installed
function IsInstalled() {
    installed=$(dpkg-query -W -f '${Status}\n' "${1}" 2>&1|awk '/ok installed/{print 0;exit}{print 1}')
    return ${installed}
}
