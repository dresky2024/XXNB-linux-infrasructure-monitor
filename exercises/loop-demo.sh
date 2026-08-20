#!/usr/bin/env bash

if [ "$#" -q 0 ]; then
	echo "Передайте хотябы один аргумент"
	exit 2
fi

NUMBER=1

for ITEM in "$@"; do
	echo "$NUMBER-й аргумент: $ITEM"
	NUMBER=$((NUMBER + 1))
done	
