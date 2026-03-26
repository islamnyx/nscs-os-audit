#!/bin/bash
################################################################################
# NSCS OS Project - Software Audit Module (HACKER EDITION)
# Phase 1 — Advanced OS, Security & Service Audit with Hacker UI
# Author: NSCS OS Project
# Date: 2026
################################################################################

# ============================================================================
# COLORS & EFFECTS
# ============================================================================

G0='\033[0;32m'
G1='\033[1;32m'
G2='\033[0;92m'
CY='\033[0;36m'
YW='\033[1;33m'
RD='\033[1;31m'
WH='\033[1;37m'
DM='\033[2;32m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================================
# PATHS
# ============================================================================

REPORT_DIR="$HOME/nscs-os-audit/reports"
mkdir -p "$REPORT_DIR"

# GUI mode: pass --gui to skip interactive prompts and auto-save JSON
GUI_MODE=0
for arg in "$@"; do [[ "$arg" == "--gui" ]] && GUI_MODE=1; done

TW=$(tput cols 2>/dev/null || echo 80)

# ============================================================================
# UTILITIES
# ============================================================================

_print_ascii_art() {
    center_print "███████╗ ██████╗ ███████╗████████╗██╗    ██╗ █████╗ ██████╗ ███████╗"
    center_print "██╔════╝██╔═══██╗██╔════╝╚══██╔══╝██║    ██║██╔══██╗██╔══██╗██╔════╝"
    center_print "███████╗██║   ██║█████╗     ██║   ██║ █╗ ██║███████║██████╔╝█████╗  "
    center_print "╚════██║██║   ██║██╔══╝     ██║   ██║███╗██║██╔══██║██╔══██╗██╔══╝  "
    center_print "███████║╚██████╔╝██║        ██║   ╚███╔███╔╝██║  ██║██║  ██║███████╗"
    center_print "╚══════╝ ╚═════╝ ╚═╝        ╚═╝    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
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
print_banner "SOFTWARE" "Advanced Software & Security Audit  |  Phase 1  |  v2.0"
type_header ">>> INITIALIZING SOFTWARE SCANNER..."
progress "Enumerating OS metadata    " 0.9
progress "Indexing installed packages" 1.0
progress "Probing security layer     " 0.8
echo ""

section "OPERATING SYSTEM & KERNEL"

OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
OS_ID=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
KERNEL_VER=$(uname -rs)
ARCH=$(uname -m)
HOSTNAME=$(hostname)
UPTIME_VAL=$(uptime -p 2>/dev/null || uptime)
LAST_BOOT=$(who -b 2>/dev/null | awk '{print $3, $4}')

print_field "OS"           "$OS_NAME"
print_field "Distro ID"    "$OS_ID"
print_field "Kernel"       "$KERNEL_VER"
print_field "Architecture" "$ARCH"
print_field "Hostname"     "$HOSTNAME"
print_field "Uptime"       "$UPTIME_VAL"
print_field "Last Boot"    "${LAST_BOOT:-"N/A"}"
print_ok "OS information collected"

# ============================================================================
# 2. USERS & SECURITY
# ============================================================================

section "USER ACCOUNTS & PRIVILEGES"

CURRENT_USER=$(whoami)
LOGGED_IN=$(who 2>/dev/null | awk '{print $1}' | sort -u | xargs)
SUDO_USERS=$(grep '^sudo:' /etc/group 2>/dev/null | cut -d: -f4)
ROOT_LOGIN=$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "N/A")
PASSWD_HASH=$(grep "^root:" /etc/shadow 2>/dev/null | cut -d: -f2 | cut -c1-6 || echo "[no access]")
TOTAL_USERS=$(grep -c "^[^#]" /etc/passwd 2>/dev/null)

print_field "Current User"    "$CURRENT_USER"
print_field "Active Sessions" "${LOGGED_IN:-"None"}"
print_field "Sudo Admins"     "${SUDO_USERS:-"None"}"
print_field "Total Accounts"  "$TOTAL_USERS"
print_field "Root SSH Login"  "$ROOT_LOGIN"
print_field "Root Hash Hint"  "$PASSWD_HASH"

# Warn if root login is enabled
if [ "$ROOT_LOGIN" = "yes" ]; then
    print_warn "Root SSH login is ENABLED — security risk!"
else
    print_ok "User accounts enumerated"
fi

# ============================================================================
# 3. PROCESSES & SERVICES
# ============================================================================

section "PROCESSES & SERVICES"

PROC_COUNT=$(ps aux 2>/dev/null | wc -l)
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
FAILED_SERVICES=$(systemctl list-units --type=service --state=failed  --no-legend 2>/dev/null | wc -l)

print_field "Total Processes"    "$PROC_COUNT"
print_field "Running Services"   "$RUNNING_SERVICES"
if (( FAILED_SERVICES > 0 )); then
    print_warn "Failed Services: $FAILED_SERVICES"
else
    print_field "Failed Services" "0"
fi

echo ""
echo -e "  ${DM}Top 5 CPU consumers:${NC}"
echo -e "  ${G0}%-6s %-6s %-20s${NC}" "CPU%" "MEM%" "COMMAND"
echo -e "  ${DM}$(repeat_char '─' 38)${NC}"
ps -eo %cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -6 | tail -5 | while read cpu mem cmd; do
    if (( ${cpu%.*} > 50 )); then
        echo -e "  ${YW}${cpu}%   ${mem}%   ${cmd}${NC}"
    else
        echo -e "  ${G0}${cpu}%   ${mem}%   ${G1}${cmd}${NC}"
    fi
done
print_ok "Process analysis complete"

# ============================================================================
# 4. OPEN PORTS & NETWORK EXPOSURE
# ============================================================================

section "NETWORK EXPOSURE (OPEN PORTS)"

echo -e "  ${DM}$(printf '%-25s %-15s %-20s' 'LOCAL ADDRESS' 'STATE' 'PROGRAM')${NC}"
echo -e "  ${G0}$(repeat_char '─' 62)${NC}"

sudo ss -tulnp 2>/dev/null | grep LISTEN | while read proto recvq sendq local remote state proc; do
    prog=$(echo "$proc" | grep -oP '"[^"]+"' | tr -d '"' | head -1)
    prog="${prog:-unknown}"
    port=$(echo "$local" | rev | cut -d: -f1 | rev)

    # Color by well-known ports
    if [[ "$port" =~ ^(22|23|21)$ ]]; then
        echo -e "  ${YW}$(printf '%-25s %-15s %-20s' "$local" "LISTEN" "$prog")${NC}"
    elif [[ "$port" =~ ^(80|443|8080|8443)$ ]]; then
        echo -e "  ${CY}$(printf '%-25s %-15s %-20s' "$local" "LISTEN" "$prog")${NC}"
    else
        echo -e "  ${G0}$(printf '%-25s %-15s %-20s' "$local" "LISTEN" "$prog")${NC}"
    fi
done
print_ok "Network port scan complete"

# ============================================================================
# 5. PACKAGE MANAGER
# ============================================================================

section "PACKAGE INVENTORY"

if command -v dpkg &>/dev/null; then
    PKGS=$(dpkg -l 2>/dev/null | wc -l)
    MGR="APT/DPKG (Debian-based)"
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -vc "Listing")
elif command -v rpm &>/dev/null; then
    PKGS=$(rpm -qa 2>/dev/null | wc -l)
    MGR="RPM (Red Hat-based)"
    UPDATES=0
elif command -v pacman &>/dev/null; then
    PKGS=$(pacman -Q 2>/dev/null | wc -l)
    MGR="Pacman (Arch-based)"
    UPDATES=0
else
    PKGS="Unknown"
    MGR="Unknown"
    UPDATES="Unknown"
fi

print_field "Package Manager"   "$MGR"
print_field "Installed Packages" "$PKGS"
if [[ "$UPDATES" =~ ^[0-9]+$ ]] && (( UPDATES > 0 )); then
    print_warn "Pending Updates: $UPDATES available"
else
    print_field "Pending Updates"  "${UPDATES}"
    print_ok "System is up to date"
fi

# ============================================================================
# 6. FIREWALL STATUS
# ============================================================================

section "FIREWALL & SECURITY"

# UFW
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | grep "Status:" | awk '{print $2}')
    print_field "UFW Firewall" "${UFW_STATUS:-"inactive"}"
    if [ "$UFW_STATUS" = "active" ]; then
        print_ok "UFW firewall is active"
    else
        print_warn "UFW firewall is INACTIVE"
    fi
fi

# iptables rule count
if command -v iptables &>/dev/null; then
    IPT_RULES=$(sudo iptables -L 2>/dev/null | grep -c "^[A-Z]" || echo "N/A")
    print_field "iptables chains" "$IPT_RULES"
fi

# SELinux / AppArmor
if command -v getenforce &>/dev/null; then
    print_field "SELinux" "$(getenforce 2>/dev/null)"
elif command -v aa-status &>/dev/null; then
    AA=$(sudo aa-status 2>/dev/null | grep "profiles are" | head -1 | xargs)
    print_field "AppArmor" "${AA:-"present"}"
fi

# Last login
LAST_LOGIN=$(last -n 3 2>/dev/null | head -3 | awk '{print $1,$3,$4,$5,$6}')
echo ""
echo -e "  ${DM}Last login records:${NC}"
echo "$LAST_LOGIN" | while read line; do
    [ -n "$line" ] && echo -e "  ${G0}▸${NC} ${WH}${line}${NC}"
done
print_ok "Security audit complete"

# ============================================================================
# SAVE TO JSON
# ============================================================================

echo ""
echo -e "${DM}"
repeat_char '─' $TW
echo -e "${NC}"
echo ""

if (( GUI_MODE == 1 )); then
    save_choice="y"
    echo -e "  ${G1}[AUTO]${NC}  GUI mode — saving JSON automatically..."
else
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Save audit to JSON? ${DM}[y/n]${NC}: "
    read -r save_choice
fi

if [[ "$save_choice" =~ ^[Yy]$ ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE_NAME="$REPORT_DIR/software_report_${TIMESTAMP}.json"

    progress "Writing JSON report        " 0.8

    cat <<EOF > "$FILE_NAME"
{
  "timestamp": "$(date)",
  "report_type": "software_audit",
  "os_details": {
    "name": "$OS_NAME",
    "kernel": "$KERNEL_VER",
    "arch": "$ARCH",
    "hostname": "$HOSTNAME",
    "uptime": "$UPTIME_VAL",
    "last_boot": "$LAST_BOOT"
  },
  "security": {
    "current_user": "$CURRENT_USER",
    "sudo_users": "$SUDO_USERS",
    "total_accounts": "$TOTAL_USERS",
    "root_ssh_login": "$ROOT_LOGIN",
    "updates_available": "$UPDATES"
  },
  "activity": {
    "processes": "$PROC_COUNT",
    "running_services": "$RUNNING_SERVICES",
    "failed_services": "$FAILED_SERVICES",
    "packages": "$PKGS",
    "package_manager": "$MGR"
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
center_print "${G0}Software Audit Complete  |  $(date '+%H:%M:%S')${NC}"
echo -e "${DM}"
divider '▄'
echo -e "${NC}"
echo ""