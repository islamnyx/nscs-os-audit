#!/bin/bash
################################################################################
# NSCS OS Project - Hardware Audit Module (HACKER EDITION)
# Phase 1 — Advanced Hardware Inventory with Hacker UI
# Author: NSCS OS Project
# Date: 2026
################################################################################

# ============================================================================
# COLORS & EFFECTS
# ============================================================================

G0='\033[0;32m'       # dim green
G1='\033[1;32m'       # bright green
G2='\033[0;92m'       # light green
CY='\033[0;36m'       # cyan
YW='\033[1;33m'       # yellow
RD='\033[1;31m'       # red
WH='\033[1;37m'       # white
DM='\033[2;32m'       # dim matrix green
NC='\033[0m'          # reset
BOLD='\033[1m'

# ============================================================================
# PATHS
# ============================================================================

REPORT_DIR="$HOME/nscs_os_project/reports"
mkdir -p "$REPORT_DIR"

# GUI mode: pass --gui to skip interactive prompts and auto-save JSON
GUI_MODE=0
for arg in "$@"; do [[ "$arg" == "--gui" ]] && GUI_MODE=1; done

TW=$(tput cols 2>/dev/null || echo 80)

# ============================================================================
# UTILITIES
# ============================================================================

_print_ascii_art() {
    center_print "██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗    ██╗ █████╗ ██████╗ ███████╗"
    center_print "██║  ██║██╔══██╗██╔══██╗██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔════╝"
    center_print "███████║███████║██████╔╝██║  ██║██║ █╗ ██║███████║██████╔╝█████╗  "
    center_print "██╔══██║██╔══██║██╔══██╗██║  ██║██║███╗██║██╔══██║██╔══██╗██╔══╝  "
    center_print "██║  ██║██║  ██║██║  ██║██████╔╝╚███╔███╔╝██║  ██║██║  ██║███████╗"
    center_print "╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
}

# ============================================================================
# RESPONSIVE TERMINAL — auto-adapts to any width (GUI or terminal)
# ============================================================================

# Always re-read terminal width — works inside GUI subprocess too
_get_tw() { tput cols 2>/dev/null || echo 80; }
TW=$(_get_tw)
# Clamp: never go below 40 or above 120
(( TW < 40 )) && TW=40
(( TW > 120 )) && TW=120

repeat_char() {
    local char="$1" count="$2"
    (( count <= 0 )) && return
    printf "%${count}s" | tr ' ' "$char"
}

# Safe divider — never overflows the terminal
divider() {
    local char="${1:-─}" color="${2:-$G0}"
    local w=$(( TW - 4 ))
    (( w < 10 )) && w=10
    echo -e "${color}$(repeat_char "$char" $w)${NC}"
}

# Center text — strips ANSI before measuring length
center_print() {
    local text="$1"
    local clean; clean=$(printf '%b' "$text" | sed 's/\x1b\[[0-9;]*[mKHABCDEFGJSTfu]//g')
    local len=${#clean}
    local pad=$(( (TW - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%${pad}s" ""
    echo -e "$text"
}

# Adaptive banner — shows ASCII art only if terminal is wide enough
# Falls back to a simple text banner on narrow screens (like the GUI panel)
print_banner() {
    local title="$1"
    local subtitle="$2"
    echo ""
    if (( TW >= 72 )); then
        # Full ASCII art — only when there is enough space
        echo -e "${G1}"
        _print_ascii_art "$title"
        echo -e "${NC}"
    else
        # Compact banner for narrow terminals / GUI
        echo -e "${G1}"
        center_print "[ NSCS — ${title} ]"
        echo -e "${NC}"
    fi
    local dw=$(( TW - 6 )); (( dw < 10 )) && dw=10
    echo -e "${DM}$(repeat_char '═' $dw)${NC}"
    center_print "${G0}${subtitle}${NC}"
    center_print "${DM}$(date '+%A %d %B %Y   %H:%M:%S')${NC}"
    echo -e "${DM}$(repeat_char '═' $dw)${NC}"
    echo ""
}

# Section header — adapts fill width to terminal
section() {
    local title="$1"
    local tlen=${#title}
    local available=$(( TW - tlen - 6 ))
    (( available < 2 )) && available=2
    local side=$(( available / 2 ))
    echo ""
    echo -en "${G0}$(repeat_char '─' $side)${NC}"
    echo -en " ${G1}${BOLD}${title}${NC} "
    echo -e "${G0}$(repeat_char '─' $side)${NC}"
}

print_field() {
    local key="$1" val="$2"
    # Truncate value if it would overflow the line
    local max_val=$(( TW - 30 ))
    (( max_val < 10 )) && max_val=10
    if (( ${#val} > max_val )); then
        val="${val:0:$max_val}..."
    fi
    printf "  ${DM}%-22s${NC} ${G1}▶${NC} ${WH}%s${NC}\n" "$key" "$val"
}

print_ok()   { echo -e "  ${G1}[ OK ]${NC}  $1"; }
print_warn() { echo -e "  ${YW}[ !! ]${NC}  $1"; }
print_info() { echo -e "  ${G0}[ ** ]${NC}  $1"; }
print_err()  { echo -e "  ${RD}[ XX ]${NC}  $1"; }

type_header() {
    local text="$1"
    # In GUI mode skip typewriter (causes flicker), just print
    if (( GUI_MODE == 1 )) || (( TW < 60 )); then
        echo -e "${G1}${text}${NC}"
    else
        echo -en "${G1}"
        while IFS= read -r -n1 char; do
            echo -n "$char"; sleep 0.015
        done <<< "$text"
        echo -e "${NC}"
    fi
}

progress() {
    local label="$1" duration="${2:-1.0}"
    # Adaptive bar width — leaves room for label + brackets + percentage
    local label_len=${#label}
    local bar_w=$(( TW - label_len - 12 ))
    (( bar_w > 40 )) && bar_w=40
    (( bar_w < 5  )) && bar_w=5
    echo -en "  ${DM}${label}${NC} ${G0}["
    local t; t=$(echo "scale=4; $duration / $bar_w" | bc 2>/dev/null || echo "0.03")
    for ((i=0; i<bar_w; i++)); do
        (( i < bar_w/3 ))                    && echo -en "${DM}█${NC}"
        (( i >= bar_w/3 && i < bar_w*2/3 ))  && echo -en "${G0}█${NC}"
        (( i >= bar_w*2/3 ))                  && echo -en "${G1}█${NC}"
        sleep "$t"
    done
    echo -e "${G1}] 100%${NC}"
}



# ============================================================================
# BOOT HEADER
# ============================================================================

clear
print_banner "HARDWARE" "Advanced Hardware Inventory  |  Phase 1  |  v2.0"
type_header ">>> INITIALIZING HARDWARE SCANNER..."
progress "Probing system buses   " 1.0
progress "Loading kernel modules " 0.8
progress "Querying DMI/SMBIOS    " 0.7
echo ""

section "MOTHERBOARD & BIOS"

MB_NAME=$(sudo dmidecode -s baseboard-product-name 2>/dev/null || echo "VirtualBox/Unknown")
MB_VENDOR=$(sudo dmidecode -s baseboard-manufacturer 2>/dev/null || echo "Unknown")
BIOS_VER=$(sudo dmidecode -s bios-version 2>/dev/null || echo "Unknown")
BIOS_DATE=$(sudo dmidecode -s bios-release-date 2>/dev/null || echo "Unknown")
[ -d /sys/firmware/efi ] && FIRMWARE="UEFI" || FIRMWARE="Legacy BIOS"

print_field "Board Name"    "$MB_NAME"
print_field "Manufacturer"  "$MB_VENDOR"
print_field "BIOS Version"  "$BIOS_VER  ($BIOS_DATE)"
print_field "Firmware Type" "$FIRMWARE"
print_ok "Motherboard information collected"

# ============================================================================
# 2. CPU
# ============================================================================

section "CPU INFORMATION"

CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
CPU_CORES=$(lscpu | grep "^CPU(s):"   | awk '{print $2}')
CPU_ARCH=$( lscpu | grep "Architecture" | awk '{print $2}')
CPU_SPEED=$(lscpu | grep "CPU MHz" | awk '{printf "%.0f MHz", $3}' 2>/dev/null || echo "N/A")
CPU_CACHE=$(lscpu | grep "L3 cache" | cut -d: -f2 | xargs 2>/dev/null || echo "N/A")
CPU_VIRT=$( lscpu | grep "Virtualization" | cut -d: -f2 | xargs 2>/dev/null || echo "N/A")

print_field "Model"          "$CPU_MODEL"
print_field "Architecture"   "$CPU_ARCH"
print_field "CPU Count"      "$CPU_CORES cores"
print_field "Clock Speed"    "$CPU_SPEED"
print_field "L3 Cache"       "$CPU_CACHE"
print_field "Virtualization" "$CPU_VIRT"
print_ok "CPU information collected"

# ============================================================================
# 3. GPU
# ============================================================================

section "GPU / GRAPHICS"

GPU_INFO=$(lspci | grep -i 'vga\|display\|3d' | cut -d: -f3 | xargs)
if [ -z "$GPU_INFO" ]; then
    print_warn "No dedicated GPU detected"
    GPU_INFO="Integrated/Not detected"
else
    print_field "GPU Device" "$GPU_INFO"
    print_ok "GPU information collected"
fi

# ============================================================================
# 4. MEMORY (RAM)
# ============================================================================

section "MEMORY (RAM)"

RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_USED=$( free -h | awk '/^Mem:/ {print $3}')
RAM_FREE=$( free -h | awk '/^Mem:/ {print $4}')
RAM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
SWAP_USED=$( free -h | awk '/^Swap:/ {print $3}')

# Memory usage bar
RAM_PCT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
BAR_W=30
FILLED=$(( RAM_PCT * BAR_W / 100 ))
EMPTY=$(( BAR_W - FILLED ))

echo -en "  ${DM}RAM Usage${NC}             ${G1}▶${NC} ${G0}["
for ((i=0; i<FILLED; i++)); do
    (( i > BAR_W*2/3 )) && echo -en "${YW}█" || echo -en "${G1}█"
done
printf "%${EMPTY}s" | tr ' ' '░'
echo -e "${G0}]${NC} ${WH}${RAM_PCT}%%${NC}"

print_field "Total RAM"   "$RAM_TOTAL"
print_field "Used"        "$RAM_USED"
print_field "Free"        "$RAM_FREE"
print_field "Available"   "$RAM_AVAIL"
print_field "Swap Total"  "$SWAP_TOTAL"
print_field "Swap Used"   "$SWAP_USED"
print_ok "Memory information collected"

# ============================================================================
# 5. STORAGE
# ============================================================================

section "DISK & PARTITIONS"

echo -e "  ${DM}$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | head -1)${NC}"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -v "loop" | tail -n +2 | while read line; do
    echo -e "  ${G0}${line}${NC}"
done

echo ""
echo -e "  ${DM}Filesystem Usage:${NC}"
df -h | grep -v tmpfs | grep -v udev | grep -v loop | tail -n +2 | while read line; do
    USE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    if (( USE > 80 )); then
        echo -e "  ${YW}${line}${NC}"
    else
        echo -e "  ${G0}${line}${NC}"
    fi
done
print_ok "Storage information collected"

# ============================================================================
# 6. NETWORK
# ============================================================================

section "NETWORK INTERFACES"

for intf in $(ls /sys/class/net | grep -v lo); do
    IP=$(ip addr show "$intf" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    MAC=$(cat /sys/class/net/"$intf"/address 2>/dev/null)
    STATE=$(cat /sys/class/net/"$intf"/operstate 2>/dev/null)
    if [ "$STATE" = "up" ]; then
        STATE_STR="${G1}UP${NC}"
    else
        STATE_STR="${DM}DOWN${NC}"
    fi
    echo -e "  ${G1}▶${NC} ${WH}${intf}${NC}"
    print_field "  IP Address"  "${IP:-"No IP assigned"}"
    print_field "  MAC Address" "$MAC"
    print_field "  State"       "$(echo -e $STATE_STR)"
done
print_ok "Network interfaces collected"

# ============================================================================
# 7. USB DEVICES
# ============================================================================

section "USB DEVICES"

lsusb | cut -d: -f3- | sed 's/^ //g' | while read -r dev; do
    echo -e "  ${G0}▸${NC} ${WH}${dev}${NC}"
done
print_ok "USB devices enumerated"

# ============================================================================
# SAVE TO JSON
# ============================================================================

echo ""
echo -e "${DM}"
repeat_char '─' $TW
echo -e "${NC}"
echo ""

if (( GUI_MODE == 1 )); then
    confirm="y"
    echo -e "  ${G1}[AUTO]${NC}  GUI mode — saving JSON automatically..."
else
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Save results to JSON? ${DM}[y/n]${NC}: "
    read -r confirm
fi

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE_NAME="$REPORT_DIR/hardware_report_full_${TIMESTAMP}.json"

    progress "Writing JSON report    " 0.8

    cat <<EOF > "$FILE_NAME"
{
  "timestamp": "$(date)",
  "report_type": "hardware_audit",
  "system": {
    "motherboard": "$MB_NAME",
    "manufacturer": "$MB_VENDOR",
    "bios_version": "$BIOS_VER",
    "bios_date": "$BIOS_DATE",
    "firmware_type": "$FIRMWARE"
  },
  "cpu": {
    "model": "$CPU_MODEL",
    "architecture": "$CPU_ARCH",
    "cores": "$CPU_CORES",
    "speed_mhz": "$CPU_SPEED",
    "l3_cache": "$CPU_CACHE",
    "virtualization": "$CPU_VIRT"
  },
  "gpu": {
    "device": "$GPU_INFO"
  },
  "memory": {
    "total": "$RAM_TOTAL",
    "used": "$RAM_USED",
    "free": "$RAM_FREE",
    "available": "$RAM_AVAIL",
    "usage_percent": "$RAM_PCT",
    "swap_total": "$SWAP_TOTAL",
    "swap_used": "$SWAP_USED"
  },
  "network": {
    "hostname": "$(hostname)",
    "interfaces": "$(ls /sys/class/net | grep -v lo | tr '\n' ',')"
  }
}
EOF
    echo ""
    print_ok "Report saved ${G1}→${NC} ${WH}$FILE_NAME${NC}"
else
    echo ""
    print_info "Report discarded — no file saved."
fi

echo ""
echo -e "${DM}"
divider '═'
echo -e "${NC}"
center_print "${G0}Hardware Audit Complete  |  $(date '+%H:%M:%S')${NC}"
echo -e "${DM}"
divider '▄'
echo -e "${NC}"
echo ""