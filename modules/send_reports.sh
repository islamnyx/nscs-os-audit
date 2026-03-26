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

_print_ascii_art() {
    center_print "███████╗███╗   ███╗ █████╗ ██╗██╗"
    center_print "██╔════╝████╗ ████║██╔══██╗██║██║"
    center_print "█████╗  ██╔████╔██║███████║██║██║"
    center_print "██╔══╝  ██║╚██╔╝██║██╔══██║██║██║"
    center_print "███████╗██║ ╚═╝ ██║██║  ██║██║███████╗"
    center_print "╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚══════╝"
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
# HEADER
# ============================================================================

clear
print_banner "EMAIL" "Secure Email Transmission  |  Phase 3  |  SMTP/TLS"
type_header ">>> INITIALIZING SECURE SMTP CHANNEL..."
progress "Loading Python mailer    " 0.7
progress "Scanning report files    " 0.6
echo ""

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

echo -e "${DM}"; divider '═'; echo -e "${NC}"
center_print "${G0}Phase 3 Complete  |  $(date '+%H:%M:%S')${NC}"
echo -e "${DM}"; divider '▄'; echo -e "${NC}"
echo ""