#!/bin/bash
################################################################################
# NSCS OS Project - Cron Automation Module (HACKER EDITION)
# Phase 4 — Automated Scheduling, Logging & Failure Handling
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT THIS SCRIPT DOES                                                  │
# │                                                                         │
# │  1. SCHEDULING   — writes cron entries so audits run automatically      │
# │                    every day at 04:00 AM (no human needed)              │
# │                                                                         │
# │  2. LOGGING      — every cron execution gets timestamped log entries    │
# │                    so you have a full audit trail of what ran & when    │
# │                                                                         │
# │  3. FAILURE      — if any module crashes, it catches the error,        │
# │     HANDLING       logs it with details, and sends an alert email       │
# │                                                                         │
# │  HOW CRON WORKS:                                                        │
# │    cron is a Linux daemon that wakes up every minute and checks         │
# │    /var/spool/cron/crontabs/<user> for scheduled tasks.                 │
# │                                                                         │
# │    Cron syntax:  MIN  HOUR  DAY  MONTH  WEEKDAY  COMMAND               │
# │    Example:        0     4    *      *        *   bash script.sh        │
# │    Meaning:    "at minute 0 of hour 4, every day" = 04:00 AM daily     │
# │                                                                         │
# │  FILES CREATED:                                                         │
# │    ~/nscs_os_project/nscs_cron_runner.sh  — the actual cron wrapper    │
# │    ~/nscs_os_project/cron.log             — execution log               │
# │    ~/nscs_os_project/cron_status.json     — machine-readable status     │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Author: NSCS OS Project | Date: 2026
################################################################################

# ============================================================================
# COLORS
# ============================================================================

G0='\033[0;32m'; G1='\033[1;32m'; G2='\033[0;92m'
CY='\033[0;36m'; YW='\033[1;33m'; RD='\033[1;31m'
WH='\033[1;37m'; DM='\033[2;32m'; NC='\033[0m'; BOLD='\033[1m'

# ============================================================================
# PATHS
# ============================================================================

BASE_DIR="$HOME/nscs-os-audit"
MODULES_DIR="$BASE_DIR/modules"
LOG_FILE="$BASE_DIR/cron.log"
STATUS_JSON="$BASE_DIR/cron_status.json"
RUNNER_SCRIPT="$BASE_DIR/nscs_cron_runner.sh"
REPORT_DIR="$BASE_DIR/reports"

mkdir -p "$BASE_DIR" "$REPORT_DIR"

TW=$(tput cols 2>/dev/null || echo 80)
(( TW < 40 )) && TW=40
(( TW > 120 )) && TW=120

GUI_MODE=0
for arg in "$@"; do [[ "$arg" == "--gui" ]] && GUI_MODE=1; done

# ============================================================================
# UTILITIES
# ============================================================================

repeat_char() {
    local char="$1" count="$2"
    (( count <= 0 )) && return
    printf "%${count}s" | tr ' ' "$char"
}

divider() {
    local char="${1:-─}" color="${2:-$G0}"
    local w=$(( TW - 4 )); (( w < 10 )) && w=10
    echo -e "${color}$(repeat_char "$char" $w)${NC}"
}

center_print() {
    local text="$1"
    local clean; clean=$(printf '%b' "$text" | sed 's/\x1b\[[0-9;]*[mKHABCDEFGJSTfu]//g')
    local len=${#clean}; local pad=$(( (TW - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%${pad}s" ""; echo -e "$text"
}

section() {
    local title="$1"; local tlen=${#title}
    local side=$(( (TW - tlen - 6) / 2 )); (( side < 1 )) && side=1
    echo ""
    echo -e "${G0}$(repeat_char '─' $side)${NC} ${G1}${BOLD}${title}${NC} ${G0}$(repeat_char '─' $side)${NC}"
}

print_field() {
    local key="$1" val="$2"
    local max_val=$(( TW - 30 )); (( max_val < 10 )) && max_val=10
    (( ${#val} > max_val )) && val="${val:0:$max_val}..."
    printf "  ${DM}%-26s${NC} ${G1}▶${NC} ${WH}%s${NC}\n" "$key" "$val"
}

print_ok()   { echo -e "  ${G1}[ OK ]${NC}  $1"; }
print_warn() { echo -e "  ${YW}[ !! ]${NC}  $1"; }
print_info() { echo -e "  ${G0}[ ** ]${NC}  $1"; }
print_err()  { echo -e "  ${RD}[ XX ]${NC}  $1"; }

progress() {
    local label="$1" duration="${2:-1.0}"
    local bar_w=$(( TW - ${#label} - 14 ))
    (( bar_w > 40 )) && bar_w=40; (( bar_w < 5 )) && bar_w=5
    echo -en "  ${DM}${label}${NC} ${G0}["
    local t; t=$(echo "scale=4; $duration / $bar_w" | bc 2>/dev/null || echo "0.03")
    for ((i=0; i<bar_w; i++)); do
        (( i < bar_w/3 ))                   && echo -en "${DM}█${NC}"
        (( i >= bar_w/3 && i < bar_w*2/3 )) && echo -en "${G0}█${NC}"
        (( i >= bar_w*2/3 ))                && echo -en "${G1}█${NC}"
        sleep "$t"
    done
    echo -e "${G1}] 100%${NC}"
}

type_header() {
    if (( GUI_MODE == 1 )) || (( TW < 60 )); then
        echo -e "${G1}$1${NC}"
    else
        echo -en "${G1}"
        while IFS= read -r -n1 c; do echo -n "$c"; sleep 0.015; done <<< "$1"
        echo -e "${NC}"
    fi
}

log_entry() {
    # Writes to cron.log with timestamp + severity
    local level="$1" msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

# ============================================================================
# BOOT HEADER
# ============================================================================

clear
echo ""
if (( TW >= 72 )); then
    echo -e "${G1}"
    center_print "█████╗ ██╗   ██╗████████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗███████╗"
    center_print "██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗████╗ ████║██╔══██╗╚══██╔══╝██╔════╝"
    center_print "███████║██║   ██║   ██║   ██║   ██║██╔████╔██║███████║   ██║   █████╗  "
    center_print "██╔══██║██║   ██║   ██║   ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  "
    center_print "██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ███████╗"
    center_print "╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝"
    echo -e "${NC}"
else
    echo -e "${G1}"; center_print "[ NSCS — CRON AUTOMATION ]"; echo -e "${NC}"
fi

local dw=$(( TW - 6 )); (( dw < 10 )) && dw=10
echo -e "${DM}$(repeat_char '═' $dw)${NC}"
center_print "${G0}NSCS — Cron Automation & Scheduling  |  Phase 4  |  v2.0${NC}"
center_print "${DM}$(date '+%A %d %B %Y   %H:%M:%S')${NC}"
echo -e "${DM}$(repeat_char '═' $dw)${NC}"
echo ""
type_header ">>> INITIALIZING CRON AUTOMATION ENGINE..."
progress "Loading cron subsystem    " 0.7
progress "Scanning module directory " 0.6
echo ""

log_entry "INFO" "setup_cron.sh started — user: $(whoami) host: $(hostname)"

# ============================================================================
# STEP 1 — CHECK MODULES EXIST
# ============================================================================
#
# CONCEPT: Before scheduling, verify all scripts exist and are executable.
# A cron job that points to a missing file silently does nothing — we
# catch that problem NOW, not at 4AM when no one is watching.
#
# ============================================================================

section "STEP 1 — MODULE VERIFICATION"

MODULES=(
    "audit_hardware_v2.sh:Phase 1 — Hardware Audit"
    "audit_software.sh:Phase 1 — Software Audit"
    "generate_reports.sh:Phase 2 — Report Generation"
    "send_reports.sh:Phase 3 — Email Transmission"
    "remote_monitor.sh:Phase 5 — Remote Monitoring"
)

ALL_OK=1
for entry in "${MODULES[@]}"; do
    script="${entry%%:*}"
    label="${entry##*:}"
    path="$MODULES_DIR/$script"

    if [ -f "$path" ]; then
        # Make executable if not already
        chmod +x "$path" 2>/dev/null
        print_ok "${WH}${script}${NC} ${DM}— ${label}${NC}"
        log_entry "INFO" "Module verified: $script"
    else
        print_warn "${YW}${script}${NC} ${DM}— NOT FOUND (will skip in runner)${NC}"
        log_entry "WARN" "Module missing: $script"
        ALL_OK=0
    fi
done

echo ""
if (( ALL_OK == 1 )); then
    print_ok "All modules verified — cron runner will execute full pipeline"
else
    print_warn "Some modules missing — cron runner will skip missing scripts"
fi

# ============================================================================
# STEP 2 — CREATE THE CRON RUNNER SCRIPT
# ============================================================================
#
# CONCEPT: The cron runner (nscs_cron_runner.sh)
#
#   Cron can't call our menu-based scripts directly — they need a TTY
#   (terminal) and interactive input. Instead, cron calls a WRAPPER script
#   that:
#     1. Sets up the environment (PATH, HOME, etc.) — cron runs with a
#        minimal environment, so we must define everything explicitly
#     2. Calls each module with --gui flag (no interactive prompts)
#     3. Checks the exit code of each module (0=success, non-zero=failure)
#     4. Logs everything with timestamps
#     5. Sends alert email if anything fails
#
#   WHY a separate wrapper?
#     Real-world practice: cron jobs should be thin — just call a script.
#     The script handles logic, logging, and error handling.
#     This makes it easy to test the runner manually:
#       bash ~/nscs_os_project/nscs_cron_runner.sh
#
# ============================================================================

section "STEP 2 — CREATING CRON RUNNER SCRIPT"

progress "Writing runner script     " 0.8

cat <<'RUNNER_EOF' > "$RUNNER_SCRIPT"
#!/bin/bash
################################################################################
# NSCS Cron Runner — Auto-generated by setup_cron.sh
# Called by cron daemon every day at 04:00 AM
#
# DO NOT EDIT MANUALLY — regenerate with setup_cron.sh
################################################################################

# ── Environment setup ─────────────────────────────────────────────────────────
# CRITICAL: cron runs with a minimal environment — none of your .bashrc
# variables exist. We must define everything from scratch.

export HOME="${HOME:-/home/$(whoami)}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="dumb"      # no color codes — cron has no terminal
export NO_COLOR="1"

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR="$HOME/nscs_os_project"
MODULES_DIR="$BASE_DIR/modules"
LOG_FILE="$BASE_DIR/cron.log"
STATUS_JSON="$BASE_DIR/cron_status.json"
REPORT_DIR="$BASE_DIR/reports"
ALERT_EMAIL_CONF="$BASE_DIR/email.conf"

mkdir -p "$BASE_DIR" "$REPORT_DIR"

# ── Logging functions ─────────────────────────────────────────────────────────
# Every line written to cron.log has:
#   [TIMESTAMP] [LEVEL] MESSAGE
# This makes it easy to grep for errors: grep '\[ERROR\]' cron.log

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO ]  $*" | tee -a "$LOG_FILE"; }
log_ok()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ OK  ]  $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN ]  $*" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]  $*" | tee -a "$LOG_FILE"; }

# ── Session tracking ──────────────────────────────────────────────────────────
RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
SESSION_START=$(date +%s)
FAILED_MODULES=()
SUCCESS_MODULES=()

# ── Start of session ──────────────────────────────────────────────────────────
{
echo "════════════════════════════════════════════════════════"
echo "  NSCS CRON RUNNER — SESSION START"
echo "  Run ID  : $RUN_ID"
echo "  Started : $(date)"
echo "  Host    : $(hostname)"
echo "  User    : $(whoami)"
echo "════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"

log_info "Session $RUN_ID started"

# ── Module runner function ────────────────────────────────────────────────────
# run_module SCRIPT_NAME LABEL
#
# HOW FAILURE HANDLING WORKS:
#   Every Linux command returns an "exit code" when it finishes:
#     0  = success (by convention)
#     1+ = failure (the number indicates the type of error)
#
#   $? contains the exit code of the last command.
#   We check it after every module and log accordingly.
#
#   timeout 300 bash ...  = kill the process after 5 minutes
#   This prevents a stuck module from blocking the entire cron job.

run_module() {
    local script="$1"
    local label="$2"
    local script_path="$MODULES_DIR/$script"

    log_info "Starting: $label ($script)"

    # Check script exists
    if [ ! -f "$script_path" ]; then
        log_warn "SKIPPED: $script — file not found at $script_path"
        return 0   # Not a failure — just skip missing modules
    fi

    # Make executable
    chmod +x "$script_path"

    # Run with:
    #   timeout 300  = max 5 minutes before force-kill
    #   --gui        = skip interactive prompts
    #   >> $LOG_FILE = append all output to log
    #   2>&1         = also capture stderr (error output) to log
    local start_time; start_time=$(date +%s)

    timeout 300 bash "$script_path" --gui >> "$LOG_FILE" 2>&1
    local exit_code=$?
    local end_time; end_time=$(date +%s)
    local duration=$(( end_time - start_time ))

    # Interpret exit code
    if [ $exit_code -eq 0 ]; then
        # SUCCESS
        log_ok "$label completed in ${duration}s (exit 0)"
        SUCCESS_MODULES+=("$label")

    elif [ $exit_code -eq 124 ]; then
        # TIMEOUT (exit code 124 = timeout killed the process)
        log_error "$label TIMED OUT after 300s — killed"
        FAILED_MODULES+=("$label:TIMEOUT after 300s")

    else
        # FAILURE (non-zero exit code)
        log_error "$label FAILED with exit code $exit_code (duration: ${duration}s)"
        FAILED_MODULES+=("$label:exit code $exit_code")
    fi

    return $exit_code
}

# ── Run all modules in order ──────────────────────────────────────────────────
# Order matters: hardware/software audits must run BEFORE report generation
# because generate_reports.sh reads the JSON files they produce.

log_info "--- Phase 1: Audit ---"
run_module "audit_hardware_v2.sh" "Hardware Audit"
run_module "audit_software.sh"    "Software Audit"

log_info "--- Phase 2: Reports ---"
run_module "generate_reports.sh"  "Report Generation"

log_info "--- Phase 3: Email ---"
run_module "send_reports.sh"      "Email Transmission"

log_info "--- Phase 5: Remote ---"
run_module "remote_monitor.sh"    "Remote Monitoring"

# ── Session summary ───────────────────────────────────────────────────────────
SESSION_END=$(date +%s)
TOTAL_DURATION=$(( SESSION_END - SESSION_START ))
FAIL_COUNT=${#FAILED_MODULES[@]}
OK_COUNT=${#SUCCESS_MODULES[@]}

{
echo "════════════════════════════════════════════════════════"
echo "  NSCS CRON RUNNER — SESSION COMPLETE"
echo "  Run ID    : $RUN_ID"
echo "  Finished  : $(date)"
echo "  Duration  : ${TOTAL_DURATION}s"
echo "  Succeeded : $OK_COUNT module(s)"
echo "  Failed    : $FAIL_COUNT module(s)"
if (( FAIL_COUNT > 0 )); then
    echo "  Failures  :"
    for f in "${FAILED_MODULES[@]}"; do
        echo "    - $f"
    done
fi
echo "════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"

# ── Write machine-readable status JSON ───────────────────────────────────────
# This lets other tools (or the GUI) read cron status programmatically

FAIL_JSON=""
for f in "${FAILED_MODULES[@]}"; do
    mod="${f%%:*}"; reason="${f##*:}"
    FAIL_JSON+="    {\"module\":\"$mod\",\"reason\":\"$reason\"},"
done
FAIL_JSON="${FAIL_JSON%,}"

OK_JSON=""
for s in "${SUCCESS_MODULES[@]}"; do
    OK_JSON+="\"$s\","
done
OK_JSON="${OK_JSON%,}"

OVERALL="SUCCESS"
(( FAIL_COUNT > 0 )) && OVERALL="PARTIAL_FAILURE"
(( OK_COUNT == 0 && FAIL_COUNT > 0 )) && OVERALL="TOTAL_FAILURE"

cat <<EOF > "$STATUS_JSON"
{
  "run_id": "$RUN_ID",
  "timestamp": "$(date)",
  "host": "$(hostname)",
  "user": "$(whoami)",
  "overall_status": "$OVERALL",
  "duration_seconds": $TOTAL_DURATION,
  "succeeded": $OK_COUNT,
  "failed": $FAIL_COUNT,
  "successful_modules": [$OK_JSON],
  "failed_modules": [
$FAIL_JSON
  ]
}
EOF

# ── FAILURE HANDLING — Send alert email if anything failed ────────────────────
#
# CONCEPT: Failure notification
#
#   A cron job that silently fails is DANGEROUS — you think your system
#   is being audited but it isn't. We solve this by sending an alert email
#   when any module fails.
#
#   We reuse the email credentials from send_reports.sh (email.conf)
#   so no extra configuration is needed.
#
#   The alert email contains:
#     - Which modules failed
#     - The error reason
#     - The full log file path to investigate
#
# ─────────────────────────────────────────────────────────────────────────────

if (( FAIL_COUNT > 0 )); then
    log_warn "Failures detected — attempting alert email..."

    if [ -f "$ALERT_EMAIL_CONF" ]; then
        source "$ALERT_EMAIL_CONF" 2>/dev/null

        if [ -n "$SMTP_FROM" ] && [ -n "$SMTP_PASS" ] && [ -n "$SMTP_TO" ]; then
            FAIL_LIST=""
            for f in "${FAILED_MODULES[@]}"; do
                FAIL_LIST+="  - $f\n"
            done

            python3 - <<PYEOF 2>/dev/null
import smtplib, ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

msg = MIMEMultipart()
msg["From"]    = "NSCS Cron <$SMTP_FROM>"
msg["To"]      = "$SMTP_TO"
msg["Subject"] = "[NSCS ALERT] Cron job failures on $(hostname) — $RUN_ID"

body = """NSCS Automated Audit System — FAILURE ALERT

Host     : $(hostname)
Run ID   : $RUN_ID
Time     : $(date)
Status   : $OVERALL

Failed modules ($FAIL_COUNT):
$(printf '%b' "$FAIL_LIST")
Successful modules ($OK_COUNT):
$(printf '%s\n' "${SUCCESS_MODULES[@]}" | sed 's/^/  - /')

Full log : $LOG_FILE
Status   : $STATUS_JSON

This is an automated alert from your NSCS cron runner.
"""
msg.attach(MIMEText(body, "plain"))

try:
    ctx = ssl.create_default_context()
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as s:
        s.ehlo(); s.starttls(context=ctx); s.ehlo()
        s.login("$SMTP_FROM", "$SMTP_PASS")
        s.sendmail("$SMTP_FROM", "$SMTP_TO", msg.as_string())
    print("[$(date '+%Y-%m-%d %H:%M:%S')] [ OK  ]  Alert email sent to $SMTP_TO")
except Exception as e:
    print(f"[$(date '+%Y-%m-%d %H:%M:%S')] [WARN ]  Alert email failed: {e}")
PYEOF
            log_ok "Alert email sent to $SMTP_TO"
        else
            log_warn "Alert email skipped — incomplete credentials in email.conf"
        fi
    else
        log_warn "Alert email skipped — no email.conf found"
        log_info "Run send_reports.sh once in terminal to configure email"
    fi
fi

# Exit with number of failures as exit code
# 0 = total success, 1+ = number of failed modules
exit $FAIL_COUNT
RUNNER_EOF

chmod +x "$RUNNER_SCRIPT"
print_ok "Runner script created → ${G1}$RUNNER_SCRIPT${NC}"
log_entry "INFO" "Cron runner script created: $RUNNER_SCRIPT"

# ============================================================================
# STEP 3 — WRITE CRON ENTRIES
# ============================================================================
#
# CONCEPT: crontab
#
#   `crontab -l` lists current entries.
#   We use `crontab -l` to read existing entries, add ours,
#   then pipe back to `crontab -` to install them.
#
#   WHY we check for existing entries first:
#   Running setup_cron.sh twice shouldn't create duplicate entries.
#
#   CRON SYNTAX:
#     MIN  HOUR  DAY  MONTH  WEEKDAY  COMMAND
#      0    4     *    *       *      = every day at 04:00 AM
#      30   14    *    *       1      = every Monday at 14:30
#      0    8     1    *       *      = 1st of every month at 08:00
#      *    *     *    *       *      = every single minute
#
# ============================================================================

section "STEP 3 — CUSTOM SCHEDULE SETUP"

echo ""
echo -e "  ${G0}Cron syntax quick reference:${NC}"
echo -e "  ${DM}  MIN(0-59)  HOUR(0-23)  DAY(1-31)  MONTH(1-12)  WEEKDAY(0-7)${NC}"
echo -e "  ${DM}  *  = every   */2 = every 2   1-5 = range   1,3,5 = specific${NC}"
echo ""

# ── PRESET SCHEDULES ─────────────────────────────────────────────────────────
echo -e "  ${G1}Choose a schedule for the daily audit:${NC}"
echo ""
echo -e "  ${G1}[1]${NC} ${WH}Every day at 04:00 AM     ${DM}0 4 * * *${NC}"
echo -e "  ${G1}[2]${NC} ${WH}Every day at 02:00 AM     ${DM}0 2 * * *${NC}"
echo -e "  ${G1}[3]${NC} ${WH}Every day at 12:00 PM     ${DM}0 12 * * *${NC}"
echo -e "  ${G1}[4]${NC} ${WH}Every day at 08:00 PM     ${DM}0 20 * * *${NC}"
echo -e "  ${G1}[5]${NC} ${WH}Every Monday at 04:00 AM  ${DM}0 4 * * 1${NC}"
echo -e "  ${G1}[6]${NC} ${WH}Every 6 hours             ${DM}0 */6 * * *${NC}"
echo -e "  ${G1}[7]${NC} ${WH}Every hour                ${DM}0 * * * *${NC}"
echo -e "  ${G1}[8]${NC} ${WH}Custom — I will type it   ${NC}"
echo ""

if (( GUI_MODE == 1 )); then
    # GUI mode — use safe default
    AUDIT_CRON="0 4 * * *"
    AUDIT_DESC="Every day at 04:00 AM (GUI default)"
    print_info "GUI mode — using default schedule: $AUDIT_CRON"
else
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Choice [1-8]: "
    read -r sched_choice

    case "$sched_choice" in
        1) AUDIT_CRON="0 4 * * *";   AUDIT_DESC="Every day at 04:00 AM" ;;
        2) AUDIT_CRON="0 2 * * *";   AUDIT_DESC="Every day at 02:00 AM" ;;
        3) AUDIT_CRON="0 12 * * *";  AUDIT_DESC="Every day at 12:00 PM" ;;
        4) AUDIT_CRON="0 20 * * *";  AUDIT_DESC="Every day at 08:00 PM" ;;
        5) AUDIT_CRON="0 4 * * 1";   AUDIT_DESC="Every Monday at 04:00 AM" ;;
        6) AUDIT_CRON="0 */6 * * *"; AUDIT_DESC="Every 6 hours" ;;
        7) AUDIT_CRON="0 * * * *";   AUDIT_DESC="Every hour" ;;
        8)
            echo ""
            echo -e "  ${DM}Enter custom cron expression (5 fields):${NC}"
            echo -e "  ${DM}Example: 30 14 * * 1-5  = Mon-Fri at 14:30${NC}"
            echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Cron expression: "
            read -r AUDIT_CRON
            AUDIT_DESC="Custom: $AUDIT_CRON"
            # Basic validation — check it has 5 fields
            FIELD_COUNT=$(echo "$AUDIT_CRON" | awk '{print NF}')
            if (( FIELD_COUNT != 5 )); then
                print_warn "Invalid — cron needs exactly 5 fields. Using default: 0 4 * * *"
                AUDIT_CRON="0 4 * * *"
                AUDIT_DESC="Every day at 04:00 AM (fallback)"
            fi
            ;;
        *)
            print_warn "Invalid choice — using default: 0 4 * * *"
            AUDIT_CRON="0 4 * * *"
            AUDIT_DESC="Every day at 04:00 AM (default)"
            ;;
    esac
fi

echo ""
print_ok "Audit schedule set: ${G1}$AUDIT_CRON${NC} — ${WH}$AUDIT_DESC${NC}"

# ── EMAIL SCHEDULE ────────────────────────────────────────────────────────────
echo ""
echo -e "  ${G1}Choose a schedule for the automatic email report:${NC}"
echo ""
echo -e "  ${G1}[1]${NC} ${WH}Same time as audit (right after)${NC}"
echo -e "  ${G1}[2]${NC} ${WH}Every Monday at 08:00 AM        ${DM}0 8 * * 1${NC}"
echo -e "  ${G1}[3]${NC} ${WH}1st of every month at 08:00 AM  ${DM}0 8 1 * *${NC}"
echo -e "  ${G1}[4]${NC} ${WH}Never (disable email schedule)${NC}"
echo ""

if (( GUI_MODE == 1 )); then
    EMAIL_CRON="0 8 1 * *"
    EMAIL_DESC="1st of every month at 08:00 AM (GUI default)"
    print_info "GUI mode — using default email schedule: $EMAIL_CRON"
else
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Choice [1-4]: "
    read -r email_choice

    case "$email_choice" in
        1)
            # Parse hour from audit cron and add 30 mins
            AUDIT_HOUR=$(echo "$AUDIT_CRON" | awk '{print $2}')
            AUDIT_MIN=$(echo "$AUDIT_CRON" | awk '{print $1}')
            # Add 30 minutes safely
            if [[ "$AUDIT_MIN" =~ ^[0-9]+$ ]] && [[ "$AUDIT_HOUR" =~ ^[0-9]+$ ]]; then
                EMAIL_MIN=$(( (AUDIT_MIN + 30) % 60 ))
                EMAIL_HOUR=$(( AUDIT_HOUR + (AUDIT_MIN + 30) / 60 ))
                EMAIL_CRON="$EMAIL_MIN $EMAIL_HOUR * * *"
            else
                EMAIL_CRON="30 4 * * *"
            fi
            EMAIL_DESC="30 minutes after audit run"
            ;;
        2) EMAIL_CRON="0 8 * * 1"; EMAIL_DESC="Every Monday at 08:00 AM" ;;
        3) EMAIL_CRON="0 8 1 * *"; EMAIL_DESC="1st of every month at 08:00 AM" ;;
        4) EMAIL_CRON="";           EMAIL_DESC="Disabled" ;;
        *) EMAIL_CRON="0 8 1 * *"; EMAIL_DESC="1st of every month (default)" ;;
    esac
fi

[ -n "$EMAIL_CRON" ] && print_ok "Email schedule set: ${G1}$EMAIL_CRON${NC} — ${WH}$EMAIL_DESC${NC}"                       || print_info "Email schedule: ${DM}disabled${NC}"

# ── BUILD AND INSTALL CRON ENTRIES ───────────────────────────────────────────
CRON_MARKER="# NSCS-AUDIT-SYSTEM"

CRON_ENTRIES="
$CRON_MARKER — DO NOT EDIT — managed by setup_cron.sh
# Audit schedule: $AUDIT_DESC
$AUDIT_CRON bash $RUNNER_SCRIPT >> $LOG_FILE 2>&1
"
# Add email entry only if enabled
if [ -n "$EMAIL_CRON" ]; then
    CRON_ENTRIES+="# Email schedule: $EMAIL_DESC
$EMAIL_CRON bash $MODULES_DIR/send_reports.sh --gui >> $LOG_FILE 2>&1
"
fi

CRON_ENTRIES+="# Weekly cleanup of old reports (keep last 30 days) — Sunday midnight
0 0 * * 0 find $REPORT_DIR -name '*.json' -mtime +30 -delete >> $LOG_FILE 2>&1
$CRON_MARKER-END"

# Remove old NSCS entries if they exist, then install fresh
if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
    print_warn "Existing NSCS cron entries found — replacing with new schedule..."
    crontab -l 2>/dev/null |         awk "/$CRON_MARKER/,/${CRON_MARKER}-END/{next}1"         > /tmp/nscs_cron_clean.txt
else
    crontab -l 2>/dev/null > /tmp/nscs_cron_clean.txt
fi

echo "$CRON_ENTRIES" >> /tmp/nscs_cron_clean.txt
crontab /tmp/nscs_cron_clean.txt
rm -f /tmp/nscs_cron_clean.txt

if [ $? -eq 0 ]; then
    print_ok "Cron schedule installed successfully"
    log_entry "INFO" "Cron installed: audit=$AUDIT_CRON email=${EMAIL_CRON:-disabled}"
else
    print_err "Failed to install crontab — try: crontab -e"
    log_entry "ERROR" "Crontab installation failed"
fi

echo ""
print_info "Active schedule:"
echo ""
printf "  ${G1}%-28s${NC} ${WH}%s${NC}\n" "$AUDIT_CRON"   "Audit: $AUDIT_DESC"
[ -n "$EMAIL_CRON" ] && printf "  ${G1}%-28s${NC} ${WH}%s${NC}\n" "$EMAIL_CRON"   "Email: $EMAIL_DESC"
printf "  ${G1}%-28s${NC} ${WH}%s${NC}\n" "0 0 * * 0"     "Cleanup: old reports (Sunday midnight)"

# ============================================================================
# STEP 4 — LOG ROTATION SETUP
# ============================================================================
#
# CONCEPT: Log rotation
#
#   If we write to cron.log every day forever, it will grow huge.
#   Log rotation = automatically archive/delete old log entries.
#   We implement a simple version: keep last 1000 lines.
#   Real systems use logrotate, but this works fine for our project.
#
# ============================================================================

section "STEP 4 — LOG ROTATION"

# Create the log file if it doesn't exist
touch "$LOG_FILE"

# Add a log rotation entry to cron (runs weekly)
LOG_ROTATE_CMD="tail -n 1000 $LOG_FILE > $LOG_FILE.tmp && mv $LOG_FILE.tmp $LOG_FILE"
ROTATE_ENTRY="# Weekly log rotation (keep last 1000 lines)
0 3 * * 0 $LOG_ROTATE_CMD"

if ! crontab -l 2>/dev/null | grep -q "log rotation"; then
    (crontab -l 2>/dev/null; echo "$ROTATE_ENTRY") | crontab -
    print_ok "Log rotation configured — weekly, keeps last 1000 lines"
else
    print_ok "Log rotation already configured"
fi

print_field "Log file"        "$LOG_FILE"
print_field "Rotation"        "Weekly (Sunday 03:00) — keep last 1000 lines"
print_field "Status JSON"     "$STATUS_JSON"
log_entry "INFO" "Log rotation configured"

# ============================================================================
# STEP 5 — VERIFY CRON IS RUNNING
# ============================================================================
#
# CONCEPT: The cron daemon must be active
#
#   Installing crontab entries does nothing if the cron daemon isn't running.
#   systemctl status cron  — checks if it's active
#   systemctl enable cron  — makes it start on boot
#   systemctl start cron   — starts it right now
#
# ============================================================================

section "STEP 5 — CRON DAEMON STATUS"

# Check if cron daemon is running
if systemctl is-active --quiet cron 2>/dev/null || \
   systemctl is-active --quiet crond 2>/dev/null; then
    print_ok "Cron daemon is ${G1}ACTIVE${NC} and running"
    log_entry "INFO" "Cron daemon: ACTIVE"
else
    print_warn "Cron daemon not running — attempting to start..."
    sudo systemctl enable cron 2>/dev/null || sudo systemctl enable crond 2>/dev/null
    sudo systemctl start  cron 2>/dev/null || sudo systemctl start  crond 2>/dev/null

    if systemctl is-active --quiet cron 2>/dev/null || \
       systemctl is-active --quiet crond 2>/dev/null; then
        print_ok "Cron daemon started successfully"
        log_entry "INFO" "Cron daemon: started by setup_cron.sh"
    else
        print_warn "Could not start cron daemon — try: sudo systemctl start cron"
        log_entry "WARN" "Cron daemon: failed to start"
    fi
fi

# Show current crontab for verification
echo ""
print_info "Current crontab (your scheduled jobs):"
echo ""
crontab -l 2>/dev/null | grep -v "^$" | while read -r line; do
    if [[ "$line" == \#* ]]; then
        echo -e "  ${DM}${line}${NC}"
    else
        echo -e "  ${G1}${line}${NC}"
    fi
done

# ============================================================================
# STEP 6 — TEST RUN
# ============================================================================
#
# CONCEPT: Verify the runner works before relying on cron
#
#   We offer to run the cron runner RIGHT NOW so you can see it work.
#   This is much better than waiting until 4AM to find out it's broken.
#
# ============================================================================

section "STEP 6 — TEST RUN"

echo ""
if (( GUI_MODE == 1 )); then
    print_info "GUI mode — skipping interactive test run prompt"
    print_info "To test manually: bash $RUNNER_SCRIPT"
else
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Run cron job NOW to test? ${DM}[y/n]${NC}: "
    read -r test_confirm

    if [[ "$test_confirm" =~ ^[Yy]$ ]]; then
        echo ""
        print_info "Running cron job immediately..."
        echo ""
        progress "Executing full pipeline  " 0.5
        echo ""

        bash "$RUNNER_SCRIPT"
        EXIT_CODE=$?

        echo ""
        if [ $EXIT_CODE -eq 0 ]; then
            print_ok "Test run completed successfully — all modules passed"
        else
            print_warn "Test run completed with $EXIT_CODE failure(s) — check $LOG_FILE"
        fi
    else
        print_info "Skipped — cron will run automatically at 04:00 AM"
    fi
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================

section "AUTOMATION COMPLETE"

echo ""
print_field "Runner script"    "$RUNNER_SCRIPT"
print_field "Log file"         "$LOG_FILE"
print_field "Status JSON"      "$STATUS_JSON"
print_field "Audit schedule"   "$AUDIT_DESC"
[ -n "$EMAIL_CRON" ] && print_field "Email schedule" "$EMAIL_DESC"
print_field "Cleanup"          "Every Sunday at midnight (auto)"
echo ""
print_info "Useful commands:"
echo -e "  ${G1}  crontab -l${NC}                        ${DM}# view all scheduled jobs${NC}"
echo -e "  ${G1}  crontab -r${NC}                        ${DM}# remove ALL cron jobs (careful!)${NC}"
echo -e "  ${G1}  bash $RUNNER_SCRIPT${NC}   ${DM}# test run now${NC}"
echo -e "  ${G1}  tail -f $LOG_FILE${NC}      ${DM}# watch log live${NC}"
echo -e "  ${G1}  cat $STATUS_JSON${NC}       ${DM}# last run status${NC}"
echo ""

# Write final log entry
log_entry "INFO" "setup_cron.sh completed successfully"
log_entry "INFO" "Next scheduled run: $(date -d 'tomorrow 04:00' '+%Y-%m-%d 04:00:00' 2>/dev/null || echo 'tomorrow at 04:00 AM')"

local fw=$(( TW < 12 ? 4 : TW - 6 ))
echo -e "${DM}$(repeat_char '═' $fw)${NC}"
center_print "${G0}Phase 4 Complete  |  $(date '+%H:%M:%S')  |  Cron automation active${NC}"
echo -e "${DM}$(repeat_char '═' $fw)${NC}"
echo ""