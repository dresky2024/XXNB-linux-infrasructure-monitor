#!/usr/bin/env bash

LOG_FILE="/home/trainee/linux-admin-lab/resource-check.log"
MONITOR="/home/trainee/linux-admin-lab/resource-check.sh"

mkdir -p "$(dirname "$LOG_FILE")"

auto_log() {
    while IFS= read -r line; do
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
    done >> "$LOG_FILE"
}

"$MONITOR" 2>&1 | auto_log

exit "${PIPESTATUS[0]}"
