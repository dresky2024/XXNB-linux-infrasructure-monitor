#!/usr/bin/env bash


if [ "$#" -eq 0 ]; then
	echo "Использование: $0 <file1> <file2> ..."
	exit 2
fi

for FILE in "$@"; do
	if [ -f "$FILE" ]; then
		echo "OK: file is true - $FILE"
	elif [ -d "$FILE" ]; then
		echo "OK: directory is true -$FILE"
	else
		echo "ERROR: directory not find - $FILE"
	fi
done
 
