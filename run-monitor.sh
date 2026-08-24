#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/resource-check.log"
MONITOR="$SCRIPT_DIR/resource-check.sh"

while IFS= read -r line; do
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
done < <("$MONITOR" 2>&1) >> "$LOG_FILE"
