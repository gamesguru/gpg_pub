#!/bin/bash -x

cd "$(dirname "$0")"
cd .. # Lives in /scripts

dirs=$@
keys=$(find $dirs -name *.asc)

# Delete keys
for key in ${keys[@]}; do
	key=$(basename "$key")
	gpg --batch --delete-keys --yes "${key%.*}"
done
