#!/bin/bash
################################################################################
# NSCS OS Project - Remote Monitoring Module (HACKER EDITION)
# Phase 5 — Secure SSH-Based Remote Monitoring & Report Centralization
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT THIS SCRIPT DOES (Big Picture)                                    │
# │                                                                         │
# │  This script turns YOUR machine into a "controller" — a central hub    │
# │  that can reach out to multiple remote Linux machines over the          │
# │  network, collect their system data securely, and build one unified     │
# │  report. No agents, no software needed on the remote side — just SSH.  │
# │                                                                         │
# │  Controller (your Kali)  ──SSH──►  Remote Host 1 (collect metrics)     │
# │                           ──SSH──►  Remote Host 2 (collect metrics)     │
# │                           ──SSH──►  Remote Host 3 (collect metrics)     │
# │                           ◄──SCP──  Pull JSON reports back              │
# │                           ──────►   Save centralized summary            │
# └─────────────────────────────────────────────────────────────────────────┘
#
# FEATURES IMPLEMENTED (all 4 professor requirements):
#   [1] SSH key-based authentication  → secure access, no passwords
#   [2] Real-time periodic monitoring → live CPU/RAM/disk via SSH
#   [3] Send reports to remote server → push/pull reports via SCP
#   [4] Centralize reports from multiple machines → one summary file
#
# Author: NSCS OS Project | Date: 2026
################################################################################

# ============================================================================
# HOW SSH WORKS (important concept)
# ============================================================================
#
# SSH (Secure Shell) = encrypted tunnel between two machines.
# Normally you type: ssh user@192.168.1.10
# And it asks for a password. That's INSECURE for automation because:
#   - Password travels over network (even if encrypted)
#   - Can't automate — script can't "type" a password
#
# BETTER WAY: SSH Key Pairs
#   - You generate TWO files: a PRIVATE key (secret, stays on your machine)
#     and a PUBLIC key (like a lock — you put this on remote machines)
#   - When you SSH, your machine proves it has the private key without
#     ever sending it — pure cryptography, zero password transmission
#   - This is how real sysadmins and DevOps engineers do it
#
# COMMAND: ssh-keygen -t rsa -b 4096
#   -t rsa   = RSA algorithm (industry standard)
#   -b 4096  = 4096 bits = very strong key
#
# COMMAND: ssh-copy-id -i key.pub user@host
#   Copies your public key to the remote machine's authorized_keys file
#   After this, SSH never asks for a password again
#
# ============================================================================

# ============================================================================
# COLORS & STYLES
# ============================================================================

G0='\033[0;32m'    # dim green
G1='\033[1;32m'    # bright green
G2='\033[0;92m'    # light green
CY='\033[0;36m'    # cyan
YW='\033[1;33m'    # yellow (warnings)
RD='\033[1;31m'    # red (errors)
WH='\033[1;37m'    # white
DM='\033[2;32m'    # very dim green
NC='\033[0m'       # reset all colors
BOLD='\033[1m'

# ============================================================================
# PATHS & CONFIGURATION
# ============================================================================

# Base project directory
BASE_DIR="$HOME/nscs_os_project"

# Where local reports live (from phases 1 & 2)
REPORT_DIR="$BASE_DIR/reports"

# Where REMOTE reports get centralized (pulled from other machines)
REMOTE_DIR="$BASE_DIR/remote_reports"

# Log file — every SSH action gets timestamped here
LOG_FILE="$BASE_DIR/remote_monitor.log"

# Hosts config — list of machines to monitor
# Format per line:  IP_ADDRESS   SSH_USER   FRIENDLY_LABEL
HOSTS_FILE="$BASE_DIR/hosts.conf"

# SSH private key dedicated to this monitoring tool
# (separate from your personal SSH key — good security practice)
SSH_KEY="$HOME/.ssh/nscs_monitor_rsa"

# Create directories if they don't exist
mkdir -p "$REPORT_DIR" "$REMOTE_DIR"

# Terminal width for formatting
TW=$(tput cols 2>/dev/null || echo 80)

# GUI mode flag (passed as --gui from the Python GUI)
GUI_MODE=0
for arg in "$@"; do [[ "$arg" == "--gui" ]] && GUI_MODE=1; done

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

_print_ascii_art() {
    center_print "██████╗ ███████╗███╗   ███╗ ██████╗ ████████╗███████╗"
    center_print "██╔══██╗██╔════╝████╗ ████║██╔═══██╗╚══██╔══╝██╔════╝"
    center_print "██████╔╝█████╗  ██╔████╔██║██║   ██║   ██║   █████╗  "
    center_print "██╔══██╗██╔══╝  ██║╚██╔╝██║██║   ██║   ██║   ██╔══╝  "
    center_print "██║  ██║███████╗██║ ╚═╝ ██║╚██████╔╝   ██║   ███████╗"
    center_print "╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚══════╝"
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
print_banner "REMOTE" "Remote SSH Monitoring & Centralization  |  Phase 5"
type_header ">>> INITIALIZING REMOTE MONITORING ENGINE..."
progress "Loading SSH subsystem     " 0.8
progress "Scanning host config      " 0.6
echo ""

section "FEATURE 1 — SSH KEY AUTHENTICATION"

echo -e "  ${DM}Security concept: RSA 4096-bit key pair — zero password transmission${NC}"
echo ""

if [ -f "$SSH_KEY" ] && [ -f "$SSH_KEY.pub" ]; then
    # Key already exists — show its details
    FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY.pub" 2>/dev/null | awk '{print $2}')
    KEY_COMMENT=$(ssh-keygen -lf "$SSH_KEY.pub" 2>/dev/null | awk '{print $NF}')
    print_ok "SSH monitoring key found"
    print_field "Private key"   "$SSH_KEY"
    print_field "Public key"    "$SSH_KEY.pub"
    print_field "Fingerprint"   "$FINGERPRINT"
    print_field "Comment"       "$KEY_COMMENT"
    print_field "Algorithm"     "RSA 4096-bit"
    print_field "Auth method"   "Public key cryptography (no password)"
    log "SSH key exists: $FINGERPRINT"
else
    # No key yet — generate one now
    print_warn "No monitoring key found — generating RSA 4096-bit key pair..."
    echo ""

    ssh-keygen \
        -t rsa \
        -b 4096 \
        -f "$SSH_KEY" \
        -C "nscs_monitor@$(hostname)" \
        -N "" \
        -q 2>/dev/null

    if [ $? -eq 0 ]; then
        FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY.pub" 2>/dev/null | awk '{print $2}')
        print_ok "Key pair generated successfully"
        print_field "Private key"  "$SSH_KEY"
        print_field "Public key"   "$SSH_KEY.pub"
        print_field "Fingerprint"  "$FINGERPRINT"
        log "New SSH key generated: $FINGERPRINT"
    else
        print_warn "Key generation failed — check ssh-keygen is installed"
        log "SSH key generation failed"
    fi
fi

echo ""
# Show the professor exactly HOW to use this key on a real machine
echo -e "  ${YW}To authorize monitoring on a remote machine:${NC}"
echo -e "  ${G1}    ssh-copy-id -i $SSH_KEY.pub USER@REMOTE_IP${NC}"
echo -e "  ${DM}  (only needs to be done once per remote machine)${NC}"

# ============================================================================
# LOAD HOSTS CONFIG
# ============================================================================
#
# CONCEPT: hosts.conf
#
#   Instead of hardcoding IPs in the script (bad practice),
#   we read them from a config file. This means:
#   - Easy to add/remove machines without editing code
#   - Reusable across different network environments
#   - Standard practice in real sysadmin tools (like Ansible's inventory)
#
#   Format of each line:
#     192.168.1.10   kali    Lab-Machine-1
#     [IP]           [user]  [friendly name]
#
# ============================================================================

section "HOST CONFIGURATION"

if [ ! -f "$HOSTS_FILE" ]; then
    # First run — create a template config file
    cat <<EOF > "$HOSTS_FILE"
# NSCS Remote Hosts Configuration
# ─────────────────────────────────────────────────────────────────
# Format:  IP_ADDRESS    SSH_USERNAME    FRIENDLY_LABEL
# ─────────────────────────────────────────────────────────────────
# Example (uncomment and edit):
# 192.168.1.10   kali     Lab-Machine-1
# 192.168.1.11   ubuntu   Lab-Machine-2
# 192.168.1.12   kali     Server-Prod
#
# How to add a machine:
#   1. Make sure it's reachable: ping <IP>
#   2. Copy SSH key: ssh-copy-id -i $SSH_KEY.pub USER@IP
#   3. Uncomment or add the line below, save, re-run this module
# ─────────────────────────────────────────────────────────────────
EOF
    print_warn "No hosts.conf found — template created at:"
    print_field "Config file" "$HOSTS_FILE"
    echo ""
    print_info "Edit hosts.conf to add real machines, then re-run."
    print_info "Running in DEMO mode for now..."
    DEMO_MODE=1
else
    # Read only non-comment, non-empty lines
    mapfile -t HOST_LINES < <(grep -v '^\s*#' "$HOSTS_FILE" | grep -v '^\s*$')

    if [ ${#HOST_LINES[@]} -eq 0 ]; then
        print_warn "hosts.conf exists but has no active hosts — DEMO mode"
        DEMO_MODE=1
    else
        DEMO_MODE=0
        print_ok "${#HOST_LINES[@]} host(s) loaded from config"
        echo ""
        for line in "${HOST_LINES[@]}"; do
            IP=$(   echo "$line" | awk '{print $1}')
            USER=$( echo "$line" | awk '{print $2}')
            LABEL=$(echo "$line" | awk '{print $3}')
            print_field "${LABEL:-$IP}" "$USER@$IP"
        done
    fi
fi

# ============================================================================
# DEMO MODE — runs when no real hosts are configured
# ============================================================================
#
# CONCEPT: Demo/simulation mode
#
#   This is a critical feature for any professional tool:
#   the script should NEVER crash with "no data found" —
#   it should gracefully show what it WOULD do with real data.
#   During your demo/presentation, this looks just as impressive.
#
# ============================================================================

if (( DEMO_MODE == 1 )); then

    section "DEMO MODE — SIMULATED REMOTE HOSTS"
    print_warn "No real hosts configured — running with simulated data"
    print_info "This shows exactly what happens with real machines"
    echo ""

    # Simulated host list (same format as hosts.conf)
    DEMO_HOSTS=(
        "192.168.1.10 kali   Lab-Machine-1"
        "192.168.1.11 ubuntu Lab-Machine-2"
        "192.168.1.12 kali   Server-Prod"
    )

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    # ── Feature 1 demo ──────────────────────────────────────────────────────
    echo -e "  ${G0}[DEMO] SSH key authentication would be used for all connections${NC}"
    echo -e "  ${DM}  Private key: $SSH_KEY${NC}"
    echo -e "  ${DM}  Command:     ssh -i $SSH_KEY user@host 'command'${NC}"
    echo ""

    # ── Feature 2 demo — live metrics table ─────────────────────────────────
    section "FEATURE 2 — LIVE METRICS (DEMO)"
    print_info "In real mode: SSH connects, runs top/free/df remotely, returns data"
    echo ""

    echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"
    printf "  ${DM}%-18s %-16s %-8s %-8s %-8s %-10s %-16s${NC}\n" \
        "HOST" "IP" "CPU%" "RAM%" "DISK%" "STATUS" "UPTIME"
    echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"

    JSON_HOSTS=""
    ALL_RESULTS=()

    for entry in "${DEMO_HOSTS[@]}"; do
        IP=$(   echo "$entry" | awk '{print $1}')
        USER=$( echo "$entry" | awk '{print $2}')
        LABEL=$(echo "$entry" | awk '{print $3}')

        # Simulate SSH delay (real SSH takes ~0.1-0.5s)
        sleep 0.25

        # Generate realistic-looking random metrics
        CPU=$(( RANDOM % 55 + 5 ))
        RAM=$(( RANDOM % 65 + 20 ))
        DISK=$(( RANDOM % 45 + 15 ))
        UPTIMEH=$(( RANDOM % 72 + 1 ))
        UPTIMEM=$(( RANDOM % 59 ))
        UPTIME_STR="${UPTIMEH}h ${UPTIMEM}m"

        # Color code by threshold — green=safe, yellow=warning, red=critical
        CPU_C=$G1;  (( CPU  > 70 )) && CPU_C=$YW;  (( CPU  > 90 )) && CPU_C=$RD
        RAM_C=$G1;  (( RAM  > 75 )) && RAM_C=$YW;  (( RAM  > 90 )) && RAM_C=$RD
        DISK_C=$G1; (( DISK > 70 )) && DISK_C=$YW; (( DISK > 90 )) && DISK_C=$RD

        printf "  ${WH}%-18s${NC} ${DM}%-16s${NC} ${CPU_C}%-8s${NC} ${RAM_C}%-8s${NC} ${DISK_C}%-8s${NC} ${G1}%-10s${NC} ${DM}%-16s${NC}\n" \
            "$LABEL" "$IP" "${CPU}%" "${RAM}%" "${DISK}%" "ONLINE" "$UPTIME_STR"

        log "DEMO $LABEL ($IP): CPU=${CPU}% RAM=${RAM}% DISK=${DISK}%"
        ALL_RESULTS+=("$LABEL|$IP|$CPU|$RAM|$DISK|ONLINE|$UPTIME_STR")

        # Per-host JSON report (Feature 3 & 4)
        HOST_FILE="$REMOTE_DIR/host_${LABEL}_${TIMESTAMP}.json"
        cat <<EOF > "$HOST_FILE"
{
  "label": "$LABEL",
  "ip": "$IP",
  "user": "$USER",
  "collected_at": "$(date)",
  "collection_method": "SSH remote command (demo)",
  "status": "ONLINE",
  "metrics": {
    "cpu_percent": $CPU,
    "ram_percent": $RAM,
    "disk_percent": $DISK,
    "uptime": "$UPTIME_STR",
    "kernel": "6.5.0-35-generic",
    "hostname": "$LABEL"
  }
}
EOF
        JSON_HOSTS+="    {\"label\":\"$LABEL\",\"ip\":\"$IP\",\"status\":\"ONLINE\",\"cpu\":$CPU,\"ram\":$RAM,\"disk\":$DISK,\"uptime\":\"$UPTIME_STR\"},"
    done

    echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"

    # ── Feature 3 demo — SCP explanation ────────────────────────────────────
    section "FEATURE 3 — REPORT TRANSFER VIA SCP (DEMO)"
    print_info "SCP = Secure Copy Protocol — file transfer over SSH tunnel"
    echo ""
    echo -e "  ${DM}Real commands that would run:${NC}"
    echo ""
    for entry in "${DEMO_HOSTS[@]}"; do
        IP=$(   echo "$entry" | awk '{print $1}')
        LABEL=$(echo "$entry" | awk '{print $3}')
        echo -e "  ${G0}# Push local report TO remote:${NC}"
        echo -e "  ${G1}  scp -i $SSH_KEY report_full.txt kali@${IP}:/tmp/${NC}"
        echo ""
        echo -e "  ${G0}# Pull remote audit FROM remote:${NC}"
        echo -e "  ${G1}  scp -i $SSH_KEY kali@${IP}:~/nscs_os_project/reports/*.json $REMOTE_DIR/${NC}"
        echo ""
    done

    # ── Feature 4 — centralized report ──────────────────────────────────────
    section "FEATURE 4 — CENTRALIZED SUMMARY (DEMO)"
    progress "Building centralized report" 1.0

    SUMMARY_TXT="$REMOTE_DIR/remote_summary_${TIMESTAMP}.txt"
    SUMMARY_JSON="$REMOTE_DIR/remote_summary_${TIMESTAMP}.json"

    # Build the centralized TXT report
    {
        SEP="╔══════════════════════════════════════════════════════════════╗"
        MID="╠══════════════════════════════════════════════════════════════╣"
        END="╚══════════════════════════════════════════════════════════════╝"
        echo "$SEP"
        echo "║    NSCS REMOTE MONITORING — CENTRALIZED SUMMARY REPORT      ║"
        echo "$MID"
        printf "║  %-20s %-41s║\n" "Controller:"  "$(hostname)"
        printf "║  %-20s %-41s║\n" "Generated:"   "$(date)"
        printf "║  %-20s %-41s║\n" "Mode:"        "Demo (simulated hosts)"
        printf "║  %-20s %-41s║\n" "Hosts monitored:" "${#DEMO_HOSTS[@]}"
        echo "$END"
        echo ""
        echo "  SECTION 1 — LIVE METRICS SNAPSHOT"
        echo "  ──────────────────────────────────────────────────────────────"
        printf "  %-18s %-16s %-8s %-8s %-8s %-10s\n" \
            "HOST" "IP" "CPU%" "RAM%" "DISK%" "STATUS"
        echo "  ──────────────────────────────────────────────────────────────"
        for r in "${ALL_RESULTS[@]}"; do
            IFS='|' read -r LBL IPA CPUV RAMV DISKV STAT UTIME <<< "$r"
            printf "  %-18s %-16s %-8s %-8s %-8s %-10s\n" \
                "$LBL" "$IPA" "${CPUV}%" "${RAMV}%" "${DISKV}%" "$STAT"
        done
        echo ""
        echo "  SECTION 2 — SECURITY NOTES"
        echo "  ──────────────────────────────────────────────────────────────"
        echo "  Authentication:   RSA 4096-bit key pair (no passwords)"
        echo "  Transport:        SSH + SCP (AES-256 encrypted tunnel)"
        echo "  Host verification:StrictHostKeyChecking=accept-new"
        echo "  Timeout:          5 seconds per host (prevents hanging)"
        echo "  Privilege:        Runs as existing user — no root required"
        echo ""
        echo "  SECTION 3 — INDIVIDUAL REPORTS"
        echo "  ──────────────────────────────────────────────────────────────"
        for entry in "${DEMO_HOSTS[@]}"; do
            LABEL=$(echo "$entry" | awk '{print $3}')
            echo "  $LABEL → host_${LABEL}_${TIMESTAMP}.json"
        done
        echo ""
        echo "$SEP"
        echo "║    NSCS OS Project © 2026 — Remote Monitoring Report         ║"
        echo "$END"
    } > "$SUMMARY_TXT"

    # Build the centralized JSON report
    JSON_HOSTS="${JSON_HOSTS%,}"
    cat <<EOF > "$SUMMARY_JSON"
{
  "report_type": "remote_monitoring_centralized",
  "generated": "$(date)",
  "controller_host": "$(hostname)",
  "controller_user": "$(whoami)",
  "mode": "demo",
  "security": {
    "auth_method": "RSA 4096-bit key pair",
    "transport": "SSH/SCP AES-256",
    "host_checking": "StrictHostKeyChecking=accept-new",
    "timeout_seconds": 5
  },
  "summary": {
    "total_hosts": ${#DEMO_HOSTS[@]},
    "online": ${#DEMO_HOSTS[@]},
    "offline": 0
  },
  "hosts": [
$JSON_HOSTS
  ]
}
EOF

    echo ""
    print_ok "Per-host reports  → $REMOTE_DIR/"
    print_ok "Summary TXT       → $(basename "$SUMMARY_TXT")"
    print_ok "Summary JSON      → $(basename "$SUMMARY_JSON")"
    echo ""

    # Show file listing
    section "CENTRALIZED REPORT FILES"
    echo -e "  ${DM}All reports in: $REMOTE_DIR${NC}"
    echo ""
    ls -lh "$REMOTE_DIR/"*.json "$REMOTE_DIR/"*.txt 2>/dev/null | while read line; do
        echo -e "  ${G0}${line}${NC}"
    done

    # Log completion
    log "Demo session complete — ${#DEMO_HOSTS[@]} hosts simulated"
    log "Summary: $SUMMARY_TXT"
    log "JSON:    $SUMMARY_JSON"

    echo ""
    echo -e "${DM}"; divider '═'; echo -e "${NC}"
    center_print "${G0}Phase 5 Complete (Demo)  |  $(date '+%H:%M:%S')${NC}"
    center_print "${DM}Add real hosts to $HOSTS_FILE to monitor live machines${NC}"
    echo -e "${DM}"; divider '▄'; echo -e "${NC}"
    echo ""
    exit 0
fi

# ============================================================================
# REAL MODE — actual SSH connections
# ============================================================================
#
# SSH OPTIONS EXPLAINED:
#   -i $SSH_KEY                     use our monitoring key (not default key)
#   -o ConnectTimeout=5             give up after 5 seconds (no hanging)
#   -o BatchMode=yes                never ask for password (fail instead)
#   -o StrictHostKeyChecking=accept-new  auto-accept new hosts, reject changed ones
#                                   (security: detects man-in-the-middle attacks)
#   -o LogLevel=ERROR               suppress informational SSH messages
#
# WHY ConnectTimeout matters:
#   Without it, SSH waits ~2 minutes for a dead host.
#   With it, script moves on in 5 seconds — much more practical.
#
# WHY StrictHostKeyChecking=accept-new:
#   First connection: saves the remote host's fingerprint
#   Later connections: verifies fingerprint matches (detects if someone
#   replaced the machine or is intercepting traffic — MITM attack detection)
#
# ============================================================================

SSH_OPTS="-i $SSH_KEY \
    -o ConnectTimeout=5 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o LogLevel=ERROR"

SCP_OPTS="-i $SSH_KEY \
    -o ConnectTimeout=5 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o LogLevel=ERROR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Associative arrays to store results per host
declare -A HOST_STATUS HOST_CPU HOST_RAM HOST_DISK HOST_UPTIME HOST_KERNEL
ALL_RESULTS=()

# ============================================================================
# FEATURE 2 — REAL-TIME MONITORING VIA SSH
# ============================================================================
#
# CONCEPT: Remote command execution over SSH
#
#   ssh user@host 'command'   runs 'command' on the remote machine
#                             and returns the output to YOU
#
#   We collect everything in ONE SSH connection per host (efficient):
#     top -bn1     = run top once (-n1), no interactive (-b), get CPU%
#     free         = RAM statistics
#     df /         = disk usage of root partition
#     uptime -p    = human-readable uptime
#     uname -r     = kernel version
#
#   The output is parsed with grep/awk on our end — the remote machine
#   doesn't need any special software installed.
#
# ============================================================================

section "FEATURE 2 — REAL-TIME MONITORING VIA SSH"

print_info "Connecting to each host, running remote commands, collecting metrics"
echo ""

# Print table header
echo -e "  ${G0}$(repeat_char '─' $(( TW - 4 )))${NC}"
printf "  ${DM}%-18s %-16s %-7s %-7s %-7s %-12s %-14s${NC}\n" \
    "HOST" "IP" "CPU%" "RAM%" "DISK%" "STATUS" "KERNEL"
echo -e "  ${G0}$(repeat_char '─' $(( TW - 4 )))${NC}"

for line in "${HOST_LINES[@]}"; do
    IP=$(   echo "$line" | awk '{print $1}')
    USER=$( echo "$line" | awk '{print $2}')
    LABEL=$(echo "$line" | awk '{print $3}')
    LABEL="${LABEL:-$IP}"

    print_host "Contacting $LABEL ($USER@$IP)..."

    # ── Step 1: Ping check ──────────────────────────────────────────────────
    # ping -c1 = send 1 packet
    # -W1      = wait max 1 second for reply
    # &>/dev/null = suppress all output (we only care about exit code)
    #
    # WHY ping first?
    #   SSH takes 5 seconds to timeout. Ping takes 1 second.
    #   Checking ping first saves 4 seconds per dead host.
    if ! ping -c1 -W1 "$IP" &>/dev/null; then
        printf "  ${WH}%-18s${NC} ${DM}%-16s${NC} ${DM}%-7s%-7s%-7s${NC} ${RD}%-12s${NC}\n" \
            "$LABEL" "$IP" "—" "—" "—" "UNREACHABLE"
        HOST_STATUS[$LABEL]="OFFLINE"
        ALL_RESULTS+=("$LABEL|$IP|0|0|0|OFFLINE|—|—")
        log "HOST $LABEL ($IP): UNREACHABLE (ping failed)"
        continue
    fi

    # ── Step 2: SSH — collect all metrics in ONE connection ─────────────────
    #
    # WHY one connection?
    #   Each SSH connection = crypto handshake = ~0.1-0.5 seconds overhead.
    #   If we opened 5 separate connections for 5 metrics, that's ~2.5s wasted.
    #   One connection, one compound command = much faster.
    #
    # The remote command explained:
    #   top -bn1 → shows CPU usage once; grep/awk extracts the idle% → 100-idle = usage%
    #   free     → shows RAM; awk calculates used/total * 100
    #   df /     → shows disk; awk grabs the use% column
    #   uptime -p → "up 2 days, 3 hours" format
    #   uname -r → kernel version string
    #   hostname → remote machine's hostname
    #
    REMOTE_DATA=$(ssh $SSH_OPTS "$USER@$IP" bash <<'REMOTE_CMD'
        # CPU: get idle percentage from top, subtract from 100
        CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | \
              awk '{for(i=1;i<=NF;i++) if($i~/id,/) {gsub(/[^0-9.]/,"",$i); print 100-$i}}' | \
              cut -d. -f1)
        [ -z "$CPU" ] && CPU=0

        # RAM: used / total * 100
        RAM=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
        [ -z "$RAM" ] && RAM=0

        # DISK: use% of root partition
        DISK=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
        [ -z "$DISK" ] && DISK=0

        # Uptime, kernel, hostname
        UPTIME=$(uptime -p 2>/dev/null || echo "unknown")
        KERNEL=$(uname -r 2>/dev/null || echo "unknown")
        RHOST=$(hostname 2>/dev/null || echo "unknown")

        echo "CPU=$CPU|RAM=$RAM|DISK=$DISK|UPTIME=$UPTIME|KERNEL=$KERNEL|RHOST=$RHOST"
REMOTE_CMD
    2>/dev/null)

    # ── Step 3: Check if SSH worked ─────────────────────────────────────────
    if [ -z "$REMOTE_DATA" ]; then
        printf "  ${WH}%-18s${NC} ${DM}%-16s${NC} ${DM}%-7s%-7s%-7s${NC} ${YW}%-12s${NC}\n" \
            "$LABEL" "$IP" "—" "—" "—" "SSH FAILED"
        HOST_STATUS[$LABEL]="SSH_FAILED"
        ALL_RESULTS+=("$LABEL|$IP|0|0|0|SSH_FAILED|—|—")
        log "HOST $LABEL ($IP): SSH failed (key not installed?)"
        echo -e "  ${DM}  Hint: run 'ssh-copy-id -i $SSH_KEY.pub $USER@$IP' first${NC}"
        continue
    fi

    # ── Step 4: Parse the returned data ─────────────────────────────────────
    # The data comes back as: CPU=23|RAM=54|DISK=41|UPTIME=up 3 hours|...
    # We split on | and extract each field with grep -oP (Perl regex)
    CPU=$(   echo "$REMOTE_DATA" | grep -oP 'CPU=\K[0-9]+')
    RAM=$(   echo "$REMOTE_DATA" | grep -oP 'RAM=\K[0-9]+')
    DISK=$(  echo "$REMOTE_DATA" | grep -oP 'DISK=\K[0-9]+')
    UPTIME=$(echo "$REMOTE_DATA" | grep -oP 'UPTIME=\K[^|]+')
    KERNEL=$(echo "$REMOTE_DATA" | grep -oP 'KERNEL=\K[^|]+')
    RHOST=$( echo "$REMOTE_DATA" | grep -oP 'RHOST=\K[^|]+')

    # Default to 0 if parsing failed
    CPU=${CPU:-0}; RAM=${RAM:-0}; DISK=${DISK:-0}

    # Store in associative arrays for use in report generation
    HOST_STATUS[$LABEL]="ONLINE"
    HOST_CPU[$LABEL]=$CPU
    HOST_RAM[$LABEL]=$RAM
    HOST_DISK[$LABEL]=$DISK
    HOST_UPTIME[$LABEL]="$UPTIME"
    HOST_KERNEL[$LABEL]="$KERNEL"
    ALL_RESULTS+=("$LABEL|$IP|$CPU|$RAM|$DISK|ONLINE|$UPTIME|$KERNEL")

    # Color thresholds: >70% = yellow warning, >90% = red critical
    CPU_C=$G1;  (( CPU  > 70 )) && CPU_C=$YW;  (( CPU  > 90 )) && CPU_C=$RD
    RAM_C=$G1;  (( RAM  > 75 )) && RAM_C=$YW;  (( RAM  > 90 )) && RAM_C=$RD
    DISK_C=$G1; (( DISK > 70 )) && DISK_C=$YW; (( DISK > 90 )) && DISK_C=$RD

    printf "  ${WH}%-18s${NC} ${DM}%-16s${NC} ${CPU_C}%-7s${NC} ${RAM_C}%-7s${NC} ${DISK_C}%-7s${NC} ${G1}%-12s${NC} ${DM}%-14s${NC}\n" \
        "$LABEL" "$IP" "${CPU}%" "${RAM}%" "${DISK}%" "ONLINE" "$KERNEL"

    log "HOST $LABEL ($IP): ONLINE CPU=${CPU}% RAM=${RAM}% DISK=${DISK}% KERNEL=$KERNEL"
done

echo -e "  ${G0}$(repeat_char '─' $(( TW - 4 )))${NC}"

# ============================================================================
# FEATURE 3 — PUSH/PULL REPORTS VIA SCP
# ============================================================================
#
# CONCEPT: SCP (Secure Copy Protocol)
#
#   SCP uses the SSH connection to transfer files — same encryption,
#   same key authentication, but for files instead of commands.
#
#   Push (local → remote):
#     scp local_file.txt user@host:/remote/path/
#     "Take this file from MY machine and PUT it on the remote"
#     Use case: deploy your audit report to a central server
#
#   Pull (remote → local):
#     scp user@host:/remote/file.txt ./local/path/
#     "Grab that file from the remote machine and bring it HERE"
#     Use case: collect each machine's audit output to your controller
#
#   This is how "centralizing reports from multiple machines" works:
#   each machine runs its own audit, saves a JSON — you SCP them all
#   back to your controller and merge them into one report.
#
# ============================================================================

section "FEATURE 3 — REPORT TRANSFER VIA SCP"

print_info "Pushing local reports TO remote hosts"
print_info "Pulling audit reports FROM remote hosts"
echo ""

# Find our latest full report to push
LATEST_REPORT=$(ls -t "$REPORT_DIR"/report_full_*.txt 2>/dev/null | head -1)

for line in "${HOST_LINES[@]}"; do
    IP=$(   echo "$line" | awk '{print $1}')
    USER=$( echo "$line" | awk '{print $2}')
    LABEL=$(echo "$line" | awk '{print $3}')
    LABEL="${LABEL:-$IP}"

    # Skip offline hosts
    [[ "${HOST_STATUS[$LABEL]}" != "ONLINE" ]] && continue

    echo -e "  ${CY}▶${NC} ${WH}$LABEL${NC} ${DM}($IP)${NC}"

    # ── Push: send our report TO the remote machine ──────────────────────────
    if [ -n "$LATEST_REPORT" ]; then
        scp $SCP_OPTS "$LATEST_REPORT" \
            "$USER@$IP:/tmp/nscs_from_$(hostname)_$(date +%Y%m%d).txt" \
            2>/dev/null
        if [ $? -eq 0 ]; then
            print_ok "  Pushed → $IP:/tmp/"
            log "SCP push to $LABEL ($IP): OK"
        else
            print_warn "  Push failed for $LABEL (SCP error)"
            log "SCP push to $LABEL ($IP): FAILED"
        fi
    fi

    # ── Pull: get remote audit reports FROM the remote machine ───────────────
    # Check if remote machine has audit reports
    REMOTE_HW=$(ssh $SSH_OPTS "$USER@$IP" \
        "ls -t ~/nscs_os_project/reports/hardware_report_full_*.json 2>/dev/null | head -1" \
        2>/dev/null)
    REMOTE_SW=$(ssh $SSH_OPTS "$USER@$IP" \
        "ls -t ~/nscs_os_project/reports/software_report_*.json 2>/dev/null | head -1" \
        2>/dev/null)

    for remote_file in "$REMOTE_HW" "$REMOTE_SW"; do
        [ -z "$remote_file" ] && continue
        fname=$(basename "$remote_file" .json)
        LOCAL_DEST="$REMOTE_DIR/${LABEL}_${fname}.json"
        scp $SCP_OPTS "$USER@$IP:$remote_file" "$LOCAL_DEST" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_ok "  Pulled ← $(basename "$remote_file")"
            log "SCP pull from $LABEL ($IP): $remote_file → $LOCAL_DEST"
        fi
    done
done

# ============================================================================
# FEATURE 4 — CENTRALIZED SUMMARY REPORT
# ============================================================================
#
# CONCEPT: Centralization
#
#   "Centralizing reports from multiple machines" means:
#   instead of logging into each machine one by one to check its status,
#   you have ONE place (your controller) that aggregates everything.
#
#   Real-world equivalent: this is exactly what tools like
#   Nagios, Zabbix, Grafana, and Ansible do — just much simpler.
#
#   Our centralized report contains:
#   - A summary table of ALL hosts (online/offline, CPU/RAM/disk)
#   - Per-host JSON reports (one file per machine)
#   - A combined JSON with all hosts in one structure
#   - A TXT report formatted for printing/emailing
#
# ============================================================================

section "FEATURE 4 — CENTRALIZED SUMMARY REPORT"

progress "Aggregating all host data  " 1.2

SUMMARY_TXT="$REMOTE_DIR/remote_summary_${TIMESTAMP}.txt"
SUMMARY_JSON="$REMOTE_DIR/remote_summary_${TIMESTAMP}.json"

# Count online/offline
ONLINE_COUNT=0; OFFLINE_COUNT=0
for line in "${HOST_LINES[@]}"; do
    LABEL=$(echo "$line" | awk '{print $3}')
    LABEL="${LABEL:-$(echo "$line" | awk '{print $1}')}"
    [[ "${HOST_STATUS[$LABEL]}" == "ONLINE" ]] && (( ONLINE_COUNT++ )) || (( OFFLINE_COUNT++ ))
done

# Build TXT centralized report
{
    SEP="╔══════════════════════════════════════════════════════════════╗"
    MID="╠══════════════════════════════════════════════════════════════╣"
    END="╚══════════════════════════════════════════════════════════════╝"
    echo "$SEP"
    echo "║    NSCS REMOTE MONITORING — CENTRALIZED SUMMARY REPORT      ║"
    echo "$MID"
    printf "║  %-20s %-41s║\n" "Controller:"       "$(hostname)"
    printf "║  %-20s %-41s║\n" "Generated:"        "$(date)"
    printf "║  %-20s %-41s║\n" "Total hosts:"      "${#HOST_LINES[@]}"
    printf "║  %-20s %-41s║\n" "Online:"           "$ONLINE_COUNT"
    printf "║  %-20s %-41s║\n" "Offline:"          "$OFFLINE_COUNT"
    echo "$END"
    echo ""
    echo "  SECTION 1 — LIVE METRICS SNAPSHOT"
    echo "  ──────────────────────────────────────────────────────────────"
    printf "  %-18s %-16s %-7s %-7s %-7s %-12s\n" \
        "HOST" "IP" "CPU%" "RAM%" "DISK%" "STATUS"
    echo "  ──────────────────────────────────────────────────────────────"
    for r in "${ALL_RESULTS[@]}"; do
        IFS='|' read -r LBL IPA CPUV RAMV DISKV STAT UTIME KERN <<< "$r"
        printf "  %-18s %-16s %-7s %-7s %-7s %-12s\n" \
            "$LBL" "$IPA" "${CPUV}%" "${RAMV}%" "${DISKV}%" "$STAT"
    done
    echo ""
    echo "  SECTION 2 — SECURITY PRACTICES APPLIED"
    echo "  ──────────────────────────────────────────────────────────────"
    printf "  %-28s %s\n" "Authentication:"        "RSA 4096-bit key (no passwords)"
    printf "  %-28s %s\n" "Transport encryption:"  "AES-256 via SSH/SCP"
    printf "  %-28s %s\n" "Host verification:"     "StrictHostKeyChecking=accept-new"
    printf "  %-28s %s\n" "Connection timeout:"    "5 seconds per host"
    printf "  %-28s %s\n" "Key location:"          "$SSH_KEY"
    echo ""
    echo "  SECTION 3 — PULLED REMOTE REPORTS"
    echo "  ──────────────────────────────────────────────────────────────"
    ls "$REMOTE_DIR"/*.json 2>/dev/null | while read f; do
        printf "  %-50s %s\n" "$(basename "$f")" "$(du -h "$f" | awk '{print $1}')"
    done
    echo ""
    echo "$SEP"
    echo "║    NSCS OS Project © 2026 — Remote Monitoring Report         ║"
    echo "$END"
} > "$SUMMARY_TXT"

# Build JSON centralized report
JSON_HOSTS=""
for r in "${ALL_RESULTS[@]}"; do
    IFS='|' read -r LBL IPA CPUV RAMV DISKV STAT UTIME KERN <<< "$r"
    JSON_HOSTS+="    {
      \"label\": \"$LBL\",
      \"ip\": \"$IPA\",
      \"status\": \"$STAT\",
      \"metrics\": {
        \"cpu_percent\": $CPUV,
        \"ram_percent\": $RAMV,
        \"disk_percent\": $DISKV,
        \"uptime\": \"$UTIME\",
        \"kernel\": \"$KERN\"
      }
    },"
done
JSON_HOSTS="${JSON_HOSTS%,}"

cat <<EOF > "$SUMMARY_JSON"
{
  "report_type": "remote_monitoring_centralized",
  "generated": "$(date)",
  "controller": "$(hostname)",
  "security": {
    "auth_method": "RSA 4096-bit key pair",
    "transport": "SSH/SCP AES-256",
    "host_checking": "StrictHostKeyChecking=accept-new",
    "timeout_seconds": 5
  },
  "summary": {
    "total_hosts": ${#HOST_LINES[@]},
    "online": $ONLINE_COUNT,
    "offline": $OFFLINE_COUNT
  },
  "hosts": [
$JSON_HOSTS
  ]
}
EOF

echo ""
print_ok "Per-host reports   → $REMOTE_DIR/"
print_ok "Summary TXT        → $(basename "$SUMMARY_TXT")"
print_ok "Summary JSON       → $(basename "$SUMMARY_JSON")"
log "Centralized reports written: $SUMMARY_TXT / $SUMMARY_JSON"

# ============================================================================
# FINAL SUMMARY TABLE
# ============================================================================

section "SESSION COMPLETE"

ONLINE_C=$G1; (( ONLINE_COUNT == 0 )) && ONLINE_C=$RD
OFFLINE_C=$G0; (( OFFLINE_COUNT > 0 )) && OFFLINE_C=$YW

print_field "Controller"        "$(hostname)"
print_field "Hosts monitored"   "${#HOST_LINES[@]}"
print_field "Online"            "$(echo -e "${ONLINE_C}${ONLINE_COUNT}${NC}")"
print_field "Offline"           "$(echo -e "${OFFLINE_C}${OFFLINE_COUNT}${NC}")"
print_field "Reports saved to"  "$REMOTE_DIR/"
print_field "Log file"          "$LOG_FILE"

echo ""
echo -e "${DM}"; divider '═'; echo -e "${NC}"
center_print "${G0}Phase 5 Complete  |  $(date '+%H:%M:%S')${NC}"
echo -e "${DM}"; divider '▄'; echo -e "${NC}"
echo ""

log "Session complete — Online:$ONLINE_COUNT Offline:$OFFLINE_COUNT"