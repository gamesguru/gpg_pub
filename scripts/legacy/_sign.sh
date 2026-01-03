#!/bin/bash -x

cd "$(dirname "$0")"
cd .. # Lives in /scripts

dirs=$@
keys=$(find $dirs -name *.asc)

# Sign with one of your existing trusted keys
for key in ${keys[@]}; do
	key=$(basename "$key")
	fingerprints=$(gpg --fingerprint --with-colons "${key%.*}" | awk -F: '$1 == "fpr" {print $10;}')
	IFS=' ' read -r -a fingerprint <<<"$fingerprints"
	gpg --quick-lsign-key --yes $fingerprint || :
done
