#!/bin/bash
# gpg-generate-certify-only-master.sh
NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

# Change to script's directory
cd "$(dirname "$0")" || exit

# Use a temporary GNUPGHOME to avoid polluting the main keyring
_tmp_dir="$(pwd)/.tmp"
export GNUPGHOME="$_tmp_dir"
# trap 'rm -rf "$GNUPGHOME"' EXIT

cat <<EOT >batch-cmds
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: cert
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
%pubring "$_tmp_dir/master-certify-only.pub"
%commit
%echo done
EOT

# Generate the key
# rm -f master-certify-only.pub
gpg --batch --gen-key batch-cmds 2>/dev/null
# rm -f batch-cmds

# Show the key for spec.sh to parse
gpg --show-key \
	--keyid-format long --with-subkey-fingerprints \
	"$_tmp_dir/master-certify-only.pub"
