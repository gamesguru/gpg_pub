#!/bin/bash
# gpg-generate-certify-only-master.sh
NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

# Create temp dir
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR" || exit

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
