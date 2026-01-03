#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")"

# Function definitions
function check_matchnumber() {

	if [ "$#" -gt $1 ]; then
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
	KEY_OUTPUT=$(./gpg-generate-ed-sce-keypair.sh)
	sleep 0.1

	# SPEC: All four (key_id & fpr, and subkey_id & subkey_fpr) start with a given letter, i.e., B
	L=E
	MATCH_1="$(echo "$KEY_OUTPUT" | grep -m1 "ed25519/$L" | awk '{print $2}')"
	MATCH_2="$(echo "$KEY_OUTPUT" | grep -m1 "$L[A-Z,0-9]\{39\}$" | tail -n1 | cut -c 7-18)"
	MATCH_3="$(echo "$KEY_OUTPUT" | grep -m1 "cv25519/$L" | awk '{print $2}')"
	MATCH_4="$(echo "$KEY_OUTPUT" | grep -m2 "$L[A-Z,0-9]\{39\}$" | grep -v "$MATCH_2" | cut -c 7-18)"
	check_matchnumber 4 "$MATCH_1" "$MATCH_2" "$MATCH_3" "$MATCH_4"
	# -- END SPEC --

	# SPEC: All three start with at least four numbers
	# -- END SPEC --

	# SPEC: Only one key (fpr + id) to compare
	# L=B
	# MATCH_1="$(echo "$KEY_OUTPUT" | grep "ed25519/$L" | awk '{print $2}')"
	# MATCH_2="$(echo "$KEY_OUTPUT" | grep "^      $L[A-Z,0-9]\{39\}$" | cut -c 7-16)"
	# set -x
	# check_matchnumber 2 "$MATCH_1" "$MATCH_2"
	# set +x
	# -- END SPEC --

done

# OLD
# while [[ ! ("$(grep 'rsa4096/0BE' output.log)" || true) ]]; do
# 	# ./gpg-generate-rsa4096-encryption.sh | tee output.log;
# 	./gpg-generate-ed-sce-keypair.sh;
# done
