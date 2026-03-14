#!/bin/bash

# Simple Email Transmission Script
# Purpose: Send the generated reports to a specified email

# 1. Setup paths
REPORT_DIR="$HOME/nscs_os_project/reports"

# 2. Get the latest Full Report (.txt)
# We pick the newest .txt file starting with "Full_Audit"
LATEST_REPORT=$(ls -t $REPORT_DIR/Audit_Full_*.txt 2>/dev/null | head -1)

echo "-------------------------------------------------------"
echo "  NSCS - Email Transmission System"
echo "-------------------------------------------------------"

# 3. Check if report exists
if [ -z "$LATEST_REPORT" ]; then
    echo "Error: No formatted report found. Run Option 3 first."
    exit 1
fi

# 4. Get User Input
echo "Latest report found: $(basename $LATEST_REPORT)"
read -p "Enter recipient email address: " RECIPIENT
read -p "Enter subject [System Audit Report]: " SUBJECT

# Set default subject if user leaves it blank
if [ -z "$SUBJECT" ]; then
    SUBJECT="System Audit Report - $(hostname)"
fi

# 5. Send the email
echo "Sending email to $RECIPIENT..."

# The < symbol tells the mail command to use the report file as the message body
mail -s "$SUBJECT" "$RECIPIENT" < "$LATEST_REPORT"

# 6. Check if it worked
if [ $? -eq 0 ]; then
    echo "Success: Email sent to $RECIPIENT"
else
    echo "Error: Failed to send email. Make sure 'mailutils' is installed."
fi

echo "-------------------------------------------------------"