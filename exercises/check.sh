#!/usr/bin/env bash



FILE="${1:-}"


if [ -z "$FILE" ]; then
	echo "Использование: $0 <путь_к_файлу>"
	exit 2

fi


if [ -f "$FILE" ]; then 
	echo "Файл $FILE существует"
	ls -lh "$FILE"
else
	echo "Файл $FILE не найден"
	exit 1
fi 
