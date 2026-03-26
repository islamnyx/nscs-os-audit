#!/bin/bash
# =============================================================================
# FILE        : setup_cron.sh
# PROJECT     : NSCS Linux Audit & Monitoring System — 2025/2026
# DESCRIPTION : Installs, removes, and manages cron automation.
#               Sets up scheduled audit runs, log rotation, and failure alerts.
# AUTHOR      : [Your Name]
# SHELL       : bash (compatible with any Linux shell)
# USAGE       : bash setup_cron.sh [--gui | install | remove | status | rotate]
#               No argument = interactive menu
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 0 — MODE & COLOR SETUP
# ─────────────────────────────────────────────────────────────────────────────
MODE="${1:-menu}"

if [[ "$MODE" == "--gui" ]] || [[ "${NO_COLOR:-}" == "1" ]]; then
    GUI_MODE=1; MODE="install"   # GUI auto-installs when button is clicked
else
    GUI_MODE=0
fi

if [[ $GUI_MODE -eq 0 ]]; then
    RED='\e[1;31m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'
    CYAN='\e[1;36m'; BLUE='\e[1;34m'; RESET='\e[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; RESET=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"           # Project root (one up from modules/)

# The main GUI launcher to schedule (Python script that orchestrates everything)
MAIN_SCRIPT="$PROJECT_ROOT/main.sh"
# Direct audit script for non-GUI automated runs
AUDIT_SCRIPT="$SCRIPT_DIR/audit_software.sh"

LOG_DIR="$HOME/nscs_os_project"
LOG_FILE="$LOG_DIR/audit.log"
CRON_LOG="$LOG_DIR/cron_execution.log"
REPORT_DIR="$HOME/nscs_os_project/reports"

# Log rotation settings
MAX_LOG_SIZE_KB=5120    # Rotate logs when they exceed 5MB
MAX_ARCHIVES=5          # Keep last 5 rotated archives

# Cron schedule — daily at 04:00 AM
# Format: min hour day month weekday
# 0 4 * * * = at exactly 04:00, every single day
CRON_SCHEDULE="0 4 * * *"

# Unique tag to identify OUR cron entries (so we can find and remove them)
CRON_TAG="# nscs_audit_auto"

HOSTNAME_VAL=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
info() { echo -e "${GREEN}[ OK ] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
err()  { echo -e "${RED}[ERROR] $1${RESET}"; }

log() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRON: $1" >> "$CRON_LOG"
}

setup_dirs() {
    for d in "$LOG_DIR" "$REPORT_DIR"; do
        mkdir -p "$d" 2>/dev/null || {
            warn "Cannot create $d — using /tmp/nscs"
            LOG_DIR="/tmp/nscs"; REPORT_DIR="/tmp/nscs/reports"
            mkdir -p "$REPORT_DIR"
        }
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — INSTALL CRON JOB
#
# HOW CRON WORKS — COMPLETE EXPLANATION:
#
#   cron is the Linux time-based job scheduler (like Windows Task Scheduler).
#   It runs as a background daemon (crond) that wakes up every minute,
#   reads the crontab files, and executes any commands whose time has come.
#
#   CRONTAB FILE FORMAT:
#   ┌───────────── minute       (0–59)
#   │ ┌─────────── hour         (0–23)
#   │ │ ┌───────── day of month (1–31)
#   │ │ │ ┌─────── month        (1–12)
#   │ │ │ │ ┌───── day of week  (0=Sun, 1=Mon, ..., 6=Sat, 7=Sun)
#   │ │ │ │ │
#   * * * * *  command_to_run
#
#   EXAMPLES:
#   0 4 * * *   = every day at 4:00 AM
#   0 4 * * 1   = every Monday at 4:00 AM
#   */5 * * * * = every 5 minutes
#   0 0 1 * *   = first day of every month at midnight
#
#   HOW WE ADD A CRON JOB SAFELY:
#   We NEVER overwrite the whole crontab — that would delete other jobs.
#   Instead we:
#     1. Read existing crontab (crontab -l)
#     2. Add our new line
#     3. Install the combined result back (crontab -)
#
#   WHAT >> AND 2>&1 MEAN IN THE CRON LINE:
#   >> $CRON_LOG   = append stdout to the log file (don't overwrite)
#   2>&1           = redirect stderr (error output) to the same place as stdout
#   Without this, cron errors are emailed locally and lost.
# ─────────────────────────────────────────────────────────────────────────────
install_cron() {
    echo ""
    echo ">>> Installing cron automation..."

    # Make audit script executable
    if [[ -f "$AUDIT_SCRIPT" ]]; then
        chmod +x "$AUDIT_SCRIPT"
        info "audit_software.sh is executable."
    else
        warn "audit_software.sh not found at $AUDIT_SCRIPT"
        warn "Cron job will be installed but may fail until script exists."
    fi

    # Our cron job line — runs the audit daily at 4:00 AM
    # /bin/bash is specified explicitly so cron uses bash regardless
    # of the user's default shell (cron has a minimal environment)
    CRON_JOB="$CRON_SCHEDULE /bin/bash $AUDIT_SCRIPT --full >> $CRON_LOG 2>&1 $CRON_TAG"

    # Check if we already installed this cron job (avoid duplicates)
    if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        warn "NSCS cron job is already installed."
        warn "Use 'remove' first if you want to reinstall."
        show_crontab
        return 0
    fi

    # (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    # Explanation:
    #   crontab -l 2>/dev/null  = print current crontab, suppress error if empty
    #   echo "$CRON_JOB"        = our new line
    #   (  ;  )                 = subshell — run both commands, combine output
    #   | crontab -             = pipe the combined output into crontab as new crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    if [[ $? -eq 0 ]]; then
        info "Cron job installed successfully!"
        echo ""
        echo "  Schedule   : $CRON_SCHEDULE (daily at 04:00 AM)"
        echo "  Script     : $AUDIT_SCRIPT"
        echo "  Log output : $CRON_LOG"
        echo ""
        log "Cron job installed: $CRON_JOB"
        show_crontab
    else
        err "Failed to install cron job."
        log "FAILED — crontab command returned error."
        exit 1
    fi

    # Also schedule weekly log rotation — every Sunday at midnight
    ROTATE_JOB="0 0 * * 0 /bin/bash $SCRIPT_DIR/setup_cron.sh rotate >> $CRON_LOG 2>&1 $CRON_TAG-rotate"
    if ! crontab -l 2>/dev/null | grep -q "$CRON_TAG-rotate"; then
        (crontab -l 2>/dev/null; echo "$ROTATE_JOB") | crontab -
        info "Log rotation cron job installed (every Sunday at midnight)."
        log "Log rotation cron installed."
    fi

    # Schedule weekly email report — every Monday at 08:00 AM
    SEND_SCRIPT="$SCRIPT_DIR/send_reports.sh"
    if [[ -f "$SEND_SCRIPT" ]]; then
        EMAIL_JOB="0 8 * * 1 /bin/bash $SEND_SCRIPT --full >> $CRON_LOG 2>&1 $CRON_TAG-email"
        if ! crontab -l 2>/dev/null | grep -q "$CRON_TAG-email"; then
            (crontab -l 2>/dev/null; echo "$EMAIL_JOB") | crontab -
            info "Weekly email cron job installed (every Monday at 08:00 AM)."
            log "Weekly email cron installed."
        fi
    fi

    echo ""
    echo "[ OK ] Cron automation configured!"
    echo ""
    echo "  [AUTO] Daily audit       : $CRON_SCHEDULE"
    echo "  [AUTO] Weekly email      : 0 8 * * 1 (Monday 08:00)"
    echo "  [AUTO] Log rotation      : 0 0 * * 0 (Sunday 00:00)"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — REMOVE CRON JOB
#
# grep -v = "invert match" = keep all lines EXCEPT ones matching the pattern.
# This removes our tagged cron lines while leaving everything else intact.
# ─────────────────────────────────────────────────────────────────────────────
remove_cron() {
    echo ""
    echo ">>> Removing NSCS cron jobs..."

    if ! crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        warn "No NSCS cron jobs found — nothing to remove."
        return 0
    fi

    # Remove all lines containing our tag
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab -

    if [[ $? -eq 0 ]]; then
        info "All NSCS cron jobs removed."
        log "Cron jobs removed."
    else
        err "Failed to remove cron jobs."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — SHOW CRONTAB
# ─────────────────────────────────────────────────────────────────────────────
show_crontab() {
    echo ""
    echo "  [ Current Crontab ]"
    echo "  ────────────────────────────────────────────────"
    crontab -l 2>/dev/null | awk '{print "  " $0}' || echo "  (empty)"
    echo "  ────────────────────────────────────────────────"
}

status_cron() {
    echo ""
    echo "=================================================="
    echo "  >>> CRON STATUS"
    echo "=================================================="

    # Check if our cron job exists
    if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        info "NSCS audit cron jobs are ACTIVE."
    else
        warn "NSCS audit cron jobs are NOT installed."
    fi

    show_crontab

    # Show last 15 log entries
    echo ""
    echo "  [ Last 15 Execution Log Entries ]"
    if [[ -f "$CRON_LOG" ]]; then
        tail -15 "$CRON_LOG" | awk '{print "  " $0}'
    else
        echo "  (No cron execution log found yet)"
    fi

    # Check cron service is running
    echo ""
    echo "  [ Cron Service Status ]"
    if command -v systemctl &>/dev/null; then
        for svc in cron crond; do
            if systemctl is-active "$svc" &>/dev/null; then
                info "$svc service is running."
                break
            fi
        done
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6 — LOG ROTATION
#
# WHY LOG ROTATION MATTERS:
#   Without rotation, log files grow indefinitely and fill your disk.
#   A full disk = system crash and lost audit data.
#
# HOW OUR ROTATION WORKS:
#   1. Check if log file exceeds MAX_LOG_SIZE_KB
#   2. If yes:
#      a. Delete the oldest archive (audit.log.5)
#      b. Shift archives: .4→.5, .3→.4, .2→.3, .1→.2
#      c. Hash the current log for integrity
#      d. Rename current log to .1 (archive it)
#      e. Create a new empty log file
#
# SHA256 INTEGRITY:
#   Before archiving, we hash the log file.
#   This creates a verifiable "fingerprint" of the log at rotation time.
#   If someone later tries to alter old log archives,
#   the hash won't match anymore — tampering detected.
# ─────────────────────────────────────────────────────────────────────────────
rotate_logs() {
    echo ""
    echo ">>> Running log rotation check..."

    for log_target in "$LOG_FILE" "$CRON_LOG"; do
        [[ ! -f "$log_target" ]] && continue

        # Get file size in KB
        # du -k = disk usage in kilobytes; cut -f1 = first column (just the number)
        SIZE_KB=$(du -k "$log_target" 2>/dev/null | cut -f1)

        echo "  Checking: $log_target (${SIZE_KB}KB / ${MAX_LOG_SIZE_KB}KB limit)"

        if [[ "$SIZE_KB" -ge "$MAX_LOG_SIZE_KB" ]] 2>/dev/null; then
            info "Rotating $log_target (${SIZE_KB}KB exceeds limit)"

            # Delete oldest archive if it exists
            OLDEST="${log_target}.${MAX_ARCHIVES}"
            [[ -f "$OLDEST" ]] && rm -f "$OLDEST" && \
                echo "  Deleted oldest archive: $OLDEST"

            # Shift existing archives: .4 → .5, .3 → .4, etc.
            # seq generates: 4 3 2 1 (counting down)
            for i in $(seq $((MAX_ARCHIVES - 1)) -1 1); do
                [[ -f "${log_target}.${i}" ]] && \
                    mv "${log_target}.${i}" "${log_target}.$((i + 1))"
            done

            # Generate SHA256 hash BEFORE archiving (integrity record)
            HASH=$(sha256sum "$log_target" 2>/dev/null | awk '{print $1}')

            # Archive the current log → .1
            mv "$log_target" "${log_target}.1"
            echo "$HASH  ${log_target}.1" > "${log_target}.1.sha256"
            info "Archived: ${log_target}.1"
            info "Integrity hash: $HASH"

            # Create fresh log with a rotation notice header
            {
                echo "================================================================"
                echo " Log file rotated on: $(date '+%Y-%m-%d %H:%M:%S')"
                echo " Previous log archived to: ${log_target}.1"
                echo " Previous log SHA256: $HASH"
                echo "================================================================"
            } > "$log_target"

            log "Rotated: $log_target (was ${SIZE_KB}KB) → archived as ${log_target}.1"
        else
            info "$log_target is fine (${SIZE_KB}KB < ${MAX_LOG_SIZE_KB}KB)."
        fi
    done

    echo ""
    echo "[ OK ] Log rotation complete."
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7 — FAILURE HANDLER & ALERT
#
# When a cron job fails, we need to know about it.
# This function logs the failure and sends an alert email.
# It's called by the cron wrapper if the audit script exits with non-zero.
# ─────────────────────────────────────────────────────────────────────────────
handle_failure() {
    local EXIT_CODE="$1"
    local FAILED_SCRIPT="${2:-unknown script}"

    err "Script failed: $FAILED_SCRIPT (exit code: $EXIT_CODE)"
    log "FAILURE — $FAILED_SCRIPT exited with code $EXIT_CODE"

    # Load email config for alert
    EMAIL_CONF="$PROJECT_ROOT/email.conf"
    [[ -f "$EMAIL_CONF" ]] && source "$EMAIL_CONF"
    RECIPIENT="${RECIPIENT_EMAIL:-admin@example.com}"

    # Send a failure alert email if msmtp is available
    if command -v msmtp &>/dev/null && [[ -f "$HOME/.msmtprc" ]]; then
        ALERT_TMP=$(mktemp /tmp/nscs_alert_XXXXXX.eml)
        cat > "$ALERT_TMP" <<EOF
From: NSCS Audit Bot <${SENDER_EMAIL:-audit@nscs.local}>
To: $RECIPIENT
Subject: [ALERT] NSCS Audit FAILED on $HOSTNAME_VAL — $(date '+%Y-%m-%d %H:%M')

AUTOMATED AUDIT FAILURE ALERT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Hostname  : $HOSTNAME_VAL
  Time      : $(date '+%Y-%m-%d %H:%M:%S')
  Script    : $FAILED_SCRIPT
  Exit Code : $EXIT_CODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Check log at: $CRON_LOG
EOF
        msmtp -a default "$RECIPIENT" < "$ALERT_TMP" 2>/dev/null && \
            info "Failure alert sent to $RECIPIENT."
        rm -f "$ALERT_TMP"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8 — INTERACTIVE MENU (terminal mode only)
# ─────────────────────────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║    NSCS AUTOMATION SETUP — setup_cron.sh  ║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  1) Install cron jobs  (daily 04:00, weekly email, log rotation)"
    echo "  2) Remove cron jobs"
    echo "  3) Show cron status"
    echo "  4) Run log rotation now"
    echo "  5) Exit"
    echo ""
    echo -n "  Choose [1-5]: "
    read -r choice

    case "$choice" in
        1) install_cron ;;
        2) remove_cron ;;
        3) status_cron ;;
        4) rotate_logs ;;
        5) echo "Goodbye."; exit 0 ;;
        *) warn "Invalid choice."; show_menu ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9 — MAIN EXECUTION
# ─────────────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "=================================================="
    echo "  >>> SETUP CRON MODULE — Initializing..."
    echo "  Hostname : $HOSTNAME_VAL"
    echo "  Time     : $TIMESTAMP"
    echo "=================================================="

    setup_dirs

    case "$MODE" in
        install)      install_cron ;;
        remove)       remove_cron ;;
        status)       status_cron ;;
        rotate)       rotate_logs ;;
        menu|"")      show_menu ;;
        --gui)        install_cron ;;    # GUI click = auto-install
        *)
            warn "Unknown argument: $MODE"
            echo "Usage: $0 [install | remove | status | rotate]"
            exit 1
            ;;
    esac

    echo ""
    echo "[ OK ] Cron setup module complete!"
    echo ""
    log "setup_cron.sh completed — mode: $MODE"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
