#!/bin/bash

#!/bin/bash

# ANSI Color Codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to draw a professional header box
draw_header() {
    local title="$1"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC} %*s %*s ${CYAN}║${NC}\n" $(( (56 + ${#title}) / 2 )) "$title" $(( (56 - ${#title}) / 2 )) ""
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Function for the "Gathering" animation
show_progress() {
    local task="$1"
    echo -ne "[ ] Gathering $task..."
    sleep 0.4 # Simulate processing
    echo -e "\r[${GREEN}✔${NC}] Gathering $task"
}