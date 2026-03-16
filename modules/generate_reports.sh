#!/bin/bash
################################################################################
# NSCS OS Project - Report Generation Module (HACKER EDITION)
# Phase 2 — Professional Multi-Format Report System
#
# Generates per requirement:
#   [a] Short Report  — Summary view  (.txt + .html + .json)
#   [b] Full Report   — Detailed view (.txt + .html + .json)
#   [c] PDF           — Via wkhtmltopdf (if installed)
#
# Output dir: ~/nscs_os_project/reports/
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

REPORT_DIR="$HOME/nscs_os_project/reports"
mkdir -p "$REPORT_DIR"
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
center_print "██████╗ ███████╗██████╗  ██████╗ ██████╗ ████████╗███████╗"
center_print "██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝"
center_print "██████╔╝█████╗  ██████╔╝██║   ██║██████╔╝   ██║   ███████╗"
center_print "██╔══██╗██╔══╝  ██╔═══╝ ██║   ██║██╔══██╗   ██║   ╚════██║"
center_print "██║  ██║███████╗██║     ╚██████╔╝██║  ██║   ██║   ███████║"
center_print "╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝"
echo -e "${NC}"
echo -e "${DM}"; center_print "$(repeat_char '═' $(( TW - 6 )))"; echo -e "${NC}"
center_print "${G0}NSCS — Multi-Format Report Generator  |  Phase 2  |  v2.0${NC}"
center_print "${DM}$(date '+%A %d %B %Y   %H:%M:%S')${NC}"
echo -e "${DM}"; center_print "$(repeat_char '═' $(( TW - 6 )))"; echo -e "${NC}"
echo ""
echo -en "  "; type_header ">>> INITIALIZING REPORT GENERATION ENGINE..."
progress "Locating audit data      " 0.7
progress "Parsing JSON sources     " 0.8
echo ""

# ============================================================================
# LOCATE LATEST JSON SOURCES
# ============================================================================

section "LOCATING AUDIT DATA"

latest_hw=$(ls -t "$REPORT_DIR"/hardware_report_*.json 2>/dev/null | head -1)
latest_sw=$(ls -t "$REPORT_DIR"/software_report_*.json  2>/dev/null | head -1)

if [[ -z "$latest_hw" || -z "$latest_sw" ]]; then
    print_err "Missing audit data — run Hardware & Software audits first!"
    echo ""
    exit 1
fi

print_field "Hardware Source" "$(basename "$latest_hw")"
print_field "Software Source" "$(basename "$latest_sw")"
print_ok "Audit data located"

# ============================================================================
# PARSE JSON DATA
# ============================================================================

section "PARSING DATA"

# Helper: extract JSON value by key (simple grep-based, no jq needed)
jval() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2>/dev/null | head -1 | cut -d: -f2- | tr -d '" '; }
jval2() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$2" 2>/dev/null | head -1 | cut -d: -f2- | tr -d '" ,}'; }

# Hardware fields
HW_TIMESTAMP=$(jval  "timestamp"      "$latest_hw")
HW_BOARD=$(    jval  "motherboard"    "$latest_hw")
HW_VENDOR=$(   jval  "manufacturer"   "$latest_hw")
HW_BIOS=$(     jval  "bios_version"   "$latest_hw")
HW_FIRMWARE=$( jval  "firmware_type"  "$latest_hw")
HW_CPU=$(      jval  "model"          "$latest_hw")
HW_ARCH=$(     jval  "architecture"   "$latest_hw")
HW_CORES=$(    jval2 "cores"          "$latest_hw")
HW_CACHE=$(    jval  "l3_cache"       "$latest_hw")
HW_VIRT=$(     jval  "virtualization" "$latest_hw")
HW_GPU=$(      jval  "device"         "$latest_hw")
HW_RAM_TOTAL=$(jval  "total"          "$latest_hw")
HW_RAM_USED=$( jval  "used"           "$latest_hw")
HW_RAM_FREE=$( jval  "free"           "$latest_hw")
HW_RAM_AVAIL=$(jval  "available"      "$latest_hw")
HW_RAM_PCT=$(  jval2 "usage_percent"  "$latest_hw")
HW_SWAP_TOT=$( jval  "swap_total"     "$latest_hw")
HW_SWAP_USED=$(jval  "swap_used"      "$latest_hw")
HW_HOSTNAME=$( jval  "hostname"       "$latest_hw")
HW_IFACES=$(   jval  "interfaces"     "$latest_hw")

# Software fields
SW_TIMESTAMP=$(jval  "timestamp"        "$latest_sw")
SW_OS=$(       jval  "name"             "$latest_sw")
SW_KERNEL=$(   jval  "kernel"           "$latest_sw")
SW_ARCH=$(     jval  "arch"             "$latest_sw")
SW_HOSTNAME=$( jval  "hostname"         "$latest_sw")
SW_UPTIME=$(   jval  "uptime"           "$latest_sw")
SW_USER=$(     jval  "current_user"     "$latest_sw")
SW_SUDO=$(     jval  "sudo_users"       "$latest_sw")
SW_ACCOUNTS=$( jval2 "total_accounts"   "$latest_sw")
SW_ROOT_SSH=$( jval  "root_ssh_login"   "$latest_sw")
SW_UPDATES=$(  jval2 "updates_available" "$latest_sw")
SW_PROCS=$(    jval2 "processes"        "$latest_sw")
SW_SERVICES=$( jval2 "running_services" "$latest_sw")
SW_FAILED=$(   jval2 "failed_services"  "$latest_sw")
SW_PKGS=$(     jval2 "packages"         "$latest_sw")
SW_PKG_MGR=$(  jval  "package_manager"  "$latest_sw")

HOSTNAME="${SW_HOSTNAME:-${HW_HOSTNAME:-$(hostname)}}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GEN_DATE=$(date '+%A %d %B %Y  %H:%M:%S')

print_field "Hostname"      "$HOSTNAME"
print_field "Generated"     "$GEN_DATE"
print_field "HW Audit Date" "$HW_TIMESTAMP"
print_field "SW Audit Date" "$SW_TIMESTAMP"
print_ok "All fields parsed successfully"

# ============================================================================
# [A] SHORT REPORT — TXT
# ============================================================================

section "GENERATING SHORT REPORT (TXT)"
progress "Writing short text report" 1.0

SHORT_TXT="$REPORT_DIR/report_short_${TIMESTAMP}.txt"

{
SEP="═══════════════════════════════════════════════════════════════"
DIV="───────────────────────────────────────────────────────────────"

echo "$SEP"
echo "       NSCS LINUX AUDIT SYSTEM — SHORT SUMMARY REPORT"
echo "$SEP"
printf "  %-20s %s\n"  "Generated:"  "$GEN_DATE"
printf "  %-20s %s\n"  "Hostname:"   "$HOSTNAME"
printf "  %-20s %s\n"  "Report Type:" "Short Summary (Key Metrics)"
echo "$SEP"

echo ""
echo "  [ HARDWARE OVERVIEW ]"
echo "  $DIV"
printf "  %-20s %s\n" "CPU:"        "$HW_CPU"
printf "  %-20s %s\n" "Cores:"      "$HW_CORES"
printf "  %-20s %s\n" "RAM Total:"  "$HW_RAM_TOTAL"
printf "  %-20s %s\n" "RAM Used:"   "$HW_RAM_USED  (${HW_RAM_PCT}%)"
printf "  %-20s %s\n" "GPU:"        "$HW_GPU"
printf "  %-20s %s\n" "Firmware:"   "$HW_FIRMWARE"

echo ""
echo "  [ SOFTWARE & OS ]"
echo "  $DIV"
printf "  %-20s %s\n" "OS:"         "$SW_OS"
printf "  %-20s %s\n" "Kernel:"     "$SW_KERNEL"
printf "  %-20s %s\n" "Uptime:"     "$SW_UPTIME"
printf "  %-20s %s\n" "Packages:"   "$SW_PKGS"

echo ""
echo "  [ SECURITY SNAPSHOT ]"
echo "  $DIV"
printf "  %-20s %s\n" "Current User:"  "$SW_USER"
printf "  %-20s %s\n" "Sudo Admins:"   "$SW_SUDO"
printf "  %-20s %s\n" "Root SSH:"      "$SW_ROOT_SSH"
printf "  %-20s %s\n" "Updates Avail:" "$SW_UPDATES"

echo ""
echo "$SEP"
echo "  NSCS OS Project © 2026 — Short Report — $GEN_DATE"
echo "$SEP"
} > "$SHORT_TXT"

print_ok "Short TXT saved → $(basename "$SHORT_TXT")"

# ============================================================================
# [B] FULL REPORT — TXT
# ============================================================================

section "GENERATING FULL REPORT (TXT)"
progress "Writing full text report " 1.2

FULL_TXT="$REPORT_DIR/report_full_${TIMESTAMP}.txt"

{
SEP="╔══════════════════════════════════════════════════════════════════╗"
SEP2="╚══════════════════════════════════════════════════════════════════╝"
MID="╠══════════════════════════════════════════════════════════════════╣"
DIV="  ──────────────────────────────────────────────────────────────"

echo "$SEP"
echo "║         NSCS LINUX AUDIT SYSTEM — FULL DETAILED REPORT          ║"
echo "$MID"
printf "║  %-20s %-43s║\n" "Generated:"  "$GEN_DATE"
printf "║  %-20s %-43s║\n" "Hostname:"   "$HOSTNAME"
printf "║  %-20s %-43s║\n" "Report Type:" "Full Technical Audit"
printf "║  %-20s %-43s║\n" "HW Source:"  "$(basename "$latest_hw")"
printf "║  %-20s %-43s║\n" "SW Source:"  "$(basename "$latest_sw")"
echo "$SEP2"

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │  SECTION 1 — PHYSICAL INFRASTRUCTURE (HARDWARE)             │"
echo "  └─────────────────────────────────────────────────────────────┘"
echo ""
echo "  1.1  Motherboard & BIOS"
echo "$DIV"
printf "  %-24s %s\n" "Board Name:"     "$HW_BOARD"
printf "  %-24s %s\n" "Manufacturer:"   "$HW_VENDOR"
printf "  %-24s %s\n" "BIOS Version:"   "$HW_BIOS"
printf "  %-24s %s\n" "Firmware Type:"  "$HW_FIRMWARE"
echo ""
echo "  1.2  Processor (CPU)"
echo "$DIV"
printf "  %-24s %s\n" "Model:"          "$HW_CPU"
printf "  %-24s %s\n" "Architecture:"   "$HW_ARCH"
printf "  %-24s %s\n" "Core Count:"     "$HW_CORES"
printf "  %-24s %s\n" "L3 Cache:"       "$HW_CACHE"
printf "  %-24s %s\n" "Virtualization:" "$HW_VIRT"
echo ""
echo "  1.3  Graphics (GPU)"
echo "$DIV"
printf "  %-24s %s\n" "GPU Device:"     "$HW_GPU"
echo ""
echo "  1.4  Memory (RAM)"
echo "$DIV"
printf "  %-24s %s\n" "Total:"          "$HW_RAM_TOTAL"
printf "  %-24s %s\n" "Used:"           "$HW_RAM_USED"
printf "  %-24s %s\n" "Free:"           "$HW_RAM_FREE"
printf "  %-24s %s\n" "Available:"      "$HW_RAM_AVAIL"
printf "  %-24s %s\n" "Usage Percent:"  "${HW_RAM_PCT}%"
printf "  %-24s %s\n" "Swap Total:"     "$HW_SWAP_TOT"
printf "  %-24s %s\n" "Swap Used:"      "$HW_SWAP_USED"
echo ""
echo "  1.5  Network"
echo "$DIV"
printf "  %-24s %s\n" "Hostname:"       "$HOSTNAME"
printf "  %-24s %s\n" "Interfaces:"     "$HW_IFACES"

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │  SECTION 2 — LOGICAL ENVIRONMENT (SOFTWARE & OS)            │"
echo "  └─────────────────────────────────────────────────────────────┘"
echo ""
echo "  2.1  Operating System"
echo "$DIV"
printf "  %-24s %s\n" "OS Name:"        "$SW_OS"
printf "  %-24s %s\n" "Kernel:"         "$SW_KERNEL"
printf "  %-24s %s\n" "Architecture:"   "$SW_ARCH"
printf "  %-24s %s\n" "Uptime:"         "$SW_UPTIME"
echo ""
echo "  2.2  Package Management"
echo "$DIV"
printf "  %-24s %s\n" "Package Manager:" "$SW_PKG_MGR"
printf "  %-24s %s\n" "Installed Pkgs:"  "$SW_PKGS"
printf "  %-24s %s\n" "Updates Pending:" "$SW_UPDATES"
echo ""
echo "  2.3  Processes & Services"
echo "$DIV"
printf "  %-24s %s\n" "Total Processes:"  "$SW_PROCS"
printf "  %-24s %s\n" "Running Services:" "$SW_SERVICES"
printf "  %-24s %s\n" "Failed Services:"  "$SW_FAILED"

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │  SECTION 3 — SECURITY ASSESSMENT                            │"
echo "  └─────────────────────────────────────────────────────────────┘"
echo ""
echo "  3.1  User Privilege Audit"
echo "$DIV"
printf "  %-24s %s\n" "Current User:"    "$SW_USER"
printf "  %-24s %s\n" "Sudo Admins:"     "$SW_SUDO"
printf "  %-24s %s\n" "Total Accounts:"  "$SW_ACCOUNTS"
printf "  %-24s %s\n" "Root SSH Login:"  "$SW_ROOT_SSH"
echo ""
echo "  3.2  Patch Status"
echo "$DIV"
printf "  %-24s %s\n" "Pending Updates:" "$SW_UPDATES"
if [[ "$SW_UPDATES" =~ ^[0-9]+$ ]] && (( SW_UPDATES > 0 )); then
    printf "  %-24s %s\n" "Risk Level:"  "MEDIUM — updates required"
else
    printf "  %-24s %s\n" "Risk Level:"  "LOW — system up to date"
fi

echo ""
echo "$SEP"
echo "║         NSCS OS Project © 2026 — Full Technical Report           ║"
printf "║  %-64s║\n" "Generated: $GEN_DATE"
echo "$SEP2"
} > "$FULL_TXT"

print_ok "Full TXT saved → $(basename "$FULL_TXT")"

# ============================================================================
# [C] SHORT REPORT — JSON
# ============================================================================

section "GENERATING JSON REPORTS"
progress "Writing summary JSON     " 0.7

SHORT_JSON="$REPORT_DIR/report_short_${TIMESTAMP}.json"
cat <<EOF > "$SHORT_JSON"
{
  "report_type": "short_summary",
  "generated": "$(date)",
  "hostname": "$HOSTNAME",
  "hardware": {
    "cpu": "$HW_CPU",
    "cores": "$HW_CORES",
    "ram_total": "$HW_RAM_TOTAL",
    "ram_used": "$HW_RAM_USED",
    "ram_percent": "$HW_RAM_PCT",
    "gpu": "$HW_GPU"
  },
  "software": {
    "os": "$SW_OS",
    "kernel": "$SW_KERNEL",
    "uptime": "$SW_UPTIME",
    "packages": "$SW_PKGS"
  },
  "security": {
    "current_user": "$SW_USER",
    "sudo_admins": "$SW_SUDO",
    "root_ssh": "$SW_ROOT_SSH",
    "updates_pending": "$SW_UPDATES"
  }
}
EOF
print_ok "Short JSON saved → $(basename "$SHORT_JSON")"

progress "Writing full JSON        " 0.7
FULL_JSON="$REPORT_DIR/report_full_${TIMESTAMP}.json"
cat <<EOF > "$FULL_JSON"
{
  "report_type": "full_audit",
  "generated": "$(date)",
  "hostname": "$HOSTNAME",
  "hardware": {
    "motherboard": { "name": "$HW_BOARD", "vendor": "$HW_VENDOR", "bios": "$HW_BIOS", "firmware": "$HW_FIRMWARE" },
    "cpu": { "model": "$HW_CPU", "arch": "$HW_ARCH", "cores": "$HW_CORES", "cache": "$HW_CACHE", "virt": "$HW_VIRT" },
    "gpu": { "device": "$HW_GPU" },
    "memory": { "total": "$HW_RAM_TOTAL", "used": "$HW_RAM_USED", "free": "$HW_RAM_FREE", "available": "$HW_RAM_AVAIL", "pct": "$HW_RAM_PCT", "swap_total": "$HW_SWAP_TOT", "swap_used": "$HW_SWAP_USED" },
    "network": { "hostname": "$HOSTNAME", "interfaces": "$HW_IFACES" }
  },
  "software": {
    "os": { "name": "$SW_OS", "kernel": "$SW_KERNEL", "arch": "$SW_ARCH", "uptime": "$SW_UPTIME" },
    "packages": { "manager": "$SW_PKG_MGR", "installed": "$SW_PKGS", "updates": "$SW_UPDATES" },
    "processes": { "total": "$SW_PROCS", "running_services": "$SW_SERVICES", "failed_services": "$SW_FAILED" }
  },
  "security": {
    "current_user": "$SW_USER",
    "sudo_admins": "$SW_SUDO",
    "total_accounts": "$SW_ACCOUNTS",
    "root_ssh_login": "$SW_ROOT_SSH",
    "updates_pending": "$SW_UPDATES"
  }
}
EOF
print_ok "Full JSON saved → $(basename "$FULL_JSON")"

# ============================================================================
# [D] HTML REPORTS — SHORT + FULL (Hacker Dashboard)
# ============================================================================

section "GENERATING HTML DASHBOARDS"
progress "Building HTML reports    " 1.4

SHORT_HTML="$REPORT_DIR/report_short_${TIMESTAMP}.html"
FULL_HTML="$REPORT_DIR/report_full_${TIMESTAMP}.html"

# ── Shared CSS ──────────────────────────────────────────────────────────────
HTML_CSS='
<style>
  @import url("https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@400;700&display=swap");
  *{margin:0;padding:0;box-sizing:border-box;}
  body{background:#000;color:#00ff41;font-family:"Share Tech Mono",monospace;padding:24px;}
  canvas#rain{position:fixed;top:0;left:0;width:100%;height:100%;opacity:.10;pointer-events:none;z-index:0;}
  .wrap{position:relative;z-index:1;max-width:960px;margin:0 auto;}
  .topbar{border:1px solid #005512;padding:16px 24px;margin-bottom:20px;background:rgba(0,20,0,.7);}
  .topbar h1{font-family:"Orbitron",monospace;font-size:1.1rem;color:#00ff41;letter-spacing:3px;text-shadow:0 0 10px #00ff41;}
  .topbar .meta{font-size:.75rem;color:#005512;margin-top:6px;line-height:1.8;}
  .topbar .meta span{color:#00cc33;}
  .section{border:1px solid #003a0a;margin-bottom:16px;background:rgba(0,15,0,.6);}
  .section-header{background:#030f03;border-bottom:1px solid #003a0a;padding:10px 16px;display:flex;align-items:center;gap:10px;}
  .section-header .num{font-family:"Orbitron",monospace;font-size:.75rem;color:#000;background:#00ff41;padding:2px 8px;}
  .section-header h2{font-size:.85rem;color:#00cc33;letter-spacing:2px;text-transform:uppercase;}
  .section-body{padding:16px;}
  table{width:100%;border-collapse:collapse;font-size:.8rem;}
  th{background:#010f01;color:#005512;text-align:left;padding:8px 12px;border-bottom:1px solid #003a0a;letter-spacing:1px;font-size:.72rem;}
  td{padding:8px 12px;border-bottom:1px solid #011501;color:#00cc33;}
  td.key{color:#005512;width:36%;}
  td.val{color:#00ff41;}
  td.warn{color:#ffcc00;}
  td.ok{color:#00ff41;}
  .badge{display:inline-block;padding:2px 10px;font-size:.7rem;border:1px solid;}
  .badge.ok{border-color:#00ff41;color:#00ff41;}
  .badge.warn{border-color:#ffcc00;color:#ffcc00;}
  .badge.err{border-color:#ff3333;color:#ff3333;}
  .rambar{height:8px;background:#001500;margin:4px 0;position:relative;}
  .rambar-fill{height:100%;background:linear-gradient(90deg,#003a0a,#00ff41);}
  .footer{text-align:center;font-size:.7rem;color:#003a0a;margin-top:20px;padding:10px;border-top:1px solid #003a0a;}
  .scanline{position:fixed;top:0;left:0;right:0;bottom:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,255,65,.012) 2px,rgba(0,255,65,.012) 4px);pointer-events:none;z-index:2;}
</style>
<script>
window.onload=function(){
  var c=document.getElementById("rain"),ctx=c.getContext("2d");
  c.width=window.innerWidth;c.height=window.innerHeight;
  var cols=Math.floor(c.width/14),drops=[];
  for(var i=0;i<cols;i++)drops[i]=1;
  var chars="ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎ0123456789ABCDEF";
  setInterval(function(){
    ctx.fillStyle="rgba(0,0,0,0.05)";ctx.fillRect(0,0,c.width,c.height);
    ctx.fillStyle="#00ff41";ctx.font="12px monospace";
    for(var i=0;i<drops.length;i++){
      var t=chars[Math.floor(Math.random()*chars.length)];
      ctx.fillText(t,i*14,drops[i]*14);
      if(drops[i]*14>c.height&&Math.random()>0.975)drops[i]=0;
      drops[i]++;
    }
  },55);
};
</script>'

# ── Security badge helper ────────────────────────────────────────────────────
get_update_badge() {
    if [[ "$SW_UPDATES" =~ ^[0-9]+$ ]] && (( SW_UPDATES > 0 )); then
        echo "<span class='badge warn'>$SW_UPDATES PENDING</span>"
    else
        echo "<span class='badge ok'>UP TO DATE</span>"
    fi
}
get_ssh_badge() {
    if [ "$SW_ROOT_SSH" = "yes" ]; then
        echo "<span class='badge err'>ENABLED — RISK</span>"
    else
        echo "<span class='badge ok'>${SW_ROOT_SSH:-N/A}</span>"
    fi
}

RAM_W=${HW_RAM_PCT:-0}

# ── SHORT HTML ───────────────────────────────────────────────────────────────
cat <<SHORTHTML > "$SHORT_HTML"
<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"><title>NSCS Short Report — $HOSTNAME</title>
$HTML_CSS
</head><body>
<canvas id="rain"></canvas><div class="scanline"></div>
<div class="wrap">
  <div class="topbar">
    <h1>[ NSCS ] SHORT AUDIT REPORT</h1>
    <div class="meta">
      <span>HOST:</span> $HOSTNAME &nbsp;|&nbsp;
      <span>GENERATED:</span> $GEN_DATE &nbsp;|&nbsp;
      <span>TYPE:</span> Summary View
    </div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">01</span><h2>Hardware Overview</h2></div>
    <div class="section-body">
      <table>
        <tr><th>COMPONENT</th><th>VALUE</th></tr>
        <tr><td class="key">CPU Model</td><td class="val">$HW_CPU</td></tr>
        <tr><td class="key">CPU Cores</td><td class="val">$HW_CORES</td></tr>
        <tr><td class="key">GPU</td><td class="val">$HW_GPU</td></tr>
        <tr><td class="key">RAM Total</td><td class="val">$HW_RAM_TOTAL</td></tr>
        <tr><td class="key">RAM Usage</td><td class="val">
          ${HW_RAM_PCT}%
          <div class="rambar"><div class="rambar-fill" style="width:${RAM_W}%"></div></div>
        </td></tr>
        <tr><td class="key">Firmware</td><td class="val">$HW_FIRMWARE</td></tr>
      </table>
    </div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">02</span><h2>Software & OS</h2></div>
    <div class="section-body">
      <table>
        <tr><th>ITEM</th><th>VALUE</th></tr>
        <tr><td class="key">OS</td><td class="val">$SW_OS</td></tr>
        <tr><td class="key">Kernel</td><td class="val">$SW_KERNEL</td></tr>
        <tr><td class="key">Uptime</td><td class="val">$SW_UPTIME</td></tr>
        <tr><td class="key">Packages</td><td class="val">$SW_PKGS</td></tr>
      </table>
    </div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">03</span><h2>Security Snapshot</h2></div>
    <div class="section-body">
      <table>
        <tr><th>CHECK</th><th>STATUS</th></tr>
        <tr><td class="key">Current User</td><td class="val">$SW_USER</td></tr>
        <tr><td class="key">Sudo Admins</td><td class="warn">$SW_SUDO</td></tr>
        <tr><td class="key">Root SSH Login</td><td>$(get_ssh_badge)</td></tr>
        <tr><td class="key">Pending Updates</td><td>$(get_update_badge)</td></tr>
      </table>
    </div>
  </div>

  <div class="footer">NSCS OS Project &copy; 2026 &mdash; Short Summary Report &mdash; $GEN_DATE</div>
</div></body></html>
SHORTHTML

print_ok "Short HTML saved → $(basename "$SHORT_HTML")"

# ── FULL HTML ────────────────────────────────────────────────────────────────
cat <<FULLHTML > "$FULL_HTML"
<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"><title>NSCS Full Report — $HOSTNAME</title>
$HTML_CSS
</head><body>
<canvas id="rain"></canvas><div class="scanline"></div>
<div class="wrap">
  <div class="topbar">
    <h1>[ NSCS ] FULL TECHNICAL AUDIT REPORT</h1>
    <div class="meta">
      <span>HOST:</span> $HOSTNAME &nbsp;|&nbsp;
      <span>GENERATED:</span> $GEN_DATE &nbsp;|&nbsp;
      <span>TYPE:</span> Full Detailed Audit &nbsp;|&nbsp;
      <span>HW SOURCE:</span> $(basename "$latest_hw") &nbsp;|&nbsp;
      <span>SW SOURCE:</span> $(basename "$latest_sw")
    </div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">1.1</span><h2>Motherboard &amp; BIOS</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Board Name</td><td class="val">$HW_BOARD</td></tr>
      <tr><td class="key">Manufacturer</td><td class="val">$HW_VENDOR</td></tr>
      <tr><td class="key">BIOS Version</td><td class="val">$HW_BIOS</td></tr>
      <tr><td class="key">Firmware Type</td><td class="val">$HW_FIRMWARE</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">1.2</span><h2>Processor (CPU)</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Model</td><td class="val">$HW_CPU</td></tr>
      <tr><td class="key">Architecture</td><td class="val">$HW_ARCH</td></tr>
      <tr><td class="key">Core Count</td><td class="val">$HW_CORES</td></tr>
      <tr><td class="key">L3 Cache</td><td class="val">$HW_CACHE</td></tr>
      <tr><td class="key">Virtualization</td><td class="val">$HW_VIRT</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">1.3</span><h2>GPU / Graphics</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">GPU Device</td><td class="val">$HW_GPU</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">1.4</span><h2>Memory (RAM)</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Total</td><td class="val">$HW_RAM_TOTAL</td></tr>
      <tr><td class="key">Used</td><td class="val">$HW_RAM_USED</td></tr>
      <tr><td class="key">Free</td><td class="val">$HW_RAM_FREE</td></tr>
      <tr><td class="key">Available</td><td class="val">$HW_RAM_AVAIL</td></tr>
      <tr><td class="key">Usage</td><td class="val">${HW_RAM_PCT}%
        <div class="rambar"><div class="rambar-fill" style="width:${RAM_W}%"></div></div>
      </td></tr>
      <tr><td class="key">Swap Total</td><td class="val">$HW_SWAP_TOT</td></tr>
      <tr><td class="key">Swap Used</td><td class="val">$HW_SWAP_USED</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">1.5</span><h2>Network</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Hostname</td><td class="val">$HOSTNAME</td></tr>
      <tr><td class="key">Interfaces</td><td class="val">$HW_IFACES</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">2.1</span><h2>Operating System</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">OS Name</td><td class="val">$SW_OS</td></tr>
      <tr><td class="key">Kernel</td><td class="val">$SW_KERNEL</td></tr>
      <tr><td class="key">Architecture</td><td class="val">$SW_ARCH</td></tr>
      <tr><td class="key">Uptime</td><td class="val">$SW_UPTIME</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">2.2</span><h2>Package Management</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Package Manager</td><td class="val">$SW_PKG_MGR</td></tr>
      <tr><td class="key">Installed</td><td class="val">$SW_PKGS</td></tr>
      <tr><td class="key">Updates Pending</td><td>$(get_update_badge)</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">2.3</span><h2>Processes &amp; Services</h2></div>
    <div class="section-body"><table>
      <tr><th>FIELD</th><th>VALUE</th></tr>
      <tr><td class="key">Total Processes</td><td class="val">$SW_PROCS</td></tr>
      <tr><td class="key">Running Services</td><td class="val">$SW_SERVICES</td></tr>
      <tr><td class="key">Failed Services</td><td class="$([ "${SW_FAILED:-0}" != "0" ] && echo warn || echo ok)">$SW_FAILED</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">3.1</span><h2>User &amp; Privilege Audit</h2></div>
    <div class="section-body"><table>
      <tr><th>CHECK</th><th>STATUS</th></tr>
      <tr><td class="key">Current User</td><td class="val">$SW_USER</td></tr>
      <tr><td class="key">Sudo Admins</td><td class="warn">$SW_SUDO</td></tr>
      <tr><td class="key">Total Accounts</td><td class="val">$SW_ACCOUNTS</td></tr>
      <tr><td class="key">Root SSH Login</td><td>$(get_ssh_badge)</td></tr>
    </table></div>
  </div>

  <div class="section">
    <div class="section-header"><span class="num">3.2</span><h2>Patch &amp; Update Status</h2></div>
    <div class="section-body"><table>
      <tr><th>CHECK</th><th>STATUS</th></tr>
      <tr><td class="key">Pending Updates</td><td>$(get_update_badge)</td></tr>
      <tr><td class="key">Risk Level</td><td class="$([ "${SW_UPDATES:-0}" != "0" ] && echo warn || echo ok)">
        $([ "${SW_UPDATES:-0}" != "0" ] && echo "MEDIUM — updates required" || echo "LOW — system up to date")
      </td></tr>
    </table></div>
  </div>

  <div class="footer">NSCS OS Project &copy; 2026 &mdash; Full Technical Report &mdash; $GEN_DATE</div>
</div></body></html>
FULLHTML

print_ok "Full HTML saved → $(basename "$FULL_HTML")"

# ============================================================================
# [E] PDF (via wkhtmltopdf if available)
# ============================================================================

section "GENERATING PDF REPORTS"

if command -v wkhtmltopdf &>/dev/null; then
    progress "Rendering PDF (short)    " 2.0
    SHORT_PDF="$REPORT_DIR/report_short_${TIMESTAMP}.pdf"
    wkhtmltopdf --quiet --page-size A4 "$SHORT_HTML" "$SHORT_PDF" 2>/dev/null
    print_ok "Short PDF saved → $(basename "$SHORT_PDF")"

    progress "Rendering PDF (full)     " 2.5
    FULL_PDF="$REPORT_DIR/report_full_${TIMESTAMP}.pdf"
    wkhtmltopdf --quiet --page-size A4 "$FULL_HTML" "$FULL_PDF" 2>/dev/null
    print_ok "Full PDF saved → $(basename "$FULL_PDF")"
else
    print_warn "wkhtmltopdf not found — install it for PDF export:"
    print_info "  sudo apt install wkhtmltopdf"
    print_info "PDFs skipped — all other formats saved successfully."
fi

# ============================================================================
# SUMMARY
# ============================================================================

section "REPORT SUMMARY"

echo ""
echo -e "  ${DM}All reports saved to:${NC} ${G1}$REPORT_DIR${NC}"
echo ""
echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"
printf "  ${DM}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "FORMAT" "FILENAME" "TYPE"
echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "TXT"  "$(basename "$SHORT_TXT")"  "Short Summary"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "TXT"  "$(basename "$FULL_TXT")"   "Full Detailed"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "JSON" "$(basename "$SHORT_JSON")" "Short Summary"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "JSON" "$(basename "$FULL_JSON")"  "Full Detailed"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "HTML" "$(basename "$SHORT_HTML")" "Short Dashboard"
printf "  ${WH}%-8s${NC} ${G1}%-42s${NC} ${DM}%s${NC}\n" "HTML" "$(basename "$FULL_HTML")"  "Full Dashboard"
echo -e "  ${G0}$(repeat_char '─' $(( TW - 6 )))${NC}"
echo ""

print_ok "Report generation complete — ${G1}6 files${NC} created"
echo ""
echo -e "${DM}"; repeat_char '▀' $TW; echo -e "${NC}"
center_print "${G0}Phase 2 Complete  |  $(date '+%H:%M:%S')  |  All formats saved${NC}"
echo -e "${DM}"; repeat_char '▄' $TW; echo -e "${NC}"
echo ""