#!/bin/bash

# Phase 4: Interactive Automation Setup
# Purpose: Let the user choose when the audit runs automatically

echo "-------------------------------------------------------"
echo "         SCHEDULE AUTOMATED AUDIT"
echo "-------------------------------------------------------"

# 1. Get User Input for Time
read -p "Enter Hour (0-23): " USER_HOUR
read -p "Enter Minute (0-59): " USER_MIN

# Simple Validation (Standard student-level check)
if [[ $USER_HOUR -gt 23 || $USER_MIN -gt 59 ]]; then
    echo "Error: Invalid time format. Please use 0-23 for hours and 0-59 for minutes."
    exit 1
fi

# 2. Define Paths
SCRIPT_PATH="$HOME/nscs_os_project/modules"
LOG_FILE="$HOME/nscs_os_project/reports/automation.log"

# 3. Create the Command String
# This runs the full chain: HW -> SW -> Report -> Email
COMMAND="/bin/bash $SCRIPT_PATH/audit_hardware_v2.sh --silent && /bin/bash $SCRIPT_PATH/audit_software.sh --silent && /bin/bash $SCRIPT_PATH/generate_reports.sh"

# 4. Construct the Cron Job string
# Syntax: Minute Hour Day Month Weekday Command
NEW_JOB="$USER_MIN $USER_HOUR * * * $COMMAND >> $LOG_FILE 2>&1"

# 5. Apply to Crontab
# We filter out any OLD project jobs first so we don't have duplicates
(crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "$NEW_JOB") | crontab -

echo "-------------------------------------------------------"
echo -e "\033[0;32m[✓] Success! Audit scheduled for $USER_HOUR:$USER_MIN every day.\033[0m"
echo "To verify, type: crontab -l"
echo "-------------------------------------------------------"