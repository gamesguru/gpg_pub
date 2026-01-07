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
		exit
	fi
}

# Main loop
while true; do
	KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh)
	sleep 0.1

	# SPEC: All four (key_id & fpr, and subkey_id & subkey_fpr) start with a given letter, i.e., B
	# L=E
	# MATCH_1="$(echo "$KEY_OUTPUT" | grep -m1 "ed25519/$L" | awk '{print $2}')"
	# MATCH_2="$(echo "$KEY_OUTPUT" | grep -m1 "$L[A-Z,0-9]\{39\}$" | tail -n1 | cut -c 7-18)"
	# MATCH_3="$(echo "$KEY_OUTPUT" | grep -m1 "cv25519/$L" | awk '{print $2}')"
	# MATCH_4="$(echo "$KEY_OUTPUT" | grep -m2 "$L[A-Z,0-9]\{39\}$" | grep -v "$MATCH_2" | cut -c 7-18)"
	# check_matchnumber 4 "$MATCH_1" "$MATCH_2" "$MATCH_3" "$MATCH_4"
	# -- END SPEC --

	# SPEC: All three start with at least four numbers
	# -- END SPEC --

	# SPEC: FPR starts with 00, Subkey ID starts with 00
	FPR_PFX="00"
	SUBKEY_PFX="00"

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Find fingerprint: Look for 40-char hex string on its own line starting with 00
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -E "^${FPR_PFX}[A-F0-9]{38}$")"

	# Find subkey ID: Look for cv25519/00...
	MATCH_2="$(echo "$CLEAN_OUTPUT" | grep -E "cv25519/${SUBKEY_PFX}[A-F0-9]*")"

	if [ -n "$MATCH_1" ] && [ -n "$MATCH_2" ]; then
		check_matchnumber 2 "$MATCH_1" "$MATCH_2"
	fi
	# -- END SPEC --

done

# OLD
# while [[ ! ("$(grep 'rsa4096/0BE' output.log)" || true) ]]; do
# 	# ./gpg-generate-rsa4096-encryption.sh | tee output.log;
# 	./gpg-generate-ed-sce-keypair.sh;
# done
