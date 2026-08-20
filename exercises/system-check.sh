#!/usr/bin/env bash

SERVICE="${1:-}"


if [ -z "$SERVICE" ]; then
	echo "Использование: $0 <имя-сервиса>"
	exit 2
fi

if systemctl is active --quiet "$SERVICE"; then
	echo "OK: сервис $SERVICE запущен"
	exit 0

elif systemctl list-unit-files --type=service | grep -q "^${SERVICE}.service"; then
	echo "WARNING: сервис $SERVICE установлен, но не запущен"
	exit 1
else
	echo "ERROR: сервис $SERVICE не найден"
	exit 3
fi
