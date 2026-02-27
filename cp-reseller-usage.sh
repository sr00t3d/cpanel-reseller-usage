#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   cPanel Reseller Usage v1.0.0                                            ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: percio@evolya.com.br | contato@perciocastelo.com.br            ║
# ║   Web:     https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Generates a disk usage report for a specific Reseller and      ║
# ║            their sub-accounts on a cPanel/WHM server.                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Check for required dependencies
if ! command -v bc >/dev/null 2>&1; then
    echo "Error: 'bc' (calculator) is required but not installed."
    exit 1
fi

# Check input parameter
if [ -z "$1" ]; then
    echo "Usage: $0 <RESELLER_USERNAME>"
    exit 1
fi

RESELLER="$1"
OUTPUT_FILE="./usage-report-$RESELLER.txt"

echo "Generating report for reseller: $RESELLER..."

# Get list of accounts owned by the reseller
# We use /etc/trueuserowners which maps User: Owner
if [ ! -f /etc/trueuserowners ]; then
    echo "Error: /etc/trueuserowners not found. Is this a cPanel server?"
    exit 1
fi

# Extract users belonging to the reseller
mapfile -t USERS < <(grep ": ${RESELLER}$" /etc/trueuserowners | awk -F':' '{print $1}')
TOTAL_USERS=${#USERS[@]}

if [ "$TOTAL_USERS" -eq 0 ]; then
    echo "No accounts found for reseller: $RESELLER"
    exit 1
fi

total_usage=0
counter=0

# Initialize Report Header
{
    echo -e "Account\t\tDisk Usage (GB)"
    echo "-----------------------------------"
} > "$OUTPUT_FILE"

# Loop through users
for user in "${USERS[@]}"; do
    # Check if home directory exists to avoid errors
    if [ -d "/home/$user" ]; then
        # Calculate size in MB (using du -sm)
        usage_mb=$(du -sm "/home/$user" 2>/dev/null | cut -f1)
        
        # Convert to GB
        if [ -n "$usage_mb" ]; then
            usage_gb=$(echo "scale=2; $usage_mb/1024" | bc)
        else
            usage_gb="0.00"
        fi
    else
        usage_gb="ERR"
    fi

    # Add to total accumulator (only if valid number)
    if [[ "$usage_gb" != "ERR" ]]; then
        total_usage=$(echo "$total_usage + $usage_gb" | bc)
    fi

    # Append to file using printf for alignment
    printf "%-15s %10s GB\n" "$user" "$usage_gb" >> "$OUTPUT_FILE"

    # Update progress bar
    counter=$((counter + 1))
    percent=$((counter * 100 / TOTAL_USERS))
    echo -ne "Progress: $percent% ($counter/$TOTAL_USERS) \r"
done

# Finalize Report
{
    echo "-----------------------------------"
    echo "TOTAL: $(echo "scale=2; $total_usage" | bc) GB"
} >> "$OUTPUT_FILE"

echo -e "\n\nReport generated successfully: $OUTPUT_FILE"