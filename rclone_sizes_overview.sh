#!/usr/bin/env bash
# rclone-remotes-overview.sh
# Displays a table of multiple rclone remotes with a usage bar.
# Math matches typical web UIs: Bytes / 1024^3 (GiB) but labeled as "GB".

set -euo pipefail
export LC_ALL=C
export LC_NUMERIC=C

# --- rclone config password ---------------------------------------------------
# Replace "yourpassword" or export RCLONE_CONFIG_PASS beforehand.
export RCLONE_CONFIG_PASS="YOURPASSWORDHERE"

# --- settings ----------------------------------------------------------------
RCLONE="/usr/bin/rclone"   # path to rclone
CAP_GB=25600               # assumed total per remote if 'total' is missing (in "GB" = GiB)
BAR_WIDTH=30               # width of bar graph
USE_COLOR=1                # 1 = colored output, 0 = plain

usage() {
  cat <<EOF
Usage: $(basename "$0") [--cap <GB>] [--no-color] remote1: [remote2: ...]
Example: $(basename "$0") --cap 25600 backup: archive: media:
Note: "GB" here means Bytes / 1024^3 (GiB) to match typical web UI displays.
EOF
}

floor() { awk -v x="$1" 'BEGIN{printf("%d", (x>=0)?int(x):int(x)-1)}'; }
# Bytes -> "GB" (actually GiB) with 2 decimals
b2webgb() { awk -v b="$1" 'BEGIN{printf("%.2f", b/1024/1024/1024)}'; }

color() {
  local code="$1"; shift
  if [[ "$USE_COLOR" -eq 1 ]] && tput colors >/dev/null 2>&1; then
    tput setaf "$code"; printf "%s" "$*"; tput sgr0
  else
    printf "%s" "$*"
  fi
}

bar() {
  local pct="$1" w="$BAR_WIDTH"
  local filled
  filled=$(floor "$(awk -v p="$pct" -v w="$w" 'BEGIN{print p/100*w}')")
  (( filled < 0 )) && filled=0
  (( filled > w )) && filled=$w
  printf "%s%s" "$(printf '█%.0s' $(seq 1 "$filled"))" "$(printf '░%.0s' $(seq 1 $((w-filled))))"
}

# --- args --------------------------------------------------------------------
remotes=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cap) CAP_GB="$2"; shift 2;;
    --no-color) USE_COLOR=0; shift;;
    -h|--help) usage; exit 0;;
    *) remotes+=("$1"); shift;;
  esac
done
[[ ${#remotes[@]} -eq 0 ]] && { usage; exit 1; }

# We'll collect rows first, then sort by Used (GB) desc.
# Row format: "used_sortkey|remote|used|trashed|free|total|used_pct_colored|bar"
rows=()

for remote in "${remotes[@]}"; do
  if ! json=$("$RCLONE" about --json "$remote" 2>/dev/null); then
    rows+=("0|$remote|ERR|ERR|ERR|ERR|0|")
    continue
  fi

  used_b=$(echo "$json"     | jq -r '.used    // 0')
  trashed_b=$(echo "$json"  | jq -r '.trashed // 0')
  free_b=$(echo "$json"     | jq -r '.free    // 0')
  total_b=$(echo "$json"    | jq -r '.total   // 0')

  if [[ "$total_b" -gt 0 ]]; then
    total_gb=$(b2webgb "$total_b")
    used_gb=$(b2webgb "$used_b")
    trashed_gb=$(b2webgb "$trashed_b")
    free_gb=$(b2webgb "$free_b")
  else
    total_gb=$(printf "%.2f" "$CAP_GB")
    used_gb=$(b2webgb "$used_b")
    trashed_gb=$(b2webgb "$trashed_b")
    free_gb=$(awk -v t="$total_gb" -v u="$used_gb" 'BEGIN{v=t-u; if(v<0) v=0; printf("%.2f", v)}')
  fi

  used_pct=$(awk -v u="$used_gb" -v t="$total_gb" 'BEGIN{if(t>0){printf("%.1f", (u/t)*100)}else{printf("0.0")}}')
  color_code=$(awk -v p="$used_pct" 'BEGIN{ if (p>85) print 1; else if (p>=60) print 3; else print 2 }')
  pct_colored="$(color "$color_code" "$used_pct")"
  b=$(bar "$used_pct")

  rows+=("$used_gb|$remote|$used_gb|$trashed_gb|$free_gb|$total_gb|$pct_colored|$b")
done

# --- output ------------------------------------------------------------------
printf "\n"
printf "%-18s  %12s  %12s  %12s  %12s  %7s  %s\n" \
  "Remote" "Used (GB)" "Trashed (GB)" "Free (GB)" "Total (GB)" "Used%" "Usage Bar"
printf "%-18s  %12s  %12s  %12s  %12s  %7s  %s\n" \
  "------------------" "-----------" "-------------" "-----------" "-----------" "------" "------------------------------"

printf "%s\n" "${rows[@]}" | sort -t'|' -k1,1nr | while IFS="|" read -r _ remote used_gb trashed_gb free_gb total_gb pct_colored bar; do
  if [[ "$used_gb" == "ERR" ]]; then
    printf "%-18s  %s\n" "$remote" "$(color 1 "Error: rclone about failed")"
  else
    printf "%-18s  %12s  %12s  %12s  %12s  %6s%%  %s\n" \
      "$remote" "$used_gb" "$trashed_gb" "$free_gb" "$total_gb" "$pct_colored" "$bar"
  fi
done

printf "\n"
