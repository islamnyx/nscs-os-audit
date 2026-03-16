#!/bin/bash
################################################################################
# NSCS OS Project - Email Transmission Module (HACKER EDITION)
# Phase 3 — Secure SMTP Report Delivery via Python/Gmail
#
# HOW IT WORKS:
#   Instead of relying on a local mail daemon (sendmail/postfix),
#   this script uses Python's smtplib to open a direct TLS connection
#   to Gmail's SMTP server (smtp.gmail.com:587), authenticate with
#   an App Password, attach all generated report files, and send.
#
#   Requirements:
#     - Python 3 (pre-installed on Kali/Ubuntu)
#     - A Gmail account with 2FA enabled
#     - A Gmail App Password (NOT your real password)
#       → myaccount.google.com > Security > App Passwords
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
# PATHS & CONFIG
# ============================================================================

REPORT_DIR="$HOME/nscs_os_project/reports"
CONFIG_DIR="$HOME/nscs_os_project"
CONFIG_FILE="$CONFIG_DIR/email.conf"
mkdir -p "$REPORT_DIR" "$CONFIG_DIR"

TW=$(tput cols 2>/dev/null || echo 80)

GUI_MODE=0
for arg in "$@"; do [[ "$arg" == "--gui" ]] && GUI_MODE=1; done

# ============================================================================
# UTILITIES
# ============================================================================

repeat_char() { printf "%${2}s" | tr ' ' "$1"; }

center_print() {
    local text="$1"
    local clean; clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#clean}; local pad=$(( (TW - len) / 2 ))
    printf "%${pad}s"; echo -e "$text"
}

section() {
    local title="$1"; local tlen=${#title}
    local side=$(( (TW - tlen - 4) / 2 )); (( side < 1 )) && side=1
    echo ""
    echo -en "${G0}"; repeat_char '─' $side
    echo -en "${NC} ${G1}${BOLD}${title}${NC} ${G0}"; repeat_char '─' $side
    echo -e "${NC}"
}

print_field() { printf "  ${DM}%-24s${NC} ${G1}▶${NC} ${WH}%s${NC}\n" "$1" "$2"; }
print_ok()    { echo -e "  ${G1}[  OK  ]${NC}  $1"; }
print_warn()  { echo -e "  ${YW}[  !!  ]${NC}  $1"; }
print_info()  { echo -e "  ${G0}[  **  ]${NC}  $1"; }
print_err()   { echo -e "  ${RD}[  ✗✗  ]${NC}  $1"; }

progress() {
    local label="$1" duration="${2:-1.0}"
    local width=$(( TW - 20 )); (( width > 50 )) && width=50; (( width < 10 )) && width=10
    echo -en "  ${DM}${label}${NC} ${G0}["
    local t; t=$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.03")
    for ((i=0; i<width; i++)); do
        (( i < width/3 ))                   && echo -en "${DM}█${NC}"
        (( i >= width/3 && i < width*2/3 )) && echo -en "${G0}█${NC}"
        (( i >= width*2/3 ))                && echo -en "${G1}█${NC}"
        sleep "$t"
    done
    echo -e "${G1}]${NC}"
}

type_header() {
    echo -en "${G1}"
    while IFS= read -r -n1 c; do echo -n "$c"; sleep 0.018; done <<< "$1"
    echo -e "${NC}"
}

# ============================================================================
# HEADER
# ============================================================================

clear
echo -e "${DM}"; repeat_char '▄' $TW; echo -e "${NC}"
echo -e "${G1}"
center_print "███████╗███╗   ███╗ █████╗ ██╗██╗"
center_print "██╔════╝████╗ ████║██╔══██╗██║██║"
center_print "█████╗  ██╔████╔██║███████║██║██║"
center_print "██╔══╝  ██║╚██╔╝██║██╔══██║██║██║"
center_print "███████╗██║ ╚═╝ ██║██║  ██║██║███████╗"
center_print "╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚══════╝"
echo -e "${NC}"
echo -e "${DM}"; center_print "$(repeat_char '═' $(( TW - 6 )))"; echo -e "${NC}"
center_print "${G0}NSCS — Secure Email Transmission  |  Phase 3  |  SMTP/TLS${NC}"
center_print "${DM}$(date '+%A %d %B %Y   %H:%M:%S')${NC}"
echo -e "${DM}"; center_print "$(repeat_char '═' $(( TW - 6 )))"; echo -e "${NC}"
echo ""
echo -en "  "; type_header ">>> INITIALIZING SECURE SMTP CHANNEL..."
progress "Loading Python mailer    " 0.7
progress "Scanning report files    " 0.6
echo ""

# ============================================================================
# CHECK PYTHON
# ============================================================================

section "DEPENDENCY CHECK"

if ! command -v python3 &>/dev/null; then
    print_err "Python3 not found — install with: sudo apt install python3"
    exit 1
fi
PY_VER=$(python3 --version 2>&1)
print_ok "Python3 found: ${G1}$PY_VER${NC}"
print_ok "smtplib — built-in (no pip needed)"
print_ok "All dependencies satisfied"

# ============================================================================
# FIND REPORT FILES
# ============================================================================

section "AVAILABLE REPORTS"

# Gather latest of each type
F_SHORT_TXT=$(ls -t  "$REPORT_DIR"/report_short_*.txt   2>/dev/null | head -1)
F_FULL_TXT=$( ls -t  "$REPORT_DIR"/report_full_*.txt    2>/dev/null | head -1)
F_SHORT_HTML=$(ls -t "$REPORT_DIR"/report_short_*.html  2>/dev/null | head -1)
F_FULL_HTML=$( ls -t "$REPORT_DIR"/report_full_*.html   2>/dev/null | head -1)
F_SHORT_JSON=$(ls -t "$REPORT_DIR"/report_short_*.json  2>/dev/null | head -1)
F_FULL_JSON=$( ls -t "$REPORT_DIR"/report_full_*.json   2>/dev/null | head -1)
F_SHORT_PDF=$( ls -t "$REPORT_DIR"/report_short_*.pdf   2>/dev/null | head -1)
F_FULL_PDF=$(  ls -t "$REPORT_DIR"/report_full_*.pdf    2>/dev/null | head -1)

# Check at least one report exists
if [[ -z "$F_SHORT_TXT" && -z "$F_FULL_TXT" ]]; then
    print_err "No reports found in $REPORT_DIR"
    print_info "Run Option 3 (Generate Reports) first!"
    exit 1
fi

# Show available files
[[ -n "$F_SHORT_TXT"  ]] && print_field "Short TXT"   "$(basename "$F_SHORT_TXT")"
[[ -n "$F_FULL_TXT"   ]] && print_field "Full TXT"    "$(basename "$F_FULL_TXT")"
[[ -n "$F_SHORT_HTML" ]] && print_field "Short HTML"  "$(basename "$F_SHORT_HTML")"
[[ -n "$F_FULL_HTML"  ]] && print_field "Full HTML"   "$(basename "$F_FULL_HTML")"
[[ -n "$F_SHORT_JSON" ]] && print_field "Short JSON"  "$(basename "$F_SHORT_JSON")"
[[ -n "$F_FULL_JSON"  ]] && print_field "Full JSON"   "$(basename "$F_FULL_JSON")"
[[ -n "$F_SHORT_PDF"  ]] && print_field "Short PDF"   "$(basename "$F_SHORT_PDF")"
[[ -n "$F_FULL_PDF"   ]] && print_field "Full PDF"    "$(basename "$F_FULL_PDF")"
echo ""
print_ok "Report files located"

# ============================================================================
# LOAD OR CREATE CONFIG
# ============================================================================

section "SMTP CONFIGURATION"

# If config file exists, load it
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    print_ok "Config loaded from $CONFIG_FILE"
    print_field "Sender (Gmail)"  "$SMTP_FROM"
    print_field "SMTP Server"     "smtp.gmail.com:587 (STARTTLS)"
    echo ""
    echo -en "  ${G0}Use saved config? ${DM}[y/n]${NC}: "
    read -r use_saved
    if [[ ! "$use_saved" =~ ^[Yy]$ ]]; then
        rm -f "$CONFIG_FILE"
    fi
fi

# If no saved config (or user rejected it), ask for credentials
if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo -e "  ${YW}SETUP: Gmail App Password required${NC}"
    echo -e "  ${DM}How to get one:${NC}"
    echo -e "  ${DM}  1. Go to myaccount.google.com${NC}"
    echo -e "  ${DM}  2. Security → 2-Step Verification (must be ON)${NC}"
    echo -e "  ${DM}  3. Search 'App Passwords' → Create one for 'Mail'${NC}"
    echo -e "  ${DM}  4. Copy the 16-char password below${NC}"
    echo ""

    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Sender Gmail address : "
    read -r SMTP_FROM
    echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Gmail App Password   : "
    read -rs SMTP_PASS
    echo ""

    # Validate basic input
    if [[ -z "$SMTP_FROM" || -z "$SMTP_PASS" ]]; then
        print_err "Email and password cannot be empty."
        exit 1
    fi

    echo -en "  ${G0}Save credentials for future use? ${DM}[y/n]${NC}: "
    read -r save_creds
    if [[ "$save_creds" =~ ^[Yy]$ ]]; then
        cat <<EOF > "$CONFIG_FILE"
# NSCS Email Configuration — saved $(date)
SMTP_FROM="$SMTP_FROM"
SMTP_PASS="$SMTP_PASS"
EOF
        chmod 600 "$CONFIG_FILE"
        print_ok "Credentials saved (chmod 600) → $CONFIG_FILE"
    fi
fi

# ============================================================================
# RECIPIENT & SUBJECT
# ============================================================================

section "TRANSMISSION DETAILS"

echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Recipient email      : "
read -r SMTP_TO
if [[ -z "$SMTP_TO" ]]; then
    print_err "Recipient cannot be empty."
    exit 1
fi

echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Email subject        : "
read -r SMTP_SUBJECT
if [[ -z "$SMTP_SUBJECT" ]]; then
    SMTP_SUBJECT="NSCS System Audit Report — $(hostname) — $(date '+%Y-%m-%d')"
fi

# Which attachments to send
echo ""
echo -e "  ${G0}Select attachments to send:${NC}"
echo -e "  ${DM}  [1] Short reports only (TXT + HTML)${NC}"
echo -e "  ${DM}  [2] Full reports only  (TXT + HTML)${NC}"
echo -e "  ${DM}  [3] All formats        (everything found)${NC}"
echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Choice [1/2/3]        : "
read -r attach_choice

# Build attachment list
ATTACHMENTS=()
case "$attach_choice" in
    1)
        [[ -n "$F_SHORT_TXT"  ]] && ATTACHMENTS+=("$F_SHORT_TXT")
        [[ -n "$F_SHORT_HTML" ]] && ATTACHMENTS+=("$F_SHORT_HTML")
        [[ -n "$F_SHORT_JSON" ]] && ATTACHMENTS+=("$F_SHORT_JSON")
        ;;
    2)
        [[ -n "$F_FULL_TXT"   ]] && ATTACHMENTS+=("$F_FULL_TXT")
        [[ -n "$F_FULL_HTML"  ]] && ATTACHMENTS+=("$F_FULL_HTML")
        [[ -n "$F_FULL_JSON"  ]] && ATTACHMENTS+=("$F_FULL_JSON")
        ;;
    *)
        for f in "$F_SHORT_TXT" "$F_FULL_TXT" "$F_SHORT_HTML" "$F_FULL_HTML" \
                 "$F_SHORT_JSON" "$F_FULL_JSON" "$F_SHORT_PDF" "$F_FULL_PDF"; do
            [[ -n "$f" ]] && ATTACHMENTS+=("$f")
        done
        ;;
esac

echo ""
print_field "From"        "$SMTP_FROM"
print_field "To"          "$SMTP_TO"
print_field "Subject"     "$SMTP_SUBJECT"
print_field "Attachments" "${#ATTACHMENTS[@]} files"
for f in "${ATTACHMENTS[@]}"; do
    echo -e "              ${DM}▸ $(basename "$f")${NC}"
done

# ============================================================================
# SEND VIA PYTHON SMTPLIB
# ============================================================================

section "TRANSMITTING"

echo ""
echo -en "  ${G1}[CONFIRM]${NC}  Send now? ${DM}[y/n]${NC}: "
read -r send_confirm
if [[ ! "$send_confirm" =~ ^[Yy]$ ]]; then
    print_warn "Transmission cancelled by user."
    exit 0
fi

echo ""
progress "Opening TLS connection   " 1.2
progress "Authenticating SMTP      " 0.8

# Build Python attachment args
ATTACH_ARGS=""
for f in "${ATTACHMENTS[@]}"; do
    ATTACH_ARGS+="\"$f\", "
done
ATTACH_ARGS="[${ATTACH_ARGS%, }]"

# Build body text (embed short TXT report as body if available)
BODY_TEXT="NSCS Linux Audit System — Automated Report\n\nHostname: $(hostname)\nGenerated: $(date)\n\nPlease find the attached audit reports.\n\nSections included:\n  - Hardware Inventory (CPU, RAM, GPU, Disk, Network)\n  - Software & OS Audit\n  - Security Assessment\n\nNSCS OS Project © 2026"

# Run Python mailer
python3 - <<PYEOF
import smtplib, ssl, os, sys
from email.mime.multipart import MIMEMultipart
from email.mime.text      import MIMEText
from email.mime.base      import MIMEBase
from email                import encoders

smtp_from    = "$SMTP_FROM"
smtp_pass    = "$SMTP_PASS"
smtp_to      = "$SMTP_TO"
subject      = "$SMTP_SUBJECT"
body         = "$BODY_TEXT"
attachments  = $ATTACH_ARGS

# ── Build message ────────────────────────────────────────────────────
msg = MIMEMultipart()
msg["From"]    = f"NSCS Audit System <{smtp_from}>"
msg["To"]      = smtp_to
msg["Subject"] = subject
msg.attach(MIMEText(body.replace("\\n", "\n"), "plain"))

# ── Attach files ─────────────────────────────────────────────────────
attached = []
for path in attachments:
    if not os.path.isfile(path):
        print(f"  [WARN] Skipping missing file: {path}")
        continue
    with open(path, "rb") as f:
        part = MIMEBase("application", "octet-stream")
        part.set_payload(f.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition",
                    f'attachment; filename="{os.path.basename(path)}"')
    msg.attach(part)
    attached.append(os.path.basename(path))
    print(f"  [  **  ]  Attached: {os.path.basename(path)}")

# ── Connect & send ────────────────────────────────────────────────────
print(f"\n  [  >>  ]  Connecting to smtp.gmail.com:587 ...")
try:
    context = ssl.create_default_context()
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as server:
        server.ehlo()
        server.starttls(context=context)        # Upgrade to TLS
        server.ehlo()
        server.login(smtp_from, smtp_pass)      # Authenticate
        server.sendmail(smtp_from, smtp_to, msg.as_string())

    print(f"  [  OK  ]  TLS handshake successful")
    print(f"  [  OK  ]  Authenticated as: {smtp_from}")
    print(f"  [  OK  ]  Message delivered to: {smtp_to}")
    print(f"  [  OK  ]  {len(attached)} attachments sent")
    print(f"  [  ✓   ]  TRANSMISSION COMPLETE")
    sys.exit(0)

except smtplib.SMTPAuthenticationError:
    print("  [  ✗✗  ]  AUTH FAILED — check App Password")
    print("  [  !!  ]  Make sure 2FA is ON and you used an App Password")
    print("  [  !!  ]  NOT your regular Gmail password")
    sys.exit(1)
except smtplib.SMTPException as e:
    print(f"  [  ✗✗  ]  SMTP error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"  [  ✗✗  ]  Connection failed: {e}")
    sys.exit(1)
PYEOF

EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    print_ok "Email delivered — check inbox of ${G1}$SMTP_TO${NC}"
else
    print_err "Transmission failed — see error above"
    echo ""
    echo -e "  ${YW}Troubleshooting:${NC}"
    print_info "1. Enable 2-Step Verification on your Google account"
    print_info "2. Create an App Password at myaccount.google.com"
    print_info "3. Use the 16-char App Password — NOT your Gmail password"
    print_info "4. Check internet connectivity: ping smtp.gmail.com"
    echo ""
fi

echo -e "${DM}"; repeat_char '▀' $TW; echo -e "${NC}"
center_print "${G0}Phase 3 Complete  |  $(date '+%H:%M:%S')${NC}"
echo -e "${DM}"; repeat_char '▄' $TW; echo -e "${NC}"
echo ""