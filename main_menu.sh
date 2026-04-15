#!/bin/bash
################################################################################
# NSCS OS PROJECT — Terminal Main Menu
# Organizes all 6 audit modules in a clean interactive terminal UI
################################################################################

# ============================================================================
# COLORS
# ============================================================================
G0='\033[0;32m'
G1='\033[1;32m'
CY='\033[0;36m'
YW='\033[1;33m'
RD='\033[1;31m'
WH='\033[1;37m'
DM='\033[2;32m'
BL='\033[0;34m'
MG='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================================
# PATHS — auto-detect relative to this script
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
REPORT_DIR="$HOME/nscs-os-audit/reports"

# ============================================================================
# TERMINAL WIDTH
# ============================================================================
_get_tw() { tput cols 2>/dev/null || echo 80; }
TW=$(_get_tw)
(( TW < 50  )) && TW=50
(( TW > 120 )) && TW=120

repeat_char() {
    local char="$1" count="$2"
    (( count <= 0 )) && return
    printf "%${count}s" | tr ' ' "$char"
}

divider() {
    local char="${1:-─}" color="${2:-$DM}"
    local w=$(( TW - 2 ))
    echo -e "${color}$(repeat_char "$char" $w)${NC}"
}

center_print() {
    local raw="$1"
    local clean; clean=$(printf '%b' "$raw" | sed 's/\x1b\[[0-9;]*[mKHABCDEFGJSTfu]//g')
    local len=${#clean}
    local pad=$(( (TW - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%${pad}s" ""
    echo -e "$raw"
}

print_ok()   { echo -e "  ${G1}[ OK ]${NC}  $1"; }
print_warn() { echo -e "  ${YW}[ !! ]${NC}  $1"; }
print_info() { echo -e "  ${CY}[ ** ]${NC}  $1"; }
print_err()  { echo -e "  ${RD}[ XX ]${NC}  $1"; }

# ============================================================================
# CHECK SCRIPT EXISTS
# ============================================================================
check_script() {
    local script="$MODULES_DIR/$1"
    if [[ -f "$script" ]]; then
        echo -e "${G1}✔${NC}"
        return 0
    else
        echo -e "${RD}✘${NC}"
        return 1
    fi
}

# ============================================================================
# HEADER
# ============================================================================
draw_header() {
    clear
    echo ""
    divider '═' "$G1"
    echo ""
    center_print "${G1}${BOLD} ███╗   ██╗███████╗ ██████╗███████╗${NC}"
    center_print "${G1}${BOLD} ████╗  ██║██╔════╝██╔════╝██╔════╝${NC}"
    center_print "${G1}${BOLD} ██╔██╗ ██║███████╗██║     ███████╗${NC}"
    center_print "${G0}${BOLD} ██║╚██╗██║╚════██║██║     ╚════██║${NC}"
    center_print "${G0}${BOLD} ██║ ╚████║███████║╚██████╗███████║${NC}"
    center_print "${DM}${BOLD} ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚══════╝${NC}"
    echo ""
    center_print "${WH}OS PROJECT — COMMAND CENTER  ${DM}v2.0${NC}"
    center_print "${DM}$(date '+%A  %d %B %Y   %H:%M:%S')${NC}"
    center_print "${DM}HOST: $(hostname)   USER: $(whoami)${NC}"
    echo ""
    divider '═' "$G1"
    echo ""
}

# ============================================================================
# STATUS BAR — shows report count + module availability
# ============================================================================
draw_status() {
    local report_count=0
    [[ -d "$REPORT_DIR" ]] && report_count=$(ls "$REPORT_DIR"/*.json 2>/dev/null | wc -l)

    local col_w=$(( (TW - 6) / 3 ))

    printf "  ${DM}%-${col_w}s${NC}  ${DM}%-${col_w}s${NC}  ${DM}%-${col_w}s${NC}\n" \
        "MODULES DIR: ${MODULES_DIR##*/}" \
        "REPORTS: $report_count saved" \
        "STATUS: ONLINE"
    echo ""
    divider '─' "$DM"
    echo ""
}

# ============================================================================
# MODULE MENU TABLE
# ============================================================================

declare -A MOD_SCRIPTS=(
    [1]="audit_hardware_v2.sh"
    [2]="audit_software.sh"
    [3]="generate_reports.sh"
    [4]="send_reports.sh"
    [5]="setup_cron.sh"
    [6]="remote_monitor.sh"
)

declare -A MOD_LABELS=(
    [1]="HARDWARE AUDIT"
    [2]="SOFTWARE AUDIT"
    [3]="GENERATE REPORTS"
    [4]="SEND REPORTS"
    [5]="CRON AUTOMATION"
    [6]="REMOTE MONITOR"
)

declare -A MOD_SUBTITLES=(
    [1]="Phase 1  ·  DMI / SMBIOS / CPU / GPU / RAM"
    [2]="Phase 1  ·  OS / Packages / Services / Security"
    [3]="Phase 2  ·  TXT / JSON / HTML / PDF"
    [4]="Phase 3  ·  SMTP / TLS / Gmail"
    [5]="Phase 4  ·  Scheduling / Logging / Failure Handling"
    [6]="Phase 5  ·  SSH / SCP / Centralized Reports"
)

declare -A MOD_COLORS=(
    [1]="$G1"
    [2]="$CY"
    [3]="$YW"
    [4]="${WH}"
    [5]="$MG"
    [6]="$RD"
)

draw_menu() {
    local label_w=20
    local sub_w=$(( TW - label_w - 18 ))
    (( sub_w < 20 )) && sub_w=20

    # Table header
    printf "  ${DM}%-4s  %-${label_w}s  %-${sub_w}s  %s${NC}\n" \
        "KEY" "MODULE" "DESCRIPTION" "STATUS"
    divider '─' "$DM"

    for i in 1 2 3 4 5 6; do
        local color="${MOD_COLORS[$i]}"
        local label="${MOD_LABELS[$i]}"
        local sub="${MOD_SUBTITLES[$i]}"
        local script="${MOD_SCRIPTS[$i]}"

        # Truncate subtitle if terminal is narrow
        if (( ${#sub} > sub_w )); then
            sub="${sub:0:$((sub_w-3))}..."
        fi

        # Check script availability
        local status
        if [[ -f "$MODULES_DIR/$script" ]]; then
            status="${G1}[READY]${NC}"
        else
            status="${DM}[MISSING]${NC}"
        fi

        printf "  ${color}[F${i}]${NC}  ${color}${BOLD}%-${label_w}s${NC}  ${DM}%-${sub_w}s${NC}  " \
            "$label" "$sub"
        echo -e "$status"
    done

    echo ""
    divider '─' "$DM"
    echo ""

    # Bottom key hints
    printf "  ${DM}%-20s${NC}  ${DM}%-20s${NC}  ${DM}%-20s${NC}\n" \
        "[1-6]  Run module" \
        "[L]    List reports" \
        "[Q]    Quit"
    echo ""
    divider '═' "$G1"
    echo ""
}

# ============================================================================
# LAUNCH MODULE
# ============================================================================
launch_module() {
    local id="$1"
    local script="$MODULES_DIR/${MOD_SCRIPTS[$id]}"
    local label="${MOD_LABELS[$id]}"
    local color="${MOD_COLORS[$id]}"

    clear
    echo ""
    divider '═' "${color}"
    center_print "${color}${BOLD}  LAUNCHING  MODULE  0${id}  —  ${label}  ${NC}"
    divider '═' "${color}"
    echo ""
    print_info "Script : ${MOD_SCRIPTS[$id]}"
    print_info "Path   : $script"
    print_info "Time   : $(date '+%H:%M:%S')"
    echo ""
    divider '─' "$DM"
    echo ""

    if [[ ! -f "$script" ]]; then
        print_err "Script not found: $script"
        print_warn "Place your .sh files in: $MODULES_DIR/"
        echo ""
        read -rp "  Press ENTER to return to menu..." _
        return
    fi

    chmod +x "$script"
    bash "$script"

    echo ""
    divider '─' "$DM"
    print_ok "Module ${label} finished."
    echo ""
    read -rp "  Press ENTER to return to menu..." _
}

# ============================================================================
# LIST REPORTS
# ============================================================================
list_reports() {
    clear
    echo ""
    divider '═' "$CY"
    center_print "${CY}${BOLD}  SAVED REPORTS  ${NC}"
    divider '═' "$CY"
    echo ""

    if [[ ! -d "$REPORT_DIR" ]]; then
        print_warn "Reports directory not found: $REPORT_DIR"
        echo ""
        read -rp "  Press ENTER to return..." _
        return
    fi

    local files=("$REPORT_DIR"/*.json "$REPORT_DIR"/*.txt "$REPORT_DIR"/*.html "$REPORT_DIR"/*.pdf)
    local found=0

    printf "  ${DM}%-10s  %-45s  %s${NC}\n" "TYPE" "FILENAME" "SIZE"
    divider '─' "$DM"

    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        found=1
        local ext="${f##*.}"
        local name="${f##*/}"
        local size
        size=$(du -sh "$f" 2>/dev/null | awk '{print $1}')

        case "$ext" in
            json) color="$G1"  ;;
            txt)  color="$WH"  ;;
            html) color="$CY"  ;;
            pdf)  color="$YW"  ;;
            *)    color="$DM"  ;;
        esac

        printf "  ${color}%-10s${NC}  %-45s  %s\n" \
            "[$ext]" "$name" "$size"
    done

    if (( found == 0 )); then
        print_warn "No reports found in $REPORT_DIR"
        print_info "Run modules 1-2 first to generate data, then module 3 to build reports."
    fi

    echo ""
    divider '═' "$CY"
    echo ""
    read -rp "  Press ENTER to return to menu..." _
}

# ============================================================================
# MAIN LOOP
# ============================================================================
main() {
    # Ensure modules dir exists
    mkdir -p "$MODULES_DIR"
    mkdir -p "$REPORT_DIR"

    while true; do
        draw_header
        draw_status
        draw_menu

        echo -en "  ${G1}root@nscs-audit${NC}:${G0}~${NC}${DM}\$${NC} Select module ${DM}[1-6 / L / Q]${NC}: "
        read -r choice

        case "${choice^^}" in
            1|F1) launch_module 1 ;;
            2|F2) launch_module 2 ;;
            3|F3) launch_module 3 ;;
            4|F4) launch_module 4 ;;
            5|F5) launch_module 5 ;;
            6|F6) launch_module 6 ;;
            L)    list_reports    ;;
            Q)
                clear
                echo ""
                center_print "${G1}${BOLD}  NSCS OS PROJECT — SESSION ENDED  ${NC}"
                center_print "${DM}  $(date '+%H:%M:%S')  —  Goodbye.${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                print_warn "Invalid choice: '$choice' — enter 1-6, L, or Q"
                sleep 1
                ;;
        esac
    done
}

main