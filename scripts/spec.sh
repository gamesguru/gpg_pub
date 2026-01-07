#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")" || exit

# Function definitions
# Args: $1=TMP_DIR, $2=count, $3+=matches
function check_matchnumber() {
	local tmp_dir="$1"
	shift

	if [ "$#" -gt "$1" ]; then
		echo Matches: "${@:2}"

		for a in "${@:2}"; do
			test "$a" || {
				rm -rf "$tmp_dir"
				return
			}
		done

		echo "Matched spec! DONE!"
		# Save the .pub file to script directory
		cp "$tmp_dir/master-certify-only.pub" .
		echo "Saved: master-certify-only.pub"
		rm -rf "$tmp_dir"
		exit
	fi
	rm -rf "$tmp_dir"
}

# Main loop
while true; do
	KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh)

	# Extract temp dir path from first line
	TMP_DIR=$(echo "$KEY_OUTPUT" | grep -oP 'TMPDIR:\K.*')

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
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -oE "${FPR_PFX}[A-F0-9]{38}" | head -n1)"

	# Find subkey ID: Look for cv25519/00...
	MATCH_2="$(echo "$CLEAN_OUTPUT" | grep -oE "cv25519/${SUBKEY_PFX}[A-F0-9]+" | cut -d/ -f2 | head -n1)"

	if [ -n "$MATCH_1" ] || [ -n "$MATCH_2" ]; then
		# Add labels for clarity, but keep empty if no match to preserve check_matchnumber logic
		M1="${MATCH_1:+FPR:$MATCH_1}"
		M2="${MATCH_2:+SUB:$MATCH_2}"
		check_matchnumber "$TMP_DIR" 2 "$M1" "$M2"
	else
		# No match at all, clean up temp dir
		rm -rf "$TMP_DIR"
	fi
	# -- END SPEC --

done

# OLD
# while [[ ! ("$(grep 'rsa4096/0BE' output.log)" || true) ]]; do
# 	# ./gpg-generate-rsa4096-encryption.sh | tee output.log;
# 	./gpg-generate-ed-sce-keypair.sh;
# done
