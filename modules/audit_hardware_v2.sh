#!/bin/bash

################################################################################
# Hardware Audit Module - Phase 1 (Simple Version)
# Purpose: Collect Hardware Info for NSCS OS Project
################################################################################

# --- Basic Setup ---
# Fixing the directory to your specific project folder
REPORT_DIR="$HOME/nscs_os_project/reports"
mkdir -p "$REPORT_DIR"

# Basic Colors for readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "-------------------------------------------------------"
echo "  NSCS - Hardware Information Collection"
echo "-------------------------------------------------------"

# 1. MOTHERBOARD INFO
echo -e "${BLUE}[*] Checking Motherboard...${NC}"
# Using simple commands like dmidecode and lspci
MB_NAME=$(sudo dmidecode -s baseboard-product-name 2>/dev/null || echo "Unknown")
MB_CHIPSET=$(lspci | grep -i "host bridge" | head -1 | cut -d: -f3)

echo "Name: $MB_NAME"
echo "Chipset: $MB_CHIPSET"

# 2. BIOS INFO
echo -e "\n${BLUE}[*] Checking BIOS...${NC}"
BIOS_VER=$(sudo dmidecode -s bios-version 2>/dev/null)
BIOS_DATE=$(sudo dmidecode -s bios-release-date 2>/dev/null)
[ -d /sys/firmware/efi ] && FIRMWARE="UEFI" || FIRMWARE="Legacy BIOS"

echo "Version: $BIOS_VER"
echo "Release: $BIOS_DATE"
echo "Type: $FIRMWARE"

# 3. CPU INFO
echo -e "\n${BLUE}[*] Checking CPU...${NC}"
CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

echo "Model: $CPU_MODEL"
echo "Cores: $CPU_CORES"

# 4. MEMORY INFO
echo -e "\n${BLUE}[*] Checking RAM...${NC}"
RAM_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
RAM_FREE=$(free -h | grep "Mem:" | awk '{print $4}')

echo "Total RAM: $RAM_TOTAL"
echo "Free RAM: $RAM_FREE"

# 5. STORAGE INFO
echo -e "\n${BLUE}[*] Checking Disk Usage...${NC}"
df -h --total | grep "total" | awk '{print "Total Size: " $2 " (Used: " $3 ")"}'

# --- SAVE TO JSON ---
echo -e "\n-------------------------------------------------------"
read -p "Do you want to save this to a JSON file? (y/n): " confirm

if [ "$confirm" == "y" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE_NAME="$REPORT_DIR/hardware_report_$TIMESTAMP.json"
    
    # Simple JSON construction
    cat <<EOF > "$FILE_NAME"
{
  "timestamp": "$(date)",
  "motherboard": "$MB_NAME",
  "chipset": "$MB_CHIPSET",
  "bios_version": "$BIOS_VER",
  "cpu": "$CPU_MODEL",
  "ram_total": "$RAM_TOTAL"
}
EOF
    echo -e "${GREEN}Success: Report saved to $FILE_NAME${NC}"
else
    echo "Report not saved."
fi

echo -e "\nAudit Finished."