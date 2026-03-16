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

echo "Searching for email keys matching prefix and Key ID starting with: $CHAR"

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
	KEY_OUTPUT=$(./gpg-generate-email.sh 2>/dev/null)

	# Clean output: remove spaces to handle space-separated fingerprints
	CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

	# Extract all 40-character fingerprints (Primary and Subkey)
	FPRS=($(echo "$CLEAN_OUTPUT" | grep -oE "[A-F0-9]{40}"))

	if [ "${#FPRS[@]}" -ge 2 ]; then
		P_FPR="${FPRS[0]}"
		S_FPR="${FPRS[1]}"

		# Key IDs are the last 16 characters
		P_ID="${P_FPR:24}"
		S_ID="${S_FPR:24}"

		# Check for the character at:
		# 1. Start of Primary Fingerprint
		# 2. Start of Primary Key ID (index 24 of FPR)
		# 3. Start of Subkey Fingerprint
		# 4. Start of Subkey Key ID (index 24 of subkey FPR)
		MATCH_COUNT=0
		[[ "${P_FPR:0:1}"  == "$CHAR" ]] && ((MATCH_COUNT++))
		[[ "${P_FPR:24:1}" == "$CHAR" ]] && ((MATCH_COUNT++))
		[[ "${S_FPR:0:1}"  == "$CHAR" ]] && ((MATCH_COUNT++))
		[[ "${S_FPR:24:1}" == "$CHAR" ]] && ((MATCH_COUNT++))

		# Display progress with labels for the 4 positions
		PROGRESS=""
		[[ "${P_FPR:0:1}"  == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."
		[[ "${P_FPR:24:1}" == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."
		[[ "${S_FPR:0:1}"  == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."
		[[ "${S_FPR:24:1}" == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."

		if [ "$MATCH_COUNT" -ge 2 ]; then
			echo -e "\n*** Match [$PROGRESS] ($MATCH_COUNT/4) ***"
			echo "   Primary: $P_FPR (ID: $P_ID)"
			echo "   Subkey:  $S_FPR (ID: $S_ID)"
		else
			echo -ne "\rSearching... [$PROGRESS] P=$P_ID S=$S_ID\033[K"
		fi

		if [ "$MATCH_COUNT" -eq 4 ]; then
			echo -e "\nFull match found!"
			check_matchnumber "$TMP_DIR" 1 "FPR:$P_FPR" "FPR:$S_FPR"
		fi
	fi
done
