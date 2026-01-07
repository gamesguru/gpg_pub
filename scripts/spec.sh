#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")" || exit

# Function definitions
function check_matchnumber() {
	if [ "$#" -gt "$1" ]; then
		echo Matches: "${@:2}"

		for a in "${@:2}"; do
			test "$a" || return
		done

		echo "Matched spec! DONE!"
		# Explicitly save the key to a unique file to prevent overwriting
		cp master-certify-only.pub found-key.pub
		echo "Copied to: found-key.pub"
		exit
	fi
}

# Main loop
while true; do
	KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh)
	sleep 0.1

	# SPEC: FPR starts with 00, Subkey ID starts with 00
	FPR_PFX="00"
	SUBKEY_PFX="00"

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Find fingerprint: Look for 40-char hex string starting with 00
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -oE "${FPR_PFX}[A-F0-9]{38}" | head -n1)"

	# Find subkey ID: Look for cv25519/00...
	MATCH_2="$(echo "$CLEAN_OUTPUT" | grep -oE "cv25519/${SUBKEY_PFX}[A-F0-9]+" | cut -d/ -f2 | head -n1)"

	if [ -n "$MATCH_1" ] || [ -n "$MATCH_2" ]; then
		# Add labels for clarity
		M1="${MATCH_1:+FPR:$MATCH_1}"
		M2="${MATCH_2:+SUB:$MATCH_2}"
		check_matchnumber 2 "$M1" "$M2"
	fi
done
