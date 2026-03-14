#!/bin/bash

# Phase 5: Remote System Monitoring
# Purpose: Check the health of a remote Linux machine via SSH

echo "======================================================="
echo "         REMOTE SYSTEM MONITORING (SSH)"
echo "======================================================="

# 1. Get Connection Details
read -p "Enter Remote IP Address: " REMOTE_IP
read -p "Enter Remote Username (e.g., kali): " REMOTE_USER

echo ""
echo "Attempting to connect to $REMOTE_IP..."
echo "-------------------------------------------------------"

# 2. Run Commands on the Remote Machine
# We use SSH to run: hostname, uptime, and free -h
ssh -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_IP} "
    echo -e '\e[1;34m[ REMOTE SYSTEM STATUS ]\e[0m'
    echo '-------------------------------------------------------'
    echo -e 'Hostname:    ' \$(hostname)
    echo -e 'Uptime:      ' \$(uptime -p | sed 's/up //')
    
    echo -e '\n\e[1;34m[ RESOURCE USAGE ]\e[0m'
    # Organized Memory: Shows Used / Total
    echo -n 'Memory:      '
    free -h | awk '/^Mem:/ {print \$3 \" used of \" \$2}'
    
    # Organized Disk: Shows Used / Total (Percentage)
    echo -n 'Disk Space:  '
    df -h / | awk 'NR==2 {print \$3 \" used of \" \$2 \" (\" \$5 \")\"}'
    
    echo -e '\n\e[1;34m[ SYSTEM LOAD ]\e[0m'
    echo -n 'CPU Load:    '
    uptime | awk -F'load average:' '{ print \$2 }'
    echo '-------------------------------------------------------'
"

# 3. Handle Connection Errors
if [ $? -ne 0 ]; then
    echo -e "\033[0;31m[!] Connection Failed.\033[0m"
    echo "Check if:"
    echo " 1. The IP address is correct."
    echo " 2. SSH is enabled on the target (sudo systemctl start ssh)."
    echo " 3. You have the correct password."
fi

echo "-------------------------------------------------------"
echo "Monitoring Task Complete."