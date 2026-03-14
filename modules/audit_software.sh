#!/bin/bash

################################################################################
# Software Audit Module - Phase 2 (Simple Student Version)
# Purpose: Collect OS and Software Info for NSCS OS Project
################################################################################

# --- Setup Paths & Colors ---
REPORT_DIR="$HOME/nscs_os_project/reports"
mkdir -p "$REPORT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo "-------------------------------------------------------"
echo "  NSCS - Software & OS Audit Module"
echo "-------------------------------------------------------"

# 1. OS & KERNEL INFORMATION
echo -e "${BLUE}[*] Collecting OS Info...${NC}"
OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL_VER=$(uname -r)
ARCH=$(uname -m)
HOSTNAME=$(hostname)

echo "OS: $OS_NAME"
echo "Kernel: $KERNEL_VER"
echo "Arch: $ARCH"

# 2. USERS & UPTIME
echo -e "\n${BLUE}[*] Checking Users and Uptime...${NC}"
UPTIME_VAL=$(uptime -p)
CURRENT_USERS=$(who | awk '{print $1}' | sort -u | xargs)

echo "Uptime: $UPTIME_VAL"
echo "Active Users: $CURRENT_USERS"

# 3. PROCESSES & SERVICES
echo -e "\n${BLUE}[*] Analyzing Processes & Services...${NC}"
PROC_COUNT=$(ps aux | wc -l)
# Count running services (standard systemd command)
SERV_COUNT=$(systemctl list-units --type=service --state=running --no-legend | wc -l)

echo "Total Processes: $PROC_COUNT"
echo "Running Services: $SERV_COUNT"
echo "Top Process: $(ps -eo comm --sort=-%cpu | head -n 2 | tail -n 1)"

# 4. NETWORK PORTS
echo -e "\n${BLUE}[*] Checking Open Ports...${NC}"
# Simple way to show listening ports
OPEN_PORTS=$(ss -tuln | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u | xargs)
echo "Listening Ports: $OPEN_PORTS"

# 5. PACKAGE COUNT
echo -e "\n${BLUE}[*] Counting Installed Packages...${NC}"
if command -v dpkg >/dev/null; then
    PKGS=$(dpkg -l | wc -l)
    MGR="dpkg/apt"
else
    PKGS=$(rpm -qa | wc -l)
    MGR="rpm/yum"
fi
echo "Manager: $MGR"
echo "Count: $PKGS"

# --- SAVE TO JSON ---
echo -e "\n-------------------------------------------------------"
read -p "Save this software data to JSON? (y/n): " save_choice

if [ "$save_choice" == "y" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE_NAME="$REPORT_DIR/software_report_$TIMESTAMP.json"
    
    # Writing the JSON manually is very "student-style"
    echo "{" > "$FILE_NAME"
    echo "  \"timestamp\": \"$(date)\"," >> "$FILE_NAME"
    echo "  \"os_name\": \"$OS_NAME\"," >> "$FILE_NAME"
    echo "  \"kernel\": \"$KERNEL_VER\"," >> "$FILE_NAME"
    echo "  \"uptime\": \"$UPTIME_VAL\"," >> "$FILE_NAME"
    echo "  \"packages\": \"$PKGS\"," >> "$FILE_NAME"
    echo "  \"open_ports\": \"$OPEN_PORTS\"" >> "$FILE_NAME"
    echo "}" >> "$FILE_NAME"
    
    echo -e "${GREEN}Success: Saved to $FILE_NAME${NC}"
else
    echo "Skipping save."
fi

echo -e "\nSoftware Audit Finished."