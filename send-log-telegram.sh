#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="$HOME/.config/linux-admin/telegram.env"
LOG_FILE="$HOME/linux-admin-lab/resource-check.log"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Telegram-конфигурация не найдена" >&2
    exit 2
fi

source "$CONFIG_FILE"

LOG_TAIL="$(tail -n 20 "$LOG_FILE" )"
MESSAGE=$(printf 'Последние записи мониторинга:\n%s' "$LOG_TAIL")

curl -fsS -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    >/dev/null

echo "Telegram: последние записи лога отправлены"
