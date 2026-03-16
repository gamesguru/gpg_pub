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

		# Output directory
		local output_dir="../.tmp"
		mkdir -p "$output_dir"

		local out_base="${output_dir}/found-email-key-${fpr}"
		local pub_file="${out_base}.pub"
		local asc_file="${out_base}.asc"

		# Copy public key
		if [ -f "$tmp_dir/email-key.pub" ]; then
			cp "$tmp_dir/email-key.pub" "$pub_file"
			echo "Saved public key: $pub_file"
		else
			echo "ERROR: Public key not found in $tmp_dir"
		fi

		# Export secret key (Heavy lifting only on match!)
		if [ -d "$tmp_dir/.gnupg" ]; then
			# Since we used %pubring, the key isn't in the DB. Import it first to link with secret key.
			gpg --homedir "$tmp_dir/.gnupg" --batch --import "$tmp_dir/email-key.pub" >/dev/null 2>&1

			# Create a combined ASCII armored file (Public + Secret)
			gpg --homedir "$tmp_dir/.gnupg" --batch --pinentry-mode loopback \
				--export --armor >"$asc_file"

			# Append ALL secret keys in the temp homedir
			gpg --homedir "$tmp_dir/.gnupg" --batch --pinentry-mode loopback \
				--export-secret-keys --armor >>"$asc_file"
			echo "Saved unified key: $asc_file"
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
# Use the same fixed temp dir as the generator script
TMP_DIR="/tmp/gpg-gen-email-$USER"

while true; do
	KEY_OUTPUT=$(./gpg-generate-email.sh)

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Find fingerprint:
	# Check for E starting on all 4 parts (indices 0, 10, 20, 30)
	# Regex: E (1) + 9 chars + E (1) + 9 chars + E (1) + 9 chars + E (1) + 9 chars
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -oE "E[A-F0-9]{9}E[A-F0-9]{9}E[A-F0-9]{9}E[A-F0-9]{9}" | head -n1)"

	if [ -n "$MATCH_1" ]; then
		# Add labels for clarity
		M1="${MATCH_1:+FPR:$MATCH_1}"

		# Pass matched parts and fixed TMP_DIR to handler
		check_matchnumber "$TMP_DIR" 1 "$M1"
	fi
done
