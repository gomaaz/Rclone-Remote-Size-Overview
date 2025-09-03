# rclone-remotes-overview.sh

This Bash script provides a **terminal overview of multiple [rclone](https://rclone.org) remotes**.  
It queries each remote using `rclone about --json`, extracts usage information, and prints a **sortable table** with:

- **Used (GB)** (largest usage at the top)
- **Trashed (GB)**
- **Free (GB)**
- **Total (GB)**
- **Usage %** (color-coded: green <60%, yellow 60–85%, red >85%)
- **ASCII bar chart** for quick visual usage

> ℹ️ The script calculates `Bytes / 1024³` and labels the result as "GB" to match typical web UI displays (many providers display GiB but label them GB).

---

## Features

- Displays usage of multiple remotes in one table
- Sorted by **largest usage first**
- Color-coded usage percentage
- ASCII bar usage visualization
- Supports custom assumed total capacity (`--cap`)
- Works with encrypted `rclone.conf` via `RCLONE_CONFIG_PASS`

---

## Requirements

- [rclone](https://rclone.org) (>= v1.53)  
- [jq](https://stedolan.github.io/jq/) for JSON parsing  
- A configured `rclone.conf` (can be encrypted)

---

## Usage

```bash
# Clone this repo and make the script executable
chmod +x rclone-remotes-overview.sh

# Run for one or more remotes
./rclone-remotes-overview.sh remote1: remote2: remote3:

# Use a custom total capacity (default = 25600 GB)
./rclone-remotes-overview.sh --cap 51200 bigbox:

# Disable colored output
./rclone-remotes-overview.sh --no-color remote:
