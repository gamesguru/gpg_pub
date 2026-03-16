#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")" || exit

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <0-9A-F>"
	exit 1
fi

# Get the character, uppercase it
CHAR=$(echo "$1" | tr 'a-f' 'A-F')

if ! [[ "$CHAR" =~ ^[0-9A-F]$ ]]; then
	echo "Error: Input must be a single hex character (0-9, A-F)"
	exit 1
fi

echo "Searching for keys matching prefix and Key ID starting with: $CHAR"

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

		local out_base="${output_dir}/found-key-${fpr}"
		local pub_file="${out_base}.pub"
		local asc_file="${out_base}.asc"

		# Copy public key
		if [ -f "$tmp_dir/master-certify-only.pub" ]; then
			cp "$tmp_dir/master-certify-only.pub" "$pub_file"
			echo "Saved public key: $pub_file"
		else
			echo "ERROR: Public key not found in $tmp_dir"
		fi

		# Export secret key (Heavy lifting only on match!)
		if [ -d "$tmp_dir/.gnupg" ]; then
			# Since we used %pubring, the key isn't in the DB. Import it first to link with secret key.
			gpg --homedir "$tmp_dir/.gnupg" --batch --pinentry-mode loopback \
				--import "$tmp_dir/master-certify-only.pub" >/dev/null 2>&1

			# Create a combined ASCII armored file (Public + Secret)
			# Export public key properly as ASCII armor (since original is binary)
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
TMP_DIR="/tmp/gpg-gen-search-$USER"

while true; do
	KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh)

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Find fingerprint:
	# 1. Starts with $CHAR (Prefix)
	# 2. Key ID (last 16 chars, i.e., char 24) starts with $CHAR
	# Regex: $CHAR (1) + 23 chars + $CHAR (1) + 15 chars = 40 chars
	MATCH_1="$(echo "$CLEAN_OUTPUT" | grep -oE "${CHAR}[A-F0-9]{23}${CHAR}[A-F0-9]{15}" | head -n1)"

	if [ -n "$MATCH_1" ]; then
		# Add labels for clarity
		M1="${MATCH_1:+FPR:$MATCH_1}"

		# Pass matched parts and fixed TMP_DIR to handler
		check_matchnumber "$TMP_DIR" 1 "$M1"
	fi
done
