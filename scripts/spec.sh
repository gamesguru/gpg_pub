#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")" || exit

# Function definitions
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

		# extract fingerprint from "FPR:..." arg for filename
		local fpr=""
		for a in "${@:2}"; do
			if [[ "$a" == FPR:* ]]; then
				fpr="${a#FPR:}"
				break
			fi
		done

		# Fallback if logic fails
		[ -z "$fpr" ] && fpr="unknown-$(date +%s)"

		local out_base="found-key-${fpr}"
		local pub_file="${out_base}.pub"
		local sec_file="${out_base}.sec"

		# Copy public key
		if [ -f "$tmp_dir/master-certify-only.pub" ]; then
			cp "$tmp_dir/master-certify-only.pub" "$pub_file"
			echo "Saved public key: $pub_file"
		else
			echo "ERROR: Public key not found in $tmp_dir"
		fi

		# Export secret key (Heavy lifting only on match!)
		if [ -d "$tmp_dir/.gnupg" ]; then
			# We know the name is Shane from generation script, or just export all (there's only one)
			gpg --homedir "$tmp_dir/.gnupg" --batch --pinentry-mode loopback \
				--export-secret-keys --armor >"$sec_file"
			echo "Saved secret key: $sec_file"
		else
			echo "ERROR: GPG home not found in $tmp_dir"
		fi

		# Cleanup
		rm -rf "$tmp_dir"
		exit
	fi
	# Cleanup on mismatch if we ever reached here (but logic handles it in caller)
	rm -rf "$tmp_dir"
}

# Main loop
while true; do
	KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh)

	# Extract TMPDIR from first line (e.g. TMPDIR:/tmp/gpg-gen-...)
	TMP_DIR=$(echo "$KEY_OUTPUT" | grep -oP '^TMPDIR:\K.*')

	# SPEC: FPR starts with 00, Subkey ID starts with 00
	FPR_PFX="0"
	SUBKEY_PFX="0"

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Find fingerprint: Look for 40-char hex string starting with 00
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -oE "${FPR_PFX}[A-F0-9]{39}" | head -n1)"

	# Find subkey ID: Look for cv25519/00...
	MATCH_2="$(echo "$CLEAN_OUTPUT" | grep -oE "cv25519/${SUBKEY_PFX}[A-F0-9]+" | cut -d/ -f2 | head -n1)"

	if [ -n "$MATCH_1" ] || [ -n "$MATCH_2" ]; then
		# Add labels for clarity
		M1="${MATCH_1:+FPR:$MATCH_1}"
		M2="${MATCH_2:+SUB:$MATCH_2}"

		# Pass matched parts and TMP_DIR to handler
		check_matchnumber "$TMP_DIR" 2 "$M1" "$M2"
	else
		# No match: clean up temp dir immediately
		[ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
	fi
done
