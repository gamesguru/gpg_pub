#!/bin/bash -e

cd "$(dirname "$0")"
cd .. # Lives in /scripts

dirs=$@

# Loop over each directory
for dir in ${dirs}; do
	# TODO: check if directory exists, before trying to find keys in it?
	printf "\n\e[1;32m$dir\e[0m\n"
	# Find keys in that directory (in alphabetical order)
	keys=$(find $dir -name *.asc | sort -h)
	# Import keys
	if [ "$keys" ]; then gpg --import --armor --yes $keys; fi
done
