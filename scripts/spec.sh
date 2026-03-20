#!/bin/bash

# Change to script's directory
cd "$(dirname "$0")" || exit

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <master|email> <0-9A-F>"
	echo "Example: $0 master 0"
	echo "Example: $0 email D"
	exit 1
fi

TYPE="$1"
# Get the character, uppercase it
CHAR=$(echo "$2" | tr 'a-f' 'A-F')

if [[ "$TYPE" != "master" && "$TYPE" != "email" ]]; then
	echo "Error: Type must be either 'master' or 'email'"
	exit 1
fi

if ! [[ "$CHAR" =~ ^[0-9A-F]$ ]]; then
	echo "Error: Input must be a single hex character (0-9, A-F)"
	exit 1
fi

echo "Mode: $TYPE"
echo "Searching for keys matching prefix and Key ID starting with: $CHAR"

# Function definitions
function check_matchnumber() {
	local tmp_dir="$1"
	local pubkey_name="$2"
	shift 2

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

		local out_base="${output_dir}/found-${TYPE}-key-${fpr}"
		local pub_file="${out_base}.pub"
		local asc_file="${out_base}.asc"

		# Copy public key
		if [ -f "$tmp_dir/$pubkey_name" ]; then
			cp "$tmp_dir/$pubkey_name" "$pub_file"
			echo "Saved public key: $pub_file"
		else
			echo "ERROR: Public key not found in $tmp_dir ($pubkey_name)"
		fi

		# Export secret key (Heavy lifting only on match!)
		if [ -d "$tmp_dir/.gnupg" ]; then
			# Since we used %pubring, the key isn't in the DB. Import it first to link with secret key.
			gpg --homedir "$tmp_dir/.gnupg" --batch --import "$tmp_dir/$pubkey_name" >/dev/null 2>&1

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

if [ "$TYPE" == "master" ]; then
	TMP_DIR="/tmp/gpg-gen-search-$USER"
	PUBKEY_NAME="master-certify-only.pub"

	while true; do
		KEY_OUTPUT=$(./gpg-generate-certify-only-master.sh 2>/dev/null)

		# Clean output: remove spaces to handle space-separated fingerprints
		CLEAN_OUTPUT="$(echo "$KEY_OUTPUT" | tr -d ' ')"

		# Extract the 40-character fingerprint
		FPR="$(echo "$CLEAN_OUTPUT" | grep -oE "[A-F0-9]{40}" | head -n1)"

		if [ -n "$FPR" ]; then
			ID="${FPR:24}"

			MATCH_COUNT=0
			[[ "${FPR:0:1}"  == "$CHAR" ]] && ((MATCH_COUNT++))
			[[ "${FPR:24:1}" == "$CHAR" ]] && ((MATCH_COUNT++))

			PROGRESS=""
			[[ "${FPR:0:1}"  == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."
			[[ "${FPR:24:1}" == "$CHAR" ]] && PROGRESS+="$CHAR" || PROGRESS+="."

			if [ "$MATCH_COUNT" -ge 1 ]; then
				echo -e "\n*** Match [$PROGRESS] ($MATCH_COUNT/2) ***"
				echo "   Key: $FPR (ID: $ID)"
			else
				echo -ne "\rSearching... [$PROGRESS] ID=$ID\033[K"
			fi

			if [ "$MATCH_COUNT" -eq 2 ]; then
				echo -e "\nFull match found!"
				check_matchnumber "$TMP_DIR" "$PUBKEY_NAME" 1 "FPR:$FPR"
			fi
		fi
	done

elif [ "$TYPE" == "email" ]; then
	TMP_DIR="/tmp/gpg-gen-email-$USER"
	PUBKEY_NAME="email-key.pub"

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
				check_matchnumber "$TMP_DIR" "$PUBKEY_NAME" 1 "FPR:$P_FPR" "FPR:$S_FPR"
			fi
		fi
	done
fi
