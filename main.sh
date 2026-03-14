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
# This points directly to the folder you requested
LOG_DIR="$HOME/nscs_os_project"
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
    echo -e "${YELLOW}           SYSTEM AUDIT PROJECT - MAIN MENU${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${MAGENTA}1)${NC} Hardware Audit Module      (Phase 1)"
    echo -e "  ${MAGENTA}2)${NC} Software Audit Module      (Phase 1)"
    echo -e "  ${MAGENTA}3)${NC} Generate Formatted Reports (Phase 2)"
    echo -e "  ${MAGENTA}4)${NC} Send Reports via Email     (Phase 3)"
    echo -e "  ${MAGENTA}5)${NC} Setup Automation (Cron)    (Phase 4)"
    echo -e "  ${MAGENTA}6)${NC} Remote System Monitoring   (Phase 5)"
    echo ""
    echo -e "  ${MAGENTA}10)${NC} Help & Documentation"
    echo -e "  ${MAGENTA}0)${NC} Exit"
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
    print_info "Starting Software Audit Module..."
    echo ""
    
    # Check for the filename we just created
    if check_module "audit_software.sh"; then
        "$MODULES_DIR/audit_software.sh"
        print_success "Software audit completed"
    else
        print_error "Failed to run software audit module"
        return 1
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

generate_reports() {
    print_info "Starting Report Generation System..."
    echo ""
    
    # Check if the module exists and run it
    if check_module "generate_reports.sh"; then
        "$MODULES_DIR/generate_reports.sh"
        print_success "Reports generated successfully in $REPORT_DIR"
    else
        print_error "Reporting module not found."
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

send_email_reports() {
    print_info "Starting Email Transmission..."
    if check_module "send_reports.sh"; then
        "$MODULES_DIR/send_reports.sh"
    else
        print_error "Email module not found."
    fi
    read -p "Press Enter to return to main menu..."
}

setup_cron_jobs() {
    if check_module "setup_cron.sh"; then
        "$MODULES_DIR/setup_cron.sh"
    fi
    read -p "Press Enter to return to main menu..."
}

# Phase 5: Remote Monitoring Function
setup_remote_monitoring() {
    print_info "Starting Remote System Monitoring..."
    
    # Check if the module exists and run it
    if check_module "remote_monitor.sh"; then
        "$MODULES_DIR/remote_monitor.sh"
    else
        print_error "Remote monitoring module not found."
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
