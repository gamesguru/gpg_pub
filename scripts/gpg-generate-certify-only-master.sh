#!/bin/bash
# gpg-generate-certify-only-master.sh
NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

cat <<EOT >batch-cmds
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: cert
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
# This saves the public key to your CWD like your old script
%pubring master-certify-only.pub
%commit
EOT

# Generate the key
# gpg --batch --status-fd 1 --gen-key batch-cmds
gpg --batch --gen-key batch-cmds
rm batch-cmds
