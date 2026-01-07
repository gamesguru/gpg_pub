#!/bin/bash
# gpg-generate-certify-only-master.sh
NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

# Create temp dir (no trap - let caller decide to clean up or keep)
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit

# Print temp dir path first so caller can access the .pub file if needed
echo "TMPDIR:$TMP_DIR"

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
# This saves the public key to your CWD like your old script
%pubring master-certify-only.pub
%commit
%echo done
EOT

# Generate the key
# Redirect stderr to /dev/null to clean up output
gpg --batch --gen-key batch-cmds 2>/dev/null

# Show the key for spec.sh to parse
gpg --show-key --keyid-format long --with-subkey-fingerprints master-certify-only.pub
