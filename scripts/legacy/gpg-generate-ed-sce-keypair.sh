#!/bin/bash

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Change to temp dir to avoid polluting the script directory and permission errors
cd "$TMP_DIR" || exit

cat <<EOT >batch-cmds
# %echo Generating an ed25519/cv25519 signing and encryption key-pair
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: ???
Name-Comment: ???
Name-Email: ???
Expire-Date: 0
Passphrase: ???
%pubring ed-sce-keypair.pub
# %secring foo.sec  # no-op as of v2.1
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOT

# Redirect stderr to /dev/null to keep output clean, unless debugging
gpg --batch --gen-key batch-cmds 2>/dev/null || echo "GPG gen-key failed"
if [ -f ed-sce-keypair.pub ]; then
	gpg --show-key --keyid-format long --with-subkey-fingerprints ed-sce-keypair.pub
else
	echo "Files not found in $TMP_DIR"
	ls -la
fi
