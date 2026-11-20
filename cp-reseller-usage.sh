#!/usr/bin/env bash
# +============================================================================+
# | cp-reseller-usage.sh                                                       |
# | cPanel Reseller Disk Usage Reporter v2.0.0                                 |
# | Audits real disk usage (du) for a cPanel/WHM Reseller and all owned        |
# | sub-accounts across multi-partition homes (/home, /home2, ...), computing  |
# | MB/GB totals, percentage share, sorting, dry-run, and table/JSON/CSV out.  |
# |                                                                            |
# | Author:  Percio Castelo                                                    |
# | Contact: percio@evolya.com.br | contato@perciocastelo.com.br               |
# | Web:     https://perciocastelo.com.br                                      |
# | Repo:    https://github.com/sr00t3d/cpanel-reseller-usage                  |
# |                                                                            |
# | Copyright 2024-2026 Percio Castelo                                         |
# | SPDX-License-Identifier: Apache-2.0                                        |
# +============================================================================+

set -uo pipefail

readonly VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# ---- Defaults ---------------------------------------------------------------
RESELLER=""
OWNERS_FILE="/etc/trueuserowners"
SORT_BY="size"
MIN_MB=0
SAVE_PATH=""
LIST_RESELLERS=0
DRY_RUN=0
OUTPUT_FORMAT="table"
QUIET=0
NO_COLOR=0

# ---- Color helpers ----------------------------------------------------------
init_colors() {
    if [[ "$NO_COLOR" -eq 1 || ! -t 1 ]]; then
        C_RESET="" C_BOLD="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
    else
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_GREEN=$'\033[32m'
        C_YELLOW=$'\033[33m'
        C_RED=$'\033[31m'
        C_CYAN=$'\033[36m'
    fi
}

# ---- Help & Version ---------------------------------------------------------
show_version() {
    echo "cPanel Reseller Disk Usage Reporter v${VERSION}"
}

show_help() {
    cat <<EOF
cPanel Reseller Disk Usage Reporter v${VERSION}
Calculates real disk usage for a cPanel/WHM reseller and all owned sub-accounts.

Usage: ${SCRIPT_NAME} <RESELLER> [OPTIONS]
       ${SCRIPT_NAME} --list-resellers [OPTIONS]

Options:
  -r, --reseller USER     Reseller username to audit
  --list-resellers        List all unique resellers found in /etc/trueuserowners
  --owners-file PATH      Path to trueuserowners file (default: /etc/trueuserowners)
  --sort MODE             Sort order: size (default, descending) or name (ascending)
  --min-mb N              Only include accounts using at least N MB (default: 0)
  --save PATH             Also save the rendered report to a file (chmod 600)
  --dry-run               Discover accounts and home paths without running du
  -o, --output FORMAT     Output format: table (default), json, csv
  -q, --quiet             Suppress standard output (errors still go to stderr)
  --no-color              Disable ANSI colors
  -V, --version           Show version and exit
  -h, --help              Show this help and exit

Examples:
  ${SCRIPT_NAME} --list-resellers
  ${SCRIPT_NAME} root --dry-run
  ${SCRIPT_NAME} agencia01 --sort size -o table --save /root/usage-agencia01.txt
  ${SCRIPT_NAME} agencia01 --min-mb 100 -o json
  ${SCRIPT_NAME} agencia01 -o csv
EOF
}

# ---- Argument Parser --------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reseller)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a reseller username." >&2; exit 1; }
            RESELLER="$2"; shift 2 ;;
        --list-resellers)
            LIST_RESELLERS=1; shift ;;
        --owners-file)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a file path." >&2; exit 1; }
            OWNERS_FILE="$2"; shift 2 ;;
        --sort)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires 'size' or 'name'." >&2; exit 1; }
            SORT_BY="$2"; shift 2 ;;
        --min-mb)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires an integer value." >&2; exit 1; }
            MIN_MB="$2"; shift 2 ;;
        --save)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires a file path." >&2; exit 1; }
            SAVE_PATH="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        -o|--output)
            [[ $# -lt 2 ]] && { echo "ERROR: $1 requires table, json, or csv." >&2; exit 1; }
            OUTPUT_FORMAT="$2"; shift 2 ;;
        -q|--quiet)
            QUIET=1; shift ;;
        --no-color)
            NO_COLOR=1; shift ;;
        -V|--version)
            show_version; exit 0 ;;
        -h|--help)
            show_help; exit 0 ;;
        -*)
            echo "ERROR: Unknown option: $1 (run with -h for usage)" >&2
            exit 1 ;;
        *)
            if [[ -z "$RESELLER" ]]; then
                RESELLER="$1"
            else
                echo "ERROR: Unexpected positional argument: $1" >&2
                exit 1
            fi
            shift ;;
    esac
done

init_colors

# ---- Validations ------------------------------------------------------------
case "$OUTPUT_FORMAT" in
    table|json|csv) ;;
    *)
        echo "${C_RED}ERROR: Invalid output format '${OUTPUT_FORMAT}'. Expected table, json, or csv.${C_RESET}" >&2
        exit 1 ;;
esac

case "$SORT_BY" in
    size|name) ;;
    *)
        echo "${C_RED}ERROR: Invalid sort mode '${SORT_BY}'. Expected 'size' or 'name'.${C_RESET}" >&2
        exit 1 ;;
esac

if ! [[ "$MIN_MB" =~ ^[0-9]+$ ]]; then
    echo "${C_RED}ERROR: --min-mb must be a non-negative integer.${C_RESET}" >&2
    exit 1
fi

if [[ ! -f "$OWNERS_FILE" ]]; then
    echo "${C_RED}ERROR: Owners file not found: ${OWNERS_FILE}. Is this a cPanel/WHM server?${C_RESET}" >&2
    exit 1
fi

TIMESTAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOSTNAME_LOCAL="$(hostname 2>/dev/null || echo unknown)"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# ---- Mode 1: List Resellers -------------------------------------------------
if [[ "$LIST_RESELLERS" -eq 1 ]]; then
    mapfile -t OWNERS < <(
        awk -F':' 'NF >= 2 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 != "") count[$2]++ }
        END { for (o in count) printf "%s\t%d\n", o, count[o] }' "$OWNERS_FILE" | sort -k2,2nr -k1,1
    )
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        printf '{\n  "version": "%s",\n  "owners_file": "%s",\n  "timestamp": "%s",\n  "resellers": [\n' \
            "$VERSION" "$(json_escape "$OWNERS_FILE")" "$TIMESTAMP_ISO"
        for i in "${!OWNERS[@]}"; do
            IFS=$'\t' read -r own cnt <<< "${OWNERS[$i]}"
            comma=","
            [[ "$i" -eq $((${#OWNERS[@]} - 1)) ]] && comma=""
            printf '    {"reseller": "%s", "accounts": %d}%s\n' "$(json_escape "$own")" "$cnt" "$comma"
        done
        printf '  ]\n}\n'
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "timestamp,reseller,accounts"
        for row in "${OWNERS[@]}"; do
            IFS=$'\t' read -r own cnt <<< "$row"
            printf '%s,"%s",%d\n' "$TIMESTAMP_ISO" "$own" "$cnt"
        done
    else
        BORDER="+----------------------+----------+"
        echo ""
        echo "${C_BOLD}cPanel Resellers (${OWNERS_FILE})${C_RESET}"
        echo "$BORDER"
        printf "| %-20s | %8s |\n" "Reseller" "Accounts"
        echo "$BORDER"
        for row in "${OWNERS[@]}"; do
            IFS=$'\t' read -r own cnt <<< "$row"
            printf "| %-20s | %8d |\n" "$own" "$cnt"
        done
        echo "$BORDER"
        echo ""
    fi
    exit 0
fi

# ---- Mode 2: Audit Reseller Disk Usage --------------------------------------
if [[ -z "$RESELLER" ]]; then
    echo "${C_RED}ERROR: Reseller username is required (or use --list-resellers). Run with -h for usage.${C_RESET}" >&2
    exit 1
fi

mapfile -t USERS < <(
    awk -F':' -v r="$RESELLER" 'NF >= 2 {
        u=$1; o=$2;
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", u);
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", o);
        if (o == r && u != "") print u;
    }' "$OWNERS_FILE" | sort -u
)

if [[ "${#USERS[@]}" -eq 0 ]]; then
    echo "${C_RED}ERROR: No accounts found for reseller '${RESELLER}' in ${OWNERS_FILE}.${C_RESET}" >&2
    exit 2
fi

resolve_home() {
    local user="$1"
    local h=""
    if command -v getent >/dev/null 2>&1; then
        h="$(getent passwd "$user" 2>/dev/null | cut -d: -f6 || true)"
    fi
    if [[ -z "$h" || ! -d "$h" ]]; then
        for base in /home /home2 /home3 /home4; do
            if [[ -d "${base}/${user}" ]]; then
                h="${base}/${user}"
                break
            fi
        done
    fi
    [[ -z "$h" ]] && h="/home/${user}"
    printf '%s' "$h"
}

# Collect raw records: "mb\tuser\thome\tstatus"
RAW_RECORDS=()
TOTAL_MB=0
ERR_COUNT=0

for user in "${USERS[@]}"; do
    home_dir="$(resolve_home "$user")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        st="WOULD_SCAN"
        [[ ! -d "$home_dir" ]] && st="MISSING_HOME"
        RAW_RECORDS+=("0	${user}	${home_dir}	${st}")
        continue
    fi

    if [[ -d "$home_dir" ]]; then
        mb="$(du -sm "$home_dir" 2>/dev/null | awk '{print $1}')"
        if [[ -n "$mb" && "$mb" =~ ^[0-9]+$ ]]; then
            if [[ "$mb" -ge "$MIN_MB" ]]; then
                RAW_RECORDS+=("${mb}	${user}	${home_dir}	OK")
                TOTAL_MB=$((TOTAL_MB + mb))
            fi
        else
            RAW_RECORDS+=("0	${user}	${home_dir}	DU_ERROR")
            ERR_COUNT=$((ERR_COUNT + 1))
        fi
    else
        RAW_RECORDS+=("0	${user}	${home_dir}	MISSING_HOME")
        ERR_COUNT=$((ERR_COUNT + 1))
    fi
done

# Sort collected records
if [[ "$SORT_BY" == "name" ]]; then
    mapfile -t SORTED < <(printf '%s\n' "${RAW_RECORDS[@]}" | sort -t$'\t' -k2,2)
else
    mapfile -t SORTED < <(printf '%s\n' "${RAW_RECORDS[@]}" | sort -t$'\t' -k1,1nr -k2,2)
fi

mb_to_gb() {
    awk -v mb="$1" 'BEGIN { printf "%.2f", mb / 1024.0 }'
}

calc_share() {
    awk -v mb="$1" -v tot="$2" 'BEGIN { if (tot > 0) printf "%.1f", (mb * 100.0) / tot; else printf "0.0" }'
}

TOTAL_GB="$(mb_to_gb "$TOTAL_MB")"
OVERALL_STATUS="SUCCESS"
[[ "$DRY_RUN" -eq 1 ]] && OVERALL_STATUS="DRY_RUN"
[[ "$ERR_COUNT" -gt 0 && "$DRY_RUN" -eq 0 ]] && OVERALL_STATUS="PARTIAL"

# ---- Render Report ----------------------------------------------------------
render_report() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        printf '{\n'
        printf '  "version": "%s",\n' "$VERSION"
        printf '  "status": "%s",\n' "$OVERALL_STATUS"
        printf '  "hostname": "%s",\n' "$(json_escape "$HOSTNAME_LOCAL")"
        printf '  "reseller": "%s",\n' "$(json_escape "$RESELLER")"
        printf '  "owners_file": "%s",\n' "$(json_escape "$OWNERS_FILE")"
        printf '  "accounts_count": %d,\n' "${#SORTED[@]}"
        printf '  "total_mb": %d,\n' "$TOTAL_MB"
        printf '  "total_gb": %s,\n' "$TOTAL_GB"
        printf '  "errors": %d,\n' "$ERR_COUNT"
        printf '  "dry_run": %s,\n' "$([[ "$DRY_RUN" -eq 1 ]] && echo true || echo false)"
        printf '  "timestamp": "%s",\n' "$TIMESTAMP_ISO"
        printf '  "accounts": [\n'
        for i in "${!SORTED[@]}"; do
            IFS=$'\t' read -r mb usr hdir st <<< "${SORTED[$i]}"
            gb="$(mb_to_gb "$mb")"
            pct="$(calc_share "$mb" "$TOTAL_MB")"
            comma=","
            [[ "$i" -eq $((${#SORTED[@]} - 1)) ]] && comma=""
            printf '    {"user": "%s", "home": "%s", "mb": %d, "gb": %s, "share_pct": %s, "status": "%s"}%s\n' \
                "$(json_escape "$usr")" "$(json_escape "$hdir")" "$mb" "$gb" "$pct" "$st" "$comma"
        done
        printf '  ]\n'
        printf '}\n'

    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "timestamp,reseller,user,home,mb,gb,share_pct,status"
        for row in "${SORTED[@]}"; do
            IFS=$'\t' read -r mb usr hdir st <<< "$row"
            gb="$(mb_to_gb "$mb")"
            pct="$(calc_share "$mb" "$TOTAL_MB")"
            printf '%s,"%s","%s","%s",%d,%s,%s,%s\n' \
                "$TIMESTAMP_ISO" "$RESELLER" "$usr" "$hdir" "$mb" "$gb" "$pct" "$st"
        done

    else
        BORDER="+------------------+------------------------+----------+----------+--------+--------------+"
        echo ""
        echo "${C_BOLD}cPanel Reseller Disk Usage Reporter v${VERSION}${C_RESET}"
        echo "Host      : ${HOSTNAME_LOCAL}"
        echo "Reseller  : ${RESELLER}"
        echo "Accounts  : ${#SORTED[@]} (min-mb: ${MIN_MB}, sort: ${SORT_BY})"
        echo "Dry-Run   : $([[ "$DRY_RUN" -eq 1 ]] && echo yes || echo no)"
        echo "Status    : ${OVERALL_STATUS}"
        echo "Timestamp : ${TIMESTAMP_ISO}"
        echo ""
        echo "$BORDER"
        printf "| %-16s | %-22s | %8s | %8s | %6s | %-12s |\n" \
            "Account" "Home Directory" "MB" "GB" "Share" "Status"
        echo "$BORDER"
        for row in "${SORTED[@]}"; do
            IFS=$'\t' read -r mb usr hdir st <<< "$row"
            gb="$(mb_to_gb "$mb")"
            pct="$(calc_share "$mb" "$TOTAL_MB")"
            printf "| %-16s | %-22s | %8d | %8s | %5s%% | %-12s |\n" \
                "$usr" "$hdir" "$mb" "$gb" "$pct" "$st"
        done
        echo "$BORDER"
        echo "TOTAL     : ${TOTAL_MB} MB (${TOTAL_GB} GB) across ${#SORTED[@]} account(s)"
        echo ""
    fi
}

REPORT_OUT="$(render_report)"

if [[ -n "$SAVE_PATH" ]]; then
    mkdir -p "$(dirname "$SAVE_PATH")"
    printf '%s\n' "$REPORT_OUT" > "$SAVE_PATH"
    chmod 600 "$SAVE_PATH"
fi

if [[ "$QUIET" -eq 0 ]]; then
    printf '%s\n' "$REPORT_OUT"
fi

exit 0
