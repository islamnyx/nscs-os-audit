#!/bin/bash

################################################################################
# NSCS OS Project - Main Menu Script (FIXED VERSION)
# Orchestrates all audit modules with an interactive menu system
# BUGFIXES: Wildcard matching, variable initialization, color output
# Author: NSCS OS Project - Part 1
# Date: 2026
################################################################################

set -o pipefail

# ============================================================================
# CONFIGURATION & COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_DIR="${LOG_DIR:-/var/log/sys_audit}"
REPORT_DIR="$LOG_DIR/reports"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Clear screen
clear_screen() {
    clear
}

# Print colored header
print_header() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          NSCS - Linux System Audit & Monitoring System               ║
║                                                                       ║
║            Design and Implementation of an Automated                  ║
║       Hardware & Software Audit System with Reporting and            ║
║              Remote Monitoring Capabilities                           ║
║                                                                       ║
║                      Part 1: Hardware Audit                           ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Print colored messages
print_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if module exists
check_module() {
    if [ ! -f "$MODULES_DIR/$1" ]; then
        print_error "Module not found: $1"
        return 1
    fi
    
    if [ ! -x "$MODULES_DIR/$1" ]; then
        print_warning "Module not executable: $1"
        chmod +x "$MODULES_DIR/$1"
        print_success "Made executable: $1"
    fi
    
    return 0
}

# Initialize audit system
init_system() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR" 2>/dev/null
    fi
    
    if [ ! -d "$REPORT_DIR" ]; then
        mkdir -p "$REPORT_DIR" 2>/dev/null || sudo mkdir -p "$REPORT_DIR" 2>/dev/null
    fi
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

show_main_menu() {
    clear_screen
    print_header
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Main Menu - Select an Audit Module${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Phase 1: Hardware & Software Audit${NC}"
    echo -e "  ${MAGENTA}1)${NC} Hardware Audit Module        (Collect hardware information)"
    echo -e "  ${MAGENTA}2)${NC} Software Audit Module        (Collect OS/software information)"
    echo ""
    echo -e "${GREEN}Phase 2: Report Generation${NC}"
    echo -e "  ${MAGENTA}3)${NC} Generate Reports             (Create formatted reports)"
    echo ""
    echo -e "${GREEN}Phase 3: Communication${NC}"
    echo -e "  ${MAGENTA}4)${NC} Send Reports via Email       (Email report delivery)"
    echo ""
    echo -e "${GREEN}Phase 4: Automation${NC}"
    echo -e "  ${MAGENTA}5)${NC} Setup Cron Jobs              (Schedule automatic audits)"
    echo ""
    echo -e "${GREEN}Phase 5: Remote Monitoring${NC}"
    echo -e "  ${MAGENTA}6)${NC} Remote Monitoring             (Monitor remote systems)"
    echo ""
    echo -e "${GREEN}System Administration${NC}"
    echo -e "  ${MAGENTA}7)${NC} View Audit Logs              (Check system logs)"
    echo -e "  ${MAGENTA}8)${NC} View Generated Reports       (Browse reports)"
    echo -e "  ${MAGENTA}9)${NC} System Status                (Check audit system status)"
    echo ""
    echo -e "${GREEN}Utilities${NC}"
    echo -e "  ${MAGENTA}10)${NC} Help & Documentation        (Project documentation)"
    echo -e "  ${MAGENTA}0)${NC} Exit                         (Quit the program)"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# MODULE EXECUTION FUNCTIONS
# ============================================================================

run_hardware_audit() {
    print_info "Starting Hardware Audit Module..."
    echo ""
    
    if check_module "audit_hardware_v2.sh"; then
        "$MODULES_DIR/audit_hardware_v2.sh"
        print_success "Hardware audit completed"
    else
        print_error "Failed to run hardware audit module"
        return 1
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

run_software_audit() {
    print_info "Software Audit Module (Coming Soon - Phase 2)"
    echo ""
    print_warning "This module is not yet implemented."
    print_info "Development timeline: March 10-14, 2026"
    echo ""
    echo "The software audit module will collect:"
    echo "  • OS name and version"
    echo "  • Kernel version"
    echo "  • Installed packages"
    echo "  • Running services"
    echo "  • Active processes"
    echo "  • Open ports"
    echo "  • Logged-in users"
    echo ""
    
    read -p "Press Enter to return to main menu..."
}

generate_reports() {
    print_info "Report Generation Module (Coming Soon - Phase 3)"
    echo ""
    print_warning "This module is not yet implemented."
    print_info "Development timeline: March 17-21, 2026"
    echo ""
    echo "The report generation module will:"
    echo "  • Create short reports (summary view)"
    echo "  • Create full reports (detailed audit)"
    echo "  • Support multiple formats: .txt, .html, .pdf, .json"
    echo "  • Add professional formatting and styling"
    echo ""
    
    read -p "Press Enter to return to main menu..."
}

send_email_reports() {
    print_info "Email Transmission Module (Coming Soon - Phase 4)"
    echo ""
    print_warning "This module is not yet implemented."
    print_info "Development timeline: March 24-28, 2026"
    echo ""
    echo "The email module will:"
    echo "  • Send reports to specified email address"
    echo "  • Support SMTP configuration"
    echo "  • Allow recipient customization"
    echo "  • Support short/full report selection"
    echo ""
    
    read -p "Press Enter to return to main menu..."
}

setup_cron_jobs() {
    print_info "Cron Automation Module (Coming Soon - Phase 5)"
    echo ""
    print_warning "This module is not yet implemented."
    print_info "Development timeline: March 24-28, 2026"
    echo ""
    echo "The cron module will:"
    echo "  • Schedule automatic audits (e.g., daily at 4:00 AM)"
    echo "  • Manage cron job configuration"
    echo "  • Handle execution logging"
    echo "  • Support log rotation"
    echo ""
    
    read -p "Press Enter to return to main menu..."
}

setup_remote_monitoring() {
    print_info "Remote Monitoring Module (Coming Soon - Phase 6)"
    echo ""
    print_warning "This module is not yet implemented."
    print_info "Development timeline: March 29-30, 2026"
    echo ""
    echo "The remote monitoring module will:"
    echo "  • Enable SSH-based remote monitoring"
    echo "  • Support real-time or periodic monitoring"
    echo "  • Centralize reports from multiple machines"
    echo "  • Ensure secure remote access practices"
    echo ""
    
    read -p "Press Enter to return to main menu..."
}

view_audit_logs() {
    clear_screen
    print_header
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Audit Logs${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$LOG_DIR" ]; then
        print_warning "Log directory not found: $LOG_DIR"
    else
        echo -e "${BLUE}Logs in: $LOG_DIR${NC}"
        echo ""
        
        if [ -f "$LOG_DIR/hardware_audit.log" ]; then
            echo -e "${GREEN}Recent Hardware Audit Logs:${NC}"
            tail -20 "$LOG_DIR/hardware_audit.log"
        else
            print_warning "No hardware audit logs found yet"
        fi
        
        echo ""
        echo -e "${BLUE}Available log files:${NC}"
        ls -lh "$LOG_DIR"/*.log 2>/dev/null || print_info "No log files yet"
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

view_reports() {
    clear_screen
    print_header
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Generated Reports${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$REPORT_DIR" ]; then
        print_warning "Reports directory not found: $REPORT_DIR"
    else
        echo -e "${BLUE}Reports in: $REPORT_DIR${NC}"
        echo ""
        
        # BUGFIX: Use proper globbing to check if files exist
        if compgen -G "$REPORT_DIR/hardware_report_full_*.json" > /dev/null 2>&1; then
            echo -e "${GREEN}Available Hardware Reports:${NC}"
            ls -lh "$REPORT_DIR"/hardware_report_full_*.json 2>/dev/null
            echo ""
            
            latest_report=$(ls -t "$REPORT_DIR"/hardware_report_full_*.json 2>/dev/null | head -1)
            if [ -n "$latest_report" ]; then
                echo -e "${YELLOW}Latest report (first 50 lines):${NC}"
                echo ""
                head -50 "$latest_report"
                echo ""
                print_info "To view full report: cat $latest_report | jq '.'"
            fi
        else
            print_warning "No hardware reports found yet"
            print_info "Run: Hardware Audit Module (option 1) to generate reports"
        fi
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

system_status() {
    clear_screen
    print_header
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}System Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check directories
    echo -e "${BLUE}Directory Status:${NC}"
    
    if [ -d "$MODULES_DIR" ]; then
        print_success "Modules directory found: $MODULES_DIR"
        echo "  Available modules:"
        ls -1 "$MODULES_DIR"/*.sh 2>/dev/null | while read -r module; do
            if [ -x "$module" ]; then
                echo "    ✓ $(basename "$module")"
            else
                echo "    ✗ $(basename "$module") (not executable)"
            fi
        done
    else
        print_error "Modules directory not found: $MODULES_DIR"
    fi
    
    echo ""
    
    if [ -d "$LOG_DIR" ]; then
        print_success "Log directory found: $LOG_DIR"
        echo "  Size: $(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)"
    else
        print_warning "Log directory not found: $LOG_DIR"
    fi
    
    echo ""
    
    if [ -d "$REPORT_DIR" ]; then
        print_success "Reports directory found: $REPORT_DIR"
        # BUGFIX: Use proper globbing to count reports
        report_count=$(compgen -G "$REPORT_DIR/*.json" 2>/dev/null | wc -l)
        echo "  Reports generated: $report_count"
    else
        print_warning "Reports directory not found: $REPORT_DIR"
    fi
    
    echo ""
    
    # System info
    echo -e "${BLUE}System Information:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  OS: $(uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  CPU: $(nproc) cores"
    echo "  Uptime: $(uptime | sed 's/.*up //' | sed 's/,.*//')"
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

show_help() {
    clear_screen
    print_header
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Help & Documentation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/docs/QUICK_START.md" ]; then
        echo -e "${GREEN}Quick Start Guide:${NC}"
        cat "$SCRIPT_DIR/docs/QUICK_START.md" | head -50
        echo ""
        print_info "Full documentation available in: $SCRIPT_DIR/docs/"
    else
        echo -e "${YELLOW}Documentation files not found in: $SCRIPT_DIR/docs/${NC}"
        echo ""
        echo "Available documentation:"
        echo "  • 00_START_HERE.txt"
        echo "  • QUICK_START.md"
        echo "  • README_HARDWARE.md"
        echo "  • IMPLEMENTATION_SUMMARY.md"
        echo "  • PROJECT_ARCHITECTURE.md"
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Initialize system
    init_system
    
    while true; do
        show_main_menu
        
        read -p "Enter your choice [0-10]: " choice
        
        case $choice in
            1)
                clear_screen
                run_hardware_audit
                ;;
            2)
                clear_screen
                run_software_audit
                ;;
            3)
                clear_screen
                generate_reports
                ;;
            4)
                clear_screen
                send_email_reports
                ;;
            5)
                clear_screen
                setup_cron_jobs
                ;;
            6)
                clear_screen
                setup_remote_monitoring
                ;;
            7)
                view_audit_logs
                ;;
            8)
                view_reports
                ;;
            9)
                system_status
                ;;
            10)
                show_help
                ;;
            0)
                clear_screen
                echo ""
                print_success "Thank you for using NSCS Audit System!"
                echo ""
                echo "Deadline: March 30, 2026 @ 8:00 AM"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 0-10."
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"