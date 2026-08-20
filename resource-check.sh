#!/usr/bin/env bash


DISK_THRESHOLD=80
INODE_THRESHOLD=80	
CPU_THRESHOLD=80
RAM_THRESHOLD=80

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    BLUE=$'\033[34m'
    RESET=$'\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    RESET=''
fi

status_line() {
    local LEVEL="$1"
    shift
    local TEXT="$*"

    case "$LEVEL" in
        OK)
            printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$TEXT"
            ;;
        WARN)
            printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$TEXT"
            ;;
        ERROR)
            printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$TEXT"
            ;;
        INFO)
            printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$TEXT"
            ;;
        *)
            printf '[UNKNOWN] %s\n' "$TEXT"
            ;;
    esac
}

EMAIL_TO="dresky2022@gmail.com"
TELEGRAM_CONFIG="$HOME/.config/linux-admin/telegram.env"

STATE_DIR="$HOME/.cache/linux-admin"
STATE_FILE="$STATE_DIR/resource-check.state"

PING_HOST="1.1.1.1"
TCP_HOST="example.com"
TCP_PORT=443
HTTP_URL="https://example.com"
SERVICES=("ssh" "nginx")

mkdir -p "$STATE_DIR"
if [ ! -f "$TELEGRAM_CONFIG" ]; then
    echo "ERROR: Telegram-конфигурация не найдена: $TELEGRAM_CONFIG"
    exit 2
fi

# shellcheck disable=SC1090
source "$TELEGRAM_CONFIG"

chmod 700 "$STATE_DIR"

send_email( ) {
    local SUBJECT="$1"
    local BODY="$2"

    printf '%b\n' "$BODY" | mail -s "$SUBJECT" "$EMAIL_TO"
}
send_telegram() {
    local MESSAGE="$1"

    curl -fsS -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MESSAGE}" \
        >/dev/null
}

send_all_notifications( ) {
    local SUBJECT="$1"
    local BODY="$2"
    local FAILED=0

    if send_email "$SUBJECT" "$BODY"; then
        echo "EMAIL: уведомление отправлено"
    else
        echo "ERROR: email-уведомление не отправлено"
        FAILED=1
    fi

    if send_telegram "$SUBJECT"$'\n'"$BODY"; then
        echo "TELEGRAM: уведомление отправлено"
    else
        echo "ERROR: Telegram-уведомление не отправлено"
        FAILED=1
    fi

    return "$FAILED"
}


DISK_USAGE=$(df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}')
INODE_USAGE=$(df -Pi / | awk 'NR==2 {gsub("%", "", $5); print $5}')

MEMORY_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", ($3 / $2) * 100}')

if [ -z "$DISK_USAGE" ] || [ -z "$MEMORY_USAGE" ]; then
    echo "ERROR: не удалось получить данные о ресурсах"
    exit 2
fi

# Первый замер CPU
read -r _ U1 N1 S1 I1 IO1 IRQ1 SIRQ1 ST1 _ < /proc/stat

sleep 1

# Второй замер CPU
read -r _ U2 N2 S2 I2 IO2 IRQ2 SIRQ2 ST2 _ < /proc/stat

TOTAL1=$((U1 + N1 + S1 + I1 + IO1 + IRQ1 + SIRQ1 + ST1))
TOTAL2=$((U2 + N2 + S2 + I2 + IO2 + IRQ2 + SIRQ2 + ST2))

IDLE1=$((I1 + IO1))
IDLE2=$((I2 + IO2))

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

if [ "$TOTAL_DIFF" -gt 0 ]; then
    CPU_USAGE=$(awk -v total="$TOTAL_DIFF" -v idle="$IDLE_DIFF" \
        'BEGIN { printf "%.0f", (1 - idle / total) * 100 }')
else
    CPU_USAGE=0
fi


CURRENT_STATE="OK"

if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}Диск заполнен на ${DISK_USAGE}%\n"
fi

if [ "$INODE_USAGE" -ge "$INODE_THRESHOLD" ]; then
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}Inode использованы на ${INODE_USAGE}%\n"
fi

if [ "$CPU_USAGE" -ge "$CPU_THRESHOLD" ]; then
    status_line WARN "CPU загружен на ${CPU_USAGE}%"	
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}CPU загружен на ${CPU_USAGE}%\n"
fi

if [ "$MEMORY_USAGE" -ge "$RAM_THRESHOLD" ]; then
    status_line WARN "RAM используется на ${MEMORY_USAGE}%"
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}RAM используется на ${MEMORY_USAGE}%\n"
fi


# Проверка ping
if ping -c 2 -W 2 "$PING_HOST" >/dev/null 2>&1; then
    status_line OK "PING OK: $PING_HOST"
else
    status_line ERROR "PING ERROR: $PING_HOST недоступен"
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}Ping: хост $PING_HOST недоступен\n"
fi

# Проверка TCP-порта
if timeout 5 bash -c "</dev/tcp/$TCP_HOST/$TCP_PORT" >/dev/null 2>&1; then
    status_line OK "TCP OK: $TCP_HOST:$TCP_PORT"
else
    status_line ERROR "TCP ERROR: $TCP_HOST:$TCP_PORT недоступен"
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}TCP: порт $TCP_HOST:$TCP_PORT недоступен\n"
fi

# Проверка HTTP/HTTPS
HTTP_CODE=$(curl -L -sS -o /dev/null -w '%{http_code}' --max-time 10 "$HTTP_URL" 2>/dev/null || echo "000" )

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    status_line OK "HTTP OK: $HTTP_URL, код $HTTP_CODE"
else
    status_line ERROR "HTTP ERROR: $HTTP_URL, код $HTTP_CODE"
    CURRENT_STATE="ALERT"
    MESSAGE="${MESSAGE}HTTP: $HTTP_URL недоступен, код $HTTP_CODE\n"
fi

if [ -f "$STATE_FILE" ]; then
    PREVIOUS_STATE=$(cat "$STATE_FILE")
else
    PREVIOUS_STATE="UNKNOWN"
fi

for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE"; then
        status_line OK "SERVICE OK: $SERVICE запущен"
    else
        status_line ERROR "SERVICE ERROR: $SERVICE не запущен"
        CURRENT_STATE="ALERT"
        MESSAGE="${MESSAGE}Служба $SERVICE не запущена или недоступна.\n"
    fi
done


echo "Диск: ${DISK_USAGE}%"
echo "Inode: ${INODE_USAGE}%"
echo "CPU: ${CPU_USAGE}%"
echo "RAM: ${MEMORY_USAGE}%"

status_line INFO "Диск: ${DISK_USAGE}%, Inode: ${INODE_USAGE}%, CPU: ${CPU_USAGE}%, RAM: ${MEMORY_USAGE}%"

status_line INFO "Проверка завершена"


if [ "$CURRENT_STATE" = "ALERT" ] && [ "$PREVIOUS_STATE" != "ALERT" ]; then
    if send_all_notifications "Linux alert: проблема с ресурсами или сетью" "$MESSAGE"; then
        status_line ERROR "ALERT: отправлено аварийное уведомление"
        printf '%s\n' "$CURRENT_STATE" > "$STATE_FILE"
    else
        status_line ERROR "ERROR: не удалось отправить аварийное уведомление"
        exit 3
    fi


elif [ "$CURRENT_STATE" = "OK" ] && [ "$PREVIOUS_STATE" = "ALERT" ]; then
    RECOVERY_MESSAGE="Система восстановлена.\nДиск: ${DISK_USAGE}%\nПамять: ${MEMORY_USAGE}%\nHTTP: $HTTP_URL отвечает, код $HTTP_CODE"

    if send_all_notifications "Linux recovery: сервисы восстановлены" "$RECOVERY_MESSAGE"; then
        status_line OK "RECOVERY: отправлено уведомление о восстановлении"
        printf '%s\n' "$CURRENT_STATE" > "$STATE_FILE"
    else
        status_line OK "ERROR: не удалось отправить уведомление о восстановлении"
        exit 3
    fi

else
    printf '%s\n' "$CURRENT_STATE" > "$STATE_FILE"
    echo "OK: ресурсы и сетевые проверки в норме"
fi

exit 0
