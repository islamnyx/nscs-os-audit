#!/bin/bash

# --- Setup ---
REPORT_DIR="$HOME/nscs_os_project/reports"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
FILE_TAG=$(date +%Y%m%d_%H%M%S)
HOST=$(hostname)

# Find latest data files
HW_DATA=$(ls -t "$REPORT_DIR"/hardware_report_*.json 2>/dev/null | head -1)
SW_DATA=$(ls -t "$REPORT_DIR"/software_report_*.json 2>/dev/null | head -1)

if [[ -z "$HW_DATA" || -z "$SW_DATA" ]]; then
    echo "Error: No JSON data found. Run Hardware and Software audits first."
    exit 1
fi

# --- Function for TXT Reports ---
make_txt() {
    TYPE=$1 # "Short" or "Full"
    OUT="$REPORT_DIR/Audit_${TYPE}_$FILE_TAG.txt"
    
    echo "------------------------------------------" > "$OUT"
    echo " NSCS SYSTEM AUDIT - $TYPE REPORT" >> "$OUT"
    echo " Date: $TIMESTAMP" >> "$OUT"
    echo " Host: $HOST" >> "$OUT"
    echo "------------------------------------------" >> "$OUT"

    if [ "$TYPE" == "Short" ]; then
        echo "[SUMMARY]" >> "$OUT"
        grep -E "os_name|kernel|cpu|ram_total" "$HW_DATA" "$SW_DATA" | tr -d '",{}' >> "$OUT"
    else
        echo "[FULL TECHNICAL DETAILS]" >> "$OUT"
        cat "$HW_DATA" "$SW_DATA" >> "$OUT"
    fi
    echo "Report saved to $OUT"
}

# --- Function for HTML Report ---
make_html() {
    OUT="$REPORT_DIR/Audit_Full_$FILE_TAG.html"
    cat <<EOF > "$OUT"
<html>
<head><title>Audit Report</title></head>
<body style="font-family: Arial; padding: 20px;">
    <h1>System Audit Report</h1>
    <p><b>Date:</b> $TIMESTAMP | <b>Host:</b> $HOST</p>
    <hr>
    <h2>Hardware Details</h2>
    <pre>$(cat "$HW_DATA")</pre>
    <hr>
    <h2>Software Details</h2>
    <pre>$(cat "$SW_DATA")</pre>
</body>
</html>
EOF
    echo "HTML Report saved to $OUT"
}

# Run generation
echo "Generating reports..."
make_txt "Short"
make_txt "Full"
make_html