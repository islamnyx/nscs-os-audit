#!/bin/bash

################################################################################
# Hardware Audit Module - Phase 1 (SIMPLE & WORKING)
# Displays hardware information on screen, then saves to JSON
# Author: NSCS OS Project - Part 1
################################################################################

# ============================================================================
# CONFIGURATION & COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directories
export LOG_DIR="$HOME/.nscs_audit"
export REPORT_DIR="$LOG_DIR/reports"
CONFIG_DIR="$LOG_DIR/config"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

print_info() {
    printf "  %-30s : %s\n" "$1" "$2"
}

init_system() {
    mkdir -p "$LOG_DIR" "$REPORT_DIR" "$CONFIG_DIR" 2>/dev/null
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

escape_json() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          Hardware Information Collection System v1.0                  ║
║                  NSCS - Operating Systems Project                     ║
║                         Part 1 - Hardware Audit                       ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    init_system
    
    echo -e "${YELLOW}Collecting and displaying hardware information...${NC}"
    echo ""
    
    # ================================================================
    # MOTHERBOARD
    # ================================================================
    
    print_header "MOTHERBOARD INFORMATION"
    
    MB_NAME="Unknown"
    MB_CHIPSET="Unknown"
    MB_PLATFORM="Desktop"
    
    if cmd_exists dmidecode; then
        MB_NAME=$(sudo dmidecode -s baseboard-product-name 2>/dev/null || echo "Unknown")
        local CHASSIS=$(sudo dmidecode -s chassis-type 2>/dev/null)
        if echo "$CHASSIS" | grep -qi "laptop\|portable\|notebook"; then
            MB_PLATFORM="Laptop"
        fi
    fi
    
    if cmd_exists lspci; then
        MB_CHIPSET=$(lspci 2>/dev/null | grep -i "host bridge" | head -1 | sed 's/.*: //')
    fi
    
    print_info "Name" "$MB_NAME"
    print_info "Chipset" "$MB_CHIPSET"
    print_info "Platform" "$MB_PLATFORM"
    
    # ================================================================
    # BIOS
    # ================================================================
    
    print_header "BIOS INFORMATION"
    
    BIOS_VERSION="Unknown"
    BIOS_RELEASE="Unknown"
    BIOS_TYPE="x64-based"
    BIOS_FIRMWARE="BIOS"
    BIOS_SECURE="Disabled"
    
    if cmd_exists dmidecode; then
        BIOS_VERSION=$(sudo dmidecode -s bios-version 2>/dev/null || echo "Unknown")
        BIOS_RELEASE=$(sudo dmidecode -s bios-release-date 2>/dev/null || echo "Unknown")
        
        if [ -d /sys/firmware/efi ]; then
            BIOS_FIRMWARE="UEFI"
            if compgen -G "/sys/firmware/efi/efivars/SecureBoot*" > /dev/null 2>&1; then
                BIOS_SECURE="Enabled"
            fi
        fi
    fi
    
    print_info "Version" "$BIOS_VERSION"
    print_info "Release Date" "$BIOS_RELEASE"
    print_info "System Type" "$BIOS_TYPE"
    print_info "Firmware Type" "$BIOS_FIRMWARE"
    print_info "Secure Boot" "$BIOS_SECURE"
    
    # ================================================================
    # CPU
    # ================================================================
    
    print_header "CPU INFORMATION"
    
    CPU_MFR="Unknown"
    CPU_MODEL="Unknown"
    CPU_CORES="Unknown"
    CPU_SOCKETS="Unknown"
    
    if cmd_exists lscpu; then
        CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | xargs)
        CPU_CORES=$(lscpu 2>/dev/null | grep "^Core(s) per socket" | awk '{print $NF}')
        CPU_SOCKETS=$(lscpu 2>/dev/null | grep "^Socket(s)" | awk '{print $NF}')
        
        [[ "$CPU_MODEL" =~ Intel ]] && CPU_MFR="Intel"
        [[ "$CPU_MODEL" =~ AMD ]] && CPU_MFR="AMD"
    fi
    
    print_info "Manufacturer" "$CPU_MFR"
    print_info "Model" "$CPU_MODEL"
    print_info "Cores per Socket" "$CPU_CORES"
    print_info "Number of Sockets" "$CPU_SOCKETS"
    
    # ================================================================
    # MEMORY
    # ================================================================
    
    print_header "MEMORY INFORMATION"
    
    RAM_TOTAL="Unknown"
    RAM_AVAILABLE="Unknown"
    
    if [ -f /proc/meminfo ]; then
        local TOTAL_KB=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local AVAIL_KB=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        
        if [ -n "$TOTAL_KB" ]; then
            RAM_TOTAL=$(awk "BEGIN {printf \"%.2f GB\", $TOTAL_KB/1024/1024}")
            RAM_AVAILABLE=$(awk "BEGIN {printf \"%.2f GB\", $AVAIL_KB/1024/1024}")
        fi
    fi
    
    print_info "Total RAM" "$RAM_TOTAL"
    print_info "Available RAM" "$RAM_AVAILABLE"
    
    # ================================================================
    # NETWORK
    # ================================================================
    
    print_header "NETWORK INFORMATION"
    
    if cmd_exists ip; then
        local NET_COUNT=0
        while IFS= read -r interface; do
            if [ -n "$interface" ] && [ "$interface" != "lo" ]; then
                local MAC=$(ip link show "$interface" 2>/dev/null | grep "link/ether" | awk '{print $2}')
                local IPV4=$(ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
                
                print_info "Interface: $interface" ""
                print_info "  MAC Address" "$MAC"
                print_info "  IP Address" "$IPV4"
                ((NET_COUNT++))
            fi
        done < <(ip link show 2>/dev/null | grep "^[0-9]" | awk '{print $2}' | tr -d ':')
        
        if [ $NET_COUNT -eq 0 ]; then
            print_info "Status" "No network interfaces found"
        fi
    fi
    
    # ================================================================
    # DISK
    # ================================================================
    
    print_header "DISK INFORMATION"
    
    if cmd_exists df; then
        df -h 2>/dev/null | tail -n +2 | while read -r FS SIZE USED AVAIL USAGE MOUNT; do
            print_info "Filesystem" "$FS"
            print_info "  Size" "$SIZE"
            print_info "  Used" "$USED"
            print_info "  Available" "$AVAIL"
            print_info "  Usage" "$USAGE"
            echo ""
        done
    fi
    
    # ================================================================
    # SAVE OPTION
    # ================================================================
    
    print_header "SAVE REPORT"
    read -p "Save this report to JSON file? (y/n) " -n 1 -r SAVE_REPORT
    echo ""
    
    if [[ $SAVE_REPORT =~ ^[Yy]$ ]]; then
        local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        local HOSTNAME=$(hostname)
        local REPORT_FILE="$REPORT_DIR/hardware_report_full_$(date +%Y%m%d_%H%M%S).json"
        
        cat > "$REPORT_FILE" <<EOJSON
{
    "Metadata": {
        "Timestamp": "$TIMESTAMP",
        "Hostname": "$HOSTNAME",
        "Report Type": "Full Hardware Audit",
        "Tool Version": "1.0"
    },
    "Motherboard": {
        "Name": "$(escape_json "$MB_NAME")",
        "Chipset": "$(escape_json "$MB_CHIPSET")",
        "Platform": "$MB_PLATFORM"
    },
    "BIOS": {
        "Version": "$(escape_json "$BIOS_VERSION")",
        "Release Date": "$(escape_json "$BIOS_RELEASE")",
        "System Type": "$BIOS_TYPE",
        "Firmware Type": "$BIOS_FIRMWARE",
        "Secure Boot": "$BIOS_SECURE"
    },
    "CPU": {
        "Manufacturer": "$CPU_MFR",
        "Model": "$(escape_json "$CPU_MODEL")",
        "Cores": "$CPU_CORES",
        "Sockets": "$CPU_SOCKETS"
    },
    "RAM": {
        "Total": "$RAM_TOTAL",
        "Available": "$RAM_AVAILABLE"
    }
}
EOJSON
        
        log_success "Report saved to: $REPORT_FILE"
        echo ""
        echo "View report with:"
        echo "  cat $REPORT_FILE | jq '.'"
    else
        log_info "Report not saved"
    fi
    
    print_header "AUDIT COMPLETE"
    log_success "Hardware audit completed successfully!"
    echo ""
}

main "$@"