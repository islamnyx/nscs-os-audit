#!/bin/bash
# =============================================================================
# FILE        : audit_software.sh
# PROJECT     : NSCS Linux Audit & Monitoring System — 2025/2026
# DESCRIPTION : Collects complete OS and software information for audit.
#               Outputs plain text lines that the GUI parses for color tags.
# AUTHOR      : [Your Name]
# SHELL       : bash (compatible with any Linux shell)
# USAGE       : bash audit_software.sh [--short | --full | --gui]
#               --short  : concise summary report
#               --full   : complete detailed report (default)
#               --gui    : same as --full but no ANSI colors (GUI mode)
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 0 — MODE & COLOR SETUP
#
# The GUI calls this script with --gui and sets NO_COLOR=1 in the environment.
# When in GUI mode, we skip ANSI escape codes entirely — the Python GUI
# applies its own colors by parsing keywords like [OK], [WARN], [ERROR].
# When run in a normal terminal, full color output is used.
# ─────────────────────────────────────────────────────────────────────────────
MODE="${1:---full}"

# Detect GUI mode: either --gui flag or NO_COLOR env variable
if [[ "$MODE" == "--gui" ]] || [[ "${NO_COLOR:-}" == "1" ]]; then
    GUI_MODE=1
    MODE="--full"   # GUI always gets full output
else
    GUI_MODE=0
fi

# Only define colors when NOT in GUI mode
if [[ $GUI_MODE -eq 0 ]]; then
    RED='\e[1;31m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'
    CYAN='\e[1;36m'; BLUE='\e[1;34m'; MAGENTA='\e[1;35m'
    WHITE='\e[1;37m'; RESET='\e[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; MAGENTA=''; WHITE=''; RESET=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — CONFIGURATION
#
# Report directory: where generated report files are saved.
# We use $HOME/nscs_os_project/reports to match what the GUI sets up.
# ─────────────────────────────────────────────────────────────────────────────
REPORT_DIR="$HOME/nscs_os_project/reports"
LOG_DIR="$HOME/nscs_os_project"
LOG_FILE="$LOG_DIR/audit.log"

# Timestamp strings used in filenames and report headers
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
HUMAN_DATE=$(date '+%A, %B %d %Y  %H:%M:%S')
HOSTNAME_VAL=$(hostname)

# Determine short or full
REPORT_TYPE="full"
[[ "$MODE" == "--short" ]] && REPORT_TYPE="short"

# Temp file — we build the report here then copy it to the final location
TEMP_REPORT=$(mktemp /tmp/soft_audit_XXXXXX.tmp)

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# info: print an [OK] status line
# The GUI detects "[ OK ]" or "[OK]" and colors it green automatically
info() { echo -e "${GREEN}[ OK ] $1${RESET}"; }

# warn: print a [WARN] line — GUI colors it yellow
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }

# err: print an [ERROR] line — GUI colors it red
err()  { echo -e "${RED}[ERROR] $1${RESET}"; }

# section: print a section header — GUI detects keywords and adds separators
section() {
    echo ""
    echo -e "${CYAN}>>> $1${RESET}"
    echo "────────────────────────────────────────────────────"
}

# write: append a line to the temp report file (silent, no terminal output)
write() { echo "$1" >> "$TEMP_REPORT"; }

# tee_line: print to terminal AND write to report file simultaneously
tee_line() { echo -e "$1" | tee -a "$TEMP_REPORT"; }

# cmd_safe: run a command; return "N/A" if it fails or doesn't exist
# This prevents the script from crashing if a tool is missing
cmd_safe() { eval "$1" 2>/dev/null || echo "N/A"; }

# check_cmd: verify a command exists before using it
check_cmd() { command -v "$1" &>/dev/null; }

# log: append a timestamped message to the audit log file
log() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SOFTWARE_AUDIT: $1" >> "$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — SETUP DIRECTORIES
# ─────────────────────────────────────────────────────────────────────────────
setup_dirs() {
    mkdir -p "$REPORT_DIR" 2>/dev/null || {
        warn "Cannot create $REPORT_DIR — falling back to /tmp/nscs_reports"
        REPORT_DIR="/tmp/nscs_reports"
        mkdir -p "$REPORT_DIR"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — REPORT FILE HEADER
# Every report starts with an identification block.
# ─────────────────────────────────────────────────────────────────────────────
write_header() {
    write "=============================================================="
    write "   NSCS LINUX AUDIT — SOFTWARE & OS MODULE"
    write "   Report Type  : $(echo $REPORT_TYPE | tr a-z A-Z)"
    write "   Date & Time  : $HUMAN_DATE"
    write "   Hostname     : $HOSTNAME_VAL"
    write "   Generated by : audit_software.sh"
    write "   Project      : NSCS OS Mini-Project 2025/2026"
    write "=============================================================="
    write ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — OPERATING SYSTEM INFORMATION
#
# KEY COMMANDS EXPLAINED:
#   /etc/os-release  : Standard file on all modern Linux distros.
#                      Contains OS name, version, ID in KEY=VALUE format.
#                      grep '^PRETTY_NAME' finds the line starting with that key.
#                      cut -d= -f2 splits on '=' and takes the 2nd part.
#                      tr -d '"' removes quote characters.
#
#   uname -r         : Prints kernel release version (e.g. 6.1.0-kali9-amd64)
#   uname -m         : Machine architecture (x86_64, arm64, etc.)
#   uname -o         : OS type (GNU/Linux)
#   uptime -p        : Human-readable uptime (e.g. "up 3 hours, 5 minutes")
# ─────────────────────────────────────────────────────────────────────────────
collect_os_info() {
    section "OPERATING SYSTEM INFORMATION"
    write "[ OPERATING SYSTEM INFORMATION ]"
    write "──────────────────────────────────────────────────────"

    OS_NAME=$(cmd_safe "grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '\"'")
    OS_VERSION=$(cmd_safe "grep '^VERSION_ID' /etc/os-release | cut -d= -f2 | tr -d '\"'")
    KERNEL=$(cmd_safe "uname -r")
    ARCH=$(cmd_safe "uname -m")
    OS_TYPE=$(cmd_safe "uname -o")
    UPTIME=$(cmd_safe "uptime -p")
    BOOT_TIME=$(cmd_safe "who -b | awk '{print \$3, \$4}'")

    tee_line "  OS Name        : $OS_NAME"
    tee_line "  OS Version     : $OS_VERSION"
    tee_line "  Kernel Version : $KERNEL"
    tee_line "  Architecture   : $ARCH"
    tee_line "  OS Type        : $OS_TYPE"
    tee_line "  System Uptime  : $UPTIME"
    tee_line "  Last Boot      : $BOOT_TIME"

    info "OS information collected."
    log "OS info collected: $OS_NAME | Kernel: $KERNEL"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6 — INSTALLED PACKAGES
#
# KEY COMMANDS EXPLAINED:
#   dpkg -l           : Lists all packages managed by Debian's package manager.
#                       Lines starting with 'ii' = fully installed.
#   grep -c '^ii'     : Count lines starting with 'ii' = count installed pkgs.
#   dpkg-query -W     : Query package info with custom format string.
#   -f='${Package}\t${Version}\n'  : Format: name TAB version NEWLINE.
#   awk '{printf...}' : Format output into aligned columns.
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Knowing exactly what software is installed helps detect:
#   - Unauthorized software (someone installed something they shouldn't)
#   - Outdated packages with known CVEs (vulnerabilities)
#   - Unexpected services that could be backdoors
# ─────────────────────────────────────────────────────────────────────────────
collect_packages() {
    section "INSTALLED PACKAGES"
    write ""
    write "[ INSTALLED PACKAGES ]"
    write "──────────────────────────────────────────────────────"

    if check_cmd "dpkg"; then
        PKG_COUNT=$(dpkg -l 2>/dev/null | grep -c '^ii')
        tee_line "  Package Manager : dpkg (Debian / Kali Linux)"
        tee_line "  Total Installed : $PKG_COUNT packages"
        write ""

        if [[ "$REPORT_TYPE" == "full" ]]; then
            write "  [ Full Package List — Name | Version ]"
            write "  $(printf '%-40s %s' 'PACKAGE' 'VERSION')"
            write "  $(printf '%-40s %s' '───────' '───────')"
            dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' 2>/dev/null \
                | grep "installed" \
                | awk '{printf "  %-40s %s\n", $1, $2}' >> "$TEMP_REPORT"
        else
            write "  [ Last 20 Packages ]"
            dpkg-query -W -f='  ${Package}\t${Version}\n' 2>/dev/null \
                | head -20 >> "$TEMP_REPORT"
        fi

        # Security check: list packages with known outdated patterns
        write ""
        write "  [ Recently Installed (last 10 — from dpkg log) ]"
        if [[ -f /var/log/dpkg.log ]]; then
            grep " install " /var/log/dpkg.log 2>/dev/null \
                | tail -10 \
                | awk '{print "  " $1, $2, $4}' >> "$TEMP_REPORT"
        else
            write "  (dpkg log not available)"
        fi

    elif check_cmd "rpm"; then
        PKG_COUNT=$(rpm -qa 2>/dev/null | wc -l)
        tee_line "  Package Manager : rpm (RedHat / Fedora / CentOS)"
        tee_line "  Total Installed : $PKG_COUNT packages"
        [[ "$REPORT_TYPE" == "full" ]] && \
            rpm -qa --qf '  %-40{NAME} %{VERSION}\n' 2>/dev/null >> "$TEMP_REPORT"
    else
        warn "No supported package manager found (dpkg/rpm)."
        write "  [WARN] No supported package manager found."
    fi

    info "Package list collected — $PKG_COUNT packages found."
    log "Packages collected: $PKG_COUNT"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7 — RUNNING SERVICES
#
# KEY COMMANDS EXPLAINED:
#   systemctl list-units --type=service --state=running
#       Lists only services that are currently active and running.
#       --no-pager : don't pause output (important for non-interactive use).
#       --no-legend: skip the header/footer lines.
#   awk '/\.service/'  : Only process lines containing ".service"
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Every running service is a potential attack surface.
#   An unexpected service = possible compromise or misconfiguration.
#   Example: if 'telnetd' is running, that's a huge security risk.
# ─────────────────────────────────────────────────────────────────────────────
collect_services() {
    section "RUNNING SERVICES"
    write ""
    write "[ RUNNING SERVICES ]"
    write "──────────────────────────────────────────────────────"

    if check_cmd "systemctl"; then
        # Count running services
        SVC_COUNT=$(systemctl list-units --type=service --state=running \
            --no-pager --no-legend 2>/dev/null | grep -c '\.service')
        tee_line "  Total Running Services : $SVC_COUNT"
        write ""

        if [[ "$REPORT_TYPE" == "full" ]]; then
            write "  [ All Running Services ]"
            write "  $(printf '%-45s %-10s %s' 'SERVICE' 'STATE' 'DESCRIPTION')"
            write "  $(printf '%-45s %-10s %s' '───────' '─────' '───────────')"
            systemctl list-units --type=service --state=running \
                --no-pager --no-legend 2>/dev/null \
                | awk '/\.service/ {printf "  %-45s %-10s %s\n", $1, $3, $4}' \
                >> "$TEMP_REPORT"

            write ""
            write "  [ Failed / Inactive Services (security concern) ]"
            systemctl list-units --type=service --state=failed \
                --no-pager --no-legend 2>/dev/null \
                | awk '/\.service/ {print "  [!!] " $1}' >> "$TEMP_REPORT" \
                || write "  (none)"
        else
            write "  [ Top Running Services ]"
            systemctl list-units --type=service --state=running \
                --no-pager --no-legend 2>/dev/null \
                | awk '/\.service/ {print "  " $1}' | head -20 >> "$TEMP_REPORT"
        fi
    else
        warn "systemctl not available — trying service command."
        cmd_safe "service --status-all 2>&1" >> "$TEMP_REPORT"
    fi

    info "Services collected — $SVC_COUNT running."
    log "Services collected: $SVC_COUNT running"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8 — ACTIVE PROCESSES
#
# KEY COMMANDS EXPLAINED:
#   ps aux             : Show ALL processes from ALL users with details.
#     a = all users, u = user-oriented format, x = include processes
#         without a terminal (daemons)
#   --sort=-%cpu       : Sort by CPU usage descending (highest first)
#   awk 'NR>1'         : Skip the header line (NR = Number of Row)
#   wc -l              : Count lines = count processes
#
# OUTPUT COLUMNS: USER | PID | %CPU | %MEM | COMMAND
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Unusual processes (unknown names, running as root, high CPU) can indicate:
#   - Cryptomining malware
#   - Reverse shells
#   - Keyloggers or spyware
# ─────────────────────────────────────────────────────────────────────────────
collect_processes() {
    section "ACTIVE PROCESSES"
    write ""
    write "[ ACTIVE PROCESSES ]"
    write "──────────────────────────────────────────────────────"

    PROC_COUNT=$(ps aux 2>/dev/null | tail -n +2 | wc -l)
    tee_line "  Total Active Processes : $PROC_COUNT"
    write ""

    if [[ "$REPORT_TYPE" == "full" ]]; then
        write "  [ All Processes — Sorted by CPU Usage ]"
        write "  $(printf '%-15s %-7s %-5s %-5s %s' 'USER' 'PID' '%CPU' '%MEM' 'COMMAND')"
        write "  $(printf '%-15s %-7s %-5s %-5s %s' '────' '───' '────' '────' '───────')"
        ps aux --sort=-%cpu 2>/dev/null \
            | awk 'NR>1 {printf "  %-15s %-7s %-5s %-5s %s\n", $1,$2,$3,$4,$11}' \
            >> "$TEMP_REPORT"
    else
        write "  [ Top 15 Processes by CPU Usage ]"
        write "  $(printf '%-15s %-7s %-5s %-5s %s' 'USER' 'PID' '%CPU' '%MEM' 'COMMAND')"
        ps aux --sort=-%cpu 2>/dev/null \
            | awk 'NR>1 && NR<=16 {printf "  %-15s %-7s %-5s %-5s %s\n",$1,$2,$3,$4,$11}' \
            >> "$TEMP_REPORT"
    fi

    # Always show processes running as root (security relevant)
    write ""
    write "  [ Processes Running as ROOT ]"
    ps aux 2>/dev/null \
        | awk 'NR>1 && $1=="root" {printf "  PID %-7s CPU %-5s CMD %s\n",$2,$3,$11}' \
        | head -20 >> "$TEMP_REPORT"

    info "Processes collected — $PROC_COUNT total."
    log "Processes collected: $PROC_COUNT"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9 — LOGGED-IN USERS & SESSION HISTORY
#
# KEY COMMANDS EXPLAINED:
#   who              : Shows currently logged-in users with terminal and time.
#   w                : More detailed version of 'who' — also shows what they're doing.
#   last -n 20       : Show last 20 login/logout events from /var/log/wtmp.
#   lastb -n 20      : Show last 20 FAILED login attempts from /var/log/btmp.
#                      Requires root privileges to read btmp.
#   /etc/passwd      : File listing all system accounts.
#                      Format: username:password:UID:GID:info:home:shell
#                      grep -v 'nologin\|false' = keep only accounts with real shells
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Failed logins = potential brute-force attack.
#   Unexpected active users = unauthorized access.
#   Accounts with UID=0 besides root = privilege escalation indicator.
# ─────────────────────────────────────────────────────────────────────────────
collect_users() {
    section "USER ACCOUNTS & SESSIONS"
    write ""
    write "[ USER ACCOUNTS & SESSIONS ]"
    write "──────────────────────────────────────────────────────"

    write "  [ Currently Logged In ]"
    who 2>/dev/null \
        | awk '{printf "  User: %-15s Terminal: %-10s Login: %s %s\n",$1,$2,$3,$4}' \
        >> "$TEMP_REPORT"

    write ""
    write "  [ System Accounts with Real Shells (from /etc/passwd) ]"
    write "  $(printf '%-20s %-8s %s' 'USERNAME' 'UID' 'HOME')"
    grep -v 'nologin\|false\|sync\|halt\|shutdown' /etc/passwd 2>/dev/null \
        | awk -F: '{printf "  %-20s %-8s %s\n", $1, $3, $6}' \
        >> "$TEMP_REPORT"

    # Accounts with UID 0 (root-level) — should only be root itself
    write ""
    write "  [ Accounts with UID=0 (root-level — SECURITY CRITICAL) ]"
    awk -F: '$3==0 {print "  [!!] " $1 " has UID=0 (root privileges)"}' \
        /etc/passwd 2>/dev/null >> "$TEMP_REPORT"

    if [[ "$REPORT_TYPE" == "full" ]]; then
        write ""
        write "  [ Last 20 Login Sessions ]"
        last -n 20 2>/dev/null \
            | awk 'NF>0 {printf "  %-12s %-10s %-18s %s %s\n",$1,$2,$3,$4,$5}' \
            >> "$TEMP_REPORT"

        write ""
        write "  [ Failed Login Attempts — Last 20 (requires root) ]"
        lastb -n 20 2>/dev/null >> "$TEMP_REPORT" \
            || write "  (Run as root to view failed login attempts)"

        write ""
        write "  [ Auth Log — Recent sudo/su activity ]"
        grep -i "sudo\|su:" /var/log/auth.log 2>/dev/null \
            | tail -15 \
            | awk '{print "  " $0}' >> "$TEMP_REPORT" \
            || write "  (Cannot read /var/log/auth.log — try as root)"
    fi

    info "User sessions collected."
    log "User sessions collected."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 10 — OPEN NETWORK PORTS
#
# KEY COMMANDS EXPLAINED:
#   ss -tulnp        : Socket Statistics — show all open ports.
#     -t = TCP sockets
#     -u = UDP sockets
#     -l = only LISTENING sockets (waiting for connections)
#     -n = numeric (don't resolve names — faster and more accurate)
#     -p = show the process name/PID using each socket
#
#   Alternative: netstat -tulnp (older tool, same flags)
#
# OUTPUT: Protocol | Local Address:Port | Process
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Open ports = doors into your system.
#   Every open port is a potential entry point for attackers.
#   Unexpected open ports = possible backdoor or misconfigured service.
#   Example: port 4444 open = classic Metasploit reverse shell indicator.
# ─────────────────────────────────────────────────────────────────────────────
collect_ports() {
    section "OPEN NETWORK PORTS"
    write ""
    write "[ OPEN NETWORK PORTS ]"
    write "──────────────────────────────────────────────────────"
    write "  NOTE: Open ports = potential attack surface."
    write "  Review unexpected ports carefully."
    write ""

    if check_cmd "ss"; then
        write "  [ Listening TCP & UDP Ports (via ss) ]"
        write "  $(printf '%-6s %-28s %-28s %s' 'PROTO' 'LOCAL ADDRESS' 'PEER ADDRESS' 'PROCESS')"
        write "  $(printf '%-6s %-28s %-28s %s' '─────' '─────────────' '────────────' '───────')"
        ss -tulnp 2>/dev/null \
            | awk 'NR>1 {printf "  %-6s %-28s %-28s %s\n",$1,$5,$6,$7}' \
            >> "$TEMP_REPORT"
    elif check_cmd "netstat"; then
        write "  [ Listening Ports (via netstat) ]"
        netstat -tulnp 2>/dev/null >> "$TEMP_REPORT"
    else
        warn "Neither ss nor netstat available."
        write "  [WARN] ss and netstat not found."
    fi

    # Flag commonly dangerous open ports
    write ""
    write "  [ High-Risk Port Check ]"
    RISKY_PORTS="23 21 512 513 514 1080 4444 5900 6666 31337"
    for port in $RISKY_PORTS; do
        if ss -tulnp 2>/dev/null | grep -q ":$port "; then
            warn "  [RISK] Port $port is OPEN — review immediately!"
            write "  [!!] RISK: Port $port is open — potential security issue!"
        fi
    done
    write "  [ OK ] High-risk port scan complete."

    info "Open ports collected."
    log "Open ports collected."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 11 — SCHEDULED CRON JOBS
#
# KEY COMMANDS EXPLAINED:
#   crontab -l       : List the current user's scheduled cron jobs.
#   /etc/cron.d/     : System-wide cron jobs (added by packages).
#   /etc/cron.daily/ : Scripts that run every day automatically.
#   /etc/crontab     : The main system crontab file.
#
# CRON JOB FORMAT REMINDER:
#   minute hour day month weekday command
#   *      *    *   *     *       = every minute/hour/day/month/weekday
#
# WHY THIS MATTERS IN CYBERSECURITY:
#   Malicious cron jobs are one of the most common persistence mechanisms.
#   After compromising a system, attackers add cron jobs to maintain access.
#   Auditing cron jobs regularly helps detect this technique.
# ─────────────────────────────────────────────────────────────────────────────
collect_cron() {
    section "SCHEDULED CRON JOBS"
    write ""
    write "[ SCHEDULED CRON JOBS ]"
    write "──────────────────────────────────────────────────────"
    write "  SECURITY NOTE: Unexpected cron jobs = possible persistence mechanism."
    write ""

    write "  [ Current User Crontab ]"
    crontab -l 2>/dev/null >> "$TEMP_REPORT" \
        || write "  (No crontab for current user)"

    write ""
    write "  [ /etc/crontab (System) ]"
    cat /etc/crontab 2>/dev/null \
        | grep -v '^#\|^$' \
        | awk '{print "  " $0}' >> "$TEMP_REPORT" \
        || write "  (Cannot read /etc/crontab)"

    write ""
    write "  [ Cron Directories ]"
    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [[ -d "$dir" ]]; then
            FILE_COUNT=$(ls "$dir" 2>/dev/null | wc -l)
            write "  $dir  ($FILE_COUNT files)"
            ls -la "$dir" 2>/dev/null | awk 'NR>1 {print "    " $0}' >> "$TEMP_REPORT"
        fi
    done

    # Check for cron jobs running suspicious commands
    write ""
    write "  [ Suspicious Cron Pattern Check ]"
    SUSPICIOUS=$(grep -r "wget\|curl\|nc \|bash -i\|/tmp/" \
        /etc/cron* /var/spool/cron* 2>/dev/null)
    if [[ -n "$SUSPICIOUS" ]]; then
        warn "Suspicious cron patterns detected!"
        write "  [!!] WARNING — Suspicious cron entries found:"
        echo "$SUSPICIOUS" | awk '{print "  " $0}' >> "$TEMP_REPORT"
    else
        write "  [ OK ] No suspicious cron patterns found."
    fi

    info "Cron jobs collected."
    log "Cron jobs collected."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 12 — CYBERSECURITY AUDIT CHECKS
#
# This section implements the advanced security checks.
# Each check looks for a specific class of vulnerability or misconfiguration.
# ─────────────────────────────────────────────────────────────────────────────
collect_security() {
    section "SECURITY AUDIT CHECKS"
    write ""
    write "[ CYBERSECURITY AUDIT CHECKS ]"
    write "══════════════════════════════════════════════════════"

    # ── 12.1 CPU Usage Alert ─────────────────────────────────────────────
    # top -bn1 = run top once (-n1) in batch mode (-b), no interaction
    # grep "Cpu(s)" finds the CPU usage summary line
    # The 'id' field = idle percentage; we subtract from 100 to get used %
    write ""
    write "  [ CPU Usage Check ]"
    CPU_IDLE=$(top -bn1 2>/dev/null \
        | grep -i "cpu" \
        | grep -v "top\|load" \
        | head -1 \
        | awk '{for(i=1;i<=NF;i++) if($i~/id,/ || $(i-1)~/id/) print $(i-1)}' \
        | tr -d ',' | cut -d'.' -f1)

    if [[ -n "$CPU_IDLE" ]] && [[ "$CPU_IDLE" =~ ^[0-9]+$ ]]; then
        CPU_USED=$((100 - CPU_IDLE))
        if [[ $CPU_USED -gt 80 ]]; then
            warn "CPU usage is ${CPU_USED}% — ABOVE 80% THRESHOLD!"
            write "  [!!] WARNING: CPU at ${CPU_USED}% — possible resource exhaustion or malware!"
        else
            write "  [ OK ] CPU usage: ${CPU_USED}% — within normal range."
        fi
    else
        write "  [ OK ] CPU check complete (unable to parse exact value)."
    fi

    # ── 12.2 SUID Files ──────────────────────────────────────────────────
    # SUID = Set User ID bit. When set on an executable, it runs with the
    # FILE OWNER's privileges (often root) regardless of who runs it.
    # Attackers look for writable SUID files to escalate to root.
    # find / -perm -4000 = find files where the SUID bit (4000) is set
    write ""
    write "  [ SUID Files — Privilege Escalation Risk ]"
    write "  (Files that run as their owner, often root)"
    SUID_COUNT=0
    while IFS= read -r file; do
        write "  [SUID] $file"
        ((SUID_COUNT++))
    done < <(find / -perm -4000 -type f 2>/dev/null | head -40)
    write "  Total SUID files found: $SUID_COUNT"
    [[ $SUID_COUNT -gt 20 ]] && \
        write "  [!!] WARNING: High SUID count ($SUID_COUNT) — review carefully."

    # ── 12.3 World-Writable Files ─────────────────────────────────────────
    # -perm -0002 = the 'write' bit is set for 'other' (everyone)
    # These files can be modified by ANY user — dangerous for config files.
    write ""
    write "  [ World-Writable Files (Top 20) ]"
    write "  (Files any user can modify — potential tampering risk)"
    find / -perm -0002 -type f \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        2>/dev/null | head -20 \
        | awk '{print "  [WRITE] " $0}' >> "$TEMP_REPORT"

    # ── 12.4 Firewall Status ──────────────────────────────────────────────
    write ""
    write "  [ Firewall Status ]"
    if check_cmd "ufw"; then
        UFW_STATUS=$(ufw status 2>/dev/null)
        echo "$UFW_STATUS" | awk '{print "  " $0}' >> "$TEMP_REPORT"
        echo "$UFW_STATUS" | grep -q "inactive" && \
            warn "Firewall (ufw) is INACTIVE — system is unprotected!"
    elif check_cmd "iptables"; then
        RULES=$(iptables -L -n --line-numbers 2>/dev/null | head -30)
        echo "$RULES" | awk '{print "  " $0}' >> "$TEMP_REPORT"
    else
        write "  [WARN] No firewall tool found (ufw/iptables)."
    fi

    # ── 12.5 SSH Hardening Check ─────────────────────────────────────────
    # /etc/ssh/sshd_config controls how the SSH daemon behaves.
    # Bad settings = easy remote compromise.
    write ""
    write "  [ SSH Security Configuration ]"
    SSH_CFG="/etc/ssh/sshd_config"
    if [[ -f "$SSH_CFG" ]]; then
        declare -A SSH_RISKS=(
            ["PermitRootLogin"]="yes"
            ["PasswordAuthentication"]="yes"
            ["X11Forwarding"]="yes"
            ["PermitEmptyPasswords"]="yes"
        )
        for setting in PermitRootLogin PasswordAuthentication \
                        X11Forwarding MaxAuthTries \
                        PubkeyAuthentication PermitEmptyPasswords Protocol; do
            VALUE=$(grep -i "^${setting}" "$SSH_CFG" 2>/dev/null \
                | awk '{print $2}' | head -1)
            VALUE="${VALUE:-default}"
            RISK=""
            [[ "$setting" == "PermitRootLogin" && "$VALUE" == "yes" ]] && \
                RISK=" [!!] RISK: Root login allowed!"
            [[ "$setting" == "PermitEmptyPasswords" && "$VALUE" == "yes" ]] && \
                RISK=" [!!] RISK: Empty passwords allowed!"
            printf "  %-30s : %-10s%s\n" "$setting" "$VALUE" "$RISK" >> "$TEMP_REPORT"
        done
    else
        write "  SSH config not found or not readable."
    fi

    # ── 12.6 Password Policy ─────────────────────────────────────────────
    write ""
    write "  [ Password Policy (/etc/login.defs) ]"
    for setting in PASS_MAX_DAYS PASS_MIN_DAYS PASS_MIN_LEN PASS_WARN_AGE; do
        VALUE=$(grep "^$setting" /etc/login.defs 2>/dev/null | awk '{print $2}')
        printf "  %-20s : %s\n" "$setting" "${VALUE:-not set}" >> "$TEMP_REPORT"
    done

    # ── 12.7 Sudo Privileges ─────────────────────────────────────────────
    write ""
    write "  [ Sudo Privileges — Who Can Run sudo? ]"
    grep -v '^#\|^$' /etc/sudoers 2>/dev/null \
        | awk '{print "  " $0}' >> "$TEMP_REPORT" \
        || write "  (Permission denied — run as root to view sudoers)"

    # ── 12.8 Listening on all interfaces (0.0.0.0) ───────────────────────
    write ""
    write "  [ Services Listening on ALL Interfaces (0.0.0.0) ]"
    write "  (These are reachable from the network — high exposure)"
    ss -tulnp 2>/dev/null \
        | grep "0.0.0.0\|:::" \
        | awk '{printf "  [EXPOSED] %-6s %s  %s\n", $1, $5, $7}' \
        >> "$TEMP_REPORT"

    info "Security checks completed."
    log "Security checks completed."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 13 — ENVIRONMENT & SHELL
#
# PATH hijacking = attacker places a malicious binary early in PATH.
# When you run 'ls', it runs their 'ls' instead of /bin/ls.
# Auditing PATH catches this attack.
# ─────────────────────────────────────────────────────────────────────────────
collect_environment() {
    if [[ "$REPORT_TYPE" == "full" ]]; then
        section "ENVIRONMENT & SHELL"
        write ""
        write "[ ENVIRONMENT & SHELL ]"
        write "──────────────────────────────────────────────────────"

        write "  [ Current Shell ]"
        write "  $SHELL"

        write ""
        write "  [ PATH Variable (each directory on its own line) ]"
        echo "$PATH" | tr ':' '\n' | awk '{print "  " $0}' >> "$TEMP_REPORT"

        # Check for suspicious PATH entries (writable dirs, /tmp in PATH)
        write ""
        write "  [ PATH Security Check ]"
        echo "$PATH" | tr ':' '\n' | while read -r dir; do
            if [[ "$dir" == "/tmp" ]] || [[ "$dir" == "." ]]; then
                write "  [!!] RISK: '$dir' in PATH — PATH hijacking risk!"
            elif [[ -w "$dir" ]] 2>/dev/null; then
                write "  [WARN] '$dir' is world-writable — review PATH."
            fi
        done

        write ""
        write "  [ Key Environment Variables ]"
        env 2>/dev/null \
            | grep -E '^(HOME|USER|SHELL|LANG|TERM|SUDO_USER|LOGNAME)' \
            | awk '{print "  " $0}' >> "$TEMP_REPORT"
    fi

    info "Environment info collected."
    log "Environment info collected."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 14 — SAVE REPORT & SHA256 INTEGRITY HASH
#
# SHA256 = a cryptographic hash function.
# It produces a unique 64-character "fingerprint" of a file.
# If even one character in the file changes, the hash completely changes.
# We store the hash alongside the report — if someone tampers with the report,
# you can detect it by recomputing the hash and comparing.
# This is called "log integrity verification."
# ─────────────────────────────────────────────────────────────────────────────
save_report() {
    # Append report footer
    write ""
    write "=============================================================="
    write "  END OF SOFTWARE AUDIT REPORT"
    write "  Hostname  : $HOSTNAME_VAL"
    write "  Completed : $(date '+%Y-%m-%d %H:%M:%S')"
    write "=============================================================="

    # Define final output filename
    REPORT_FILE="$REPORT_DIR/software_audit_${REPORT_TYPE}_${TIMESTAMP}.txt"

    # Copy temp file to final location
    cp "$TEMP_REPORT" "$REPORT_FILE"
    rm -f "$TEMP_REPORT"

    # Generate SHA256 integrity hash
    # sha256sum outputs: HASH  FILENAME — we take only the hash part
    HASH=$(sha256sum "$REPORT_FILE" 2>/dev/null | awk '{print $1}')
    echo "$HASH" > "${REPORT_FILE}.sha256"

    # Append hash to end of report for easy reference
    echo "" >> "$REPORT_FILE"
    echo "  SHA256 Integrity Hash : $HASH" >> "$REPORT_FILE"
    echo "  Hash File             : ${REPORT_FILE}.sha256" >> "$REPORT_FILE"

    echo ""
    info "Report saved → $REPORT_FILE"
    info "SHA256 hash  → $HASH"
    echo ""

    # Export path so send_reports.sh can find it without searching
    export LAST_SOFTWARE_REPORT="$REPORT_FILE"

    log "Report saved: $REPORT_FILE | SHA256: $HASH"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 15 — MAIN EXECUTION
# This is where the script orchestrates all sections in order.
# ─────────────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "=================================================="
    echo "  >>> SOFTWARE AUDIT MODULE — Initializing..."
    echo "  Hostname : $HOSTNAME_VAL"
    echo "  Mode     : $REPORT_TYPE"
    echo "  Output   : $REPORT_DIR"
    echo "=================================================="
    echo ""

    # Validate mode argument
    case "$MODE" in
        --short|--full|--gui) ;;
        *)
            warn "Unknown mode '$MODE' — defaulting to full."
            MODE="--full"; REPORT_TYPE="full"
            ;;
    esac

    setup_dirs            # Create output directories
    write_header          # Write report identification block

    collect_os_info       # Section 5 — OS name, kernel, uptime
    collect_packages      # Section 6 — installed packages
    collect_services      # Section 7 — running services
    collect_processes     # Section 8 — active processes
    collect_users         # Section 9 — logged-in users, sessions
    collect_ports         # Section 10 — open network ports
    collect_cron          # Section 11 — scheduled cron jobs
    collect_security      # Section 12 — cybersecurity checks
    collect_environment   # Section 13 — environment variables

    save_report           # Section 14 — save file + SHA256 hash

    echo ""
    echo "[ OK ] Software audit complete!"
    echo "[ OK ] Report saved → $REPORT_DIR"
    echo ""

    log "Software audit complete."
}

# ─────────────────────────────────────────────────────────────────────────────
# Entry point: only run main() when executed directly (not sourced)
# BASH_SOURCE[0] == $0 means "this script is being run, not imported"
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
