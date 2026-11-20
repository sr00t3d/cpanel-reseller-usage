# cPanel Reseller Disk Usage Reporter

Readme: [PT-BR](README-ptbr.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.0-green.svg)](https://github.com/sr00t3d/cpanel-reseller-usage/releases)
[![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

<img width="700" src="cpanel-reseller-usage-cover.webp" alt="cPanel Reseller Disk Usage Reporter" />

**cPanel Reseller Disk Usage Reporter v2.0.0** is a zero-dependency Bash CLI tool for cPanel/WHM administrators that audits real disk consumption (`du -sm`) for any Reseller and all owned sub-accounts across multi-partition homes (`/home`, `/home2`, `/home3`, ...), calculating MB/GB totals, percentage share per account, sorting, and exporting to table, JSON, or CSV.

---

## Features

- **Multi-Partition Home Resolution**: resolves each sub-account's real home directory via `getent passwd` (with `/home`, `/home2`, `/home3`, `/home4` fallback)
- **Zero External Dependencies**: uses pure `awk` arithmetic instead of requiring `bc`
- **Reseller Discovery (`--list-resellers`)**: lists all unique resellers and sub-account counts from `/etc/trueuserowners`
- **Analytics & Filtering**: calculates `% Share` per sub-account, sorts by `--sort size` (descending) or `--sort name`, and supports `--min-mb N` threshold filtering
- **Dry-Run Simulation (`--dry-run`)**: resolves accounts and home directories without invoking `du`
- **Multi-Format Reporting (`-o table|json|csv`) & Optional `--save PATH`**: outputs directly to stdout for piping or saves with `chmod 600`

---

## Requirements

- Linux cPanel/WHM server with Bash 4+
- Standard coreutils (`du`, `awk`, `sort`, `getent`)
- Root (or sufficient read) permissions to scan sub-account home directories

---

## Installation

```bash
curl -fsSLO https://raw.githubusercontent.com/sr00t3d/cpanel-reseller-usage/main/cp-reseller-usage.sh
chmod +x cp-reseller-usage.sh
```

---

## Usage

```bash
./cp-reseller-usage.sh <RESELLER> [OPTIONS]
./cp-reseller-usage.sh --list-resellers [OPTIONS]

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
```

### Examples

```bash
# List all resellers on the server
./cp-reseller-usage.sh --list-resellers

# Preview accounts owned by reseller without running du
./cp-reseller-usage.sh agencia01 --dry-run

# Audit reseller sorted by largest consumer and save chmod 600 report
./cp-reseller-usage.sh agencia01 --sort size --save /root/usage-agencia01.txt

# Filter accounts >= 500 MB and output JSON
./cp-reseller-usage.sh agencia01 --min-mb 500 -o json

# Export CSV for billing / capacity spreadsheets
./cp-reseller-usage.sh agencia01 -o csv
```

---

## Real Output Example

Captured live on an AlmaLinux 8.10 cPanel/WHM server:

### List resellers (`--list-resellers`)

```text
$ ./cp-reseller-usage.sh --list-resellers --owners-file /tmp/reseller-e2e/trueuserowners --no-color

cPanel Resellers (/tmp/reseller-e2e/trueuserowners)
+----------------------+----------+
| Reseller             | Accounts |
+----------------------+----------+
| agencia01            |        3 |
| root                 |        1 |
+----------------------+----------+
```

### Table output (default)

```text
$ ./cp-reseller-usage.sh agencia01 --owners-file /tmp/reseller-e2e/trueuserowners --save /tmp/reseller-e2e/report.txt --no-color

cPanel Reseller Disk Usage Reporter v2.0.0
Host      : cpanel-test.local
Reseller  : agencia01
Accounts  : 3 (min-mb: 0, sort: size)
Dry-Run   : no
Status    : SUCCESS
Timestamp : 2026-11-20T06:30:16Z

+------------------+------------------------+----------+----------+--------+--------------+
| Account          | Home Directory         |       MB |       GB |  Share | Status       |
+------------------+------------------------+----------+----------+--------+--------------+
| e2e_client1      | /home/e2e_client1      |       13 |     0.01 |  68.4% | OK           |
| e2e_client2      | /home/e2e_client2      |        5 |     0.00 |  26.3% | OK           |
| percio           | /home/percio           |        1 |     0.00 |   5.3% | OK           |
+------------------+------------------------+----------+----------+--------+--------------+
TOTAL     : 19 MB (0.02 GB) across 3 account(s)
```

### JSON output (`-o json`)

```json
{
  "version": "2.0.0",
  "status": "SUCCESS",
  "hostname": "cpanel-test.local",
  "reseller": "agencia01",
  "owners_file": "/tmp/reseller-e2e/trueuserowners",
  "accounts_count": 3,
  "total_mb": 19,
  "total_gb": 0.02,
  "errors": 0,
  "dry_run": false,
  "timestamp": "2026-11-20T06:30:16Z",
  "accounts": [
    {"user": "e2e_client1", "home": "/home/e2e_client1", "mb": 13, "gb": 0.01, "share_pct": 68.4, "status": "OK"},
    {"user": "e2e_client2", "home": "/home/e2e_client2", "mb": 5, "gb": 0.00, "share_pct": 26.3, "status": "OK"},
    {"user": "percio", "home": "/home/percio", "mb": 1, "gb": 0.00, "share_pct": 5.3, "status": "OK"}
  ]
}
```

### CSV output (`-o csv`)

```csv
timestamp,reseller,user,home,mb,gb,share_pct,status
2026-11-20T06:30:16Z,"agencia01","e2e_client1","/home/e2e_client1",13,0.01,68.4,OK
2026-11-20T06:30:16Z,"agencia01","e2e_client2","/home/e2e_client2",5,0.00,26.3,OK
2026-11-20T06:30:16Z,"agencia01","percio","/home/percio",1,0.00,5.3,OK
```

---

## License

Apache-2.0. See [LICENSE](LICENSE) for details.

## Author

[Percio Castelo](https://perciocastelo.com.br)
