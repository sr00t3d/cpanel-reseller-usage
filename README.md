# cPanel Reseller Disk Usage Reporter

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/cpanel-reseller-usage)
![Shell Script](https://img.shields.io/badge/shell-script-green)

<img width="700" alt="BindFilter" src="cpanel-reseller-usage-cover.webp" />

A Bash script designed for cPanel/WHM system administrators. It calculates the actual disk usage (via `du`) for a specific Reseller and all of their owned sub-accounts, generating a formatted text report.

## 🚀 Features

* **Reseller Lookup:** Automatically identifies all child accounts belonging to a specific reseller using `/etc/trueuserowners`.
* **Real Usage Calculation:** Uses `du` (disk usage) scanning on the file system, ensuring accurate reporting of file sizes even if cPanel quotas are out of sync.
* **Formatted Output:** Generates a clean, aligned text file with usage in GB.
* **Progress Tracking:** Displays a real-time progress bar during execution (useful for resellers with many accounts).

## 📋 Prerequisites

* **Operating System:** CentOS/AlmaLinux/CloudLinux with cPanel & WHM installed.
* **Permissions:** Must be run as `root` to access `/home/` directories of other users.
* **Dependencies:** `bc` (Basic Calculator) must be installed for floating-point math.
  * Install via: `yum install bc` or `apt install bc`.

## 🔧 Usage

1. **Download the file to the server:**

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/cpanel-reseller-usage/refs/heads/main/cp-reseller-usage.sh
```

2. **Give execution permission:**

```bash
chmod +x cp-reseller-usage.sh
```

3. **Execute the script:**

```bash
./cp-reseller-usage.sh RESELLER
```

## 📄 Exemplo

```bash
./cp-reseller-usage.sh root
Generating report for reseller: root...
Progress: 100% (6/6) 

Report generated successfully: ./usage-report-root.txt

cat ./usage-report-root.txt
Account         Disk Usage (GB)
-----------------------------------
client_a              2.45 GB
client_b              0.89 GB
client_c             15.20 GB
-----------------------------------
TOTAL: 18.54 GB
```

## ⚠️ Performance Note
Since this script runs du -sm on every user's home directory, it performs a real I/O scan of the file system.
- Small/Medium Resellers: Runs quickly.
- Large Resellers: If a reseller has hundreds of accounts or accounts with millions of small files (inodes), execution may take some time.

## ⚠️ Legal Notice

> [!WARNING]
> This software is provided "as is." Always ensure you have explicit permission before executing it. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## 📚 Detailed Tutorial

For a complete, step-by-step guide, check out my full article:

👉 [**Check size of reseller child accounts in WHM.**](https://perciocastelo.com.br/blog/check-size-of-reseller-child-accounts-in-whm.html)

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.