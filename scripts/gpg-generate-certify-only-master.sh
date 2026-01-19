#!/bin/bash
# gpg-generate-certify-only-master.sh

NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

# Change to script's directory
cd "$(dirname "$0")" || exit

# Use a temporary GNUPGHOME to avoid polluting the main keyring
# Use a temporary GNUPGHOME to avoid polluting the main keyring
_tmp_dir="/tmp/gpg-gen-$(date +%s)"
export GNUPGHOME="$_tmp_dir"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Check for pinentry
if ! which pinentry >/dev/null; then
	echo "WARNING: pinentry not found in PATH"
fi

# Config for loopback
# pinentry-mode loopback is a GPG option, ensure it is set
echo "pinentry-mode loopback" >"$GNUPGHOME/gpg.conf"
# allow-loopback-pinentry is an AGENT option
echo "allow-loopback-pinentry" >"$GNUPGHOME/gpg-agent.conf"

# Debug info
echo "GNUPGHOME: $GNUPGHOME"
ls -ld "$GNUPGHOME"

# Ensure gpg-agent is running (implicitly by gpg)
# gpg-agent --daemon --verbose --home-dir "$GNUPGHOME" 2>&1

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
%pubring $_tmp_dir/master-certify-only.pub
%commit
%echo done
EOT

# Generate the key
gpg --batch --gen-key batch-cmds

# Output TMPDIR for spec.sh to capture
echo "TMPDIR:$_tmp_dir"

# Show the key for spec.sh to parse
gpg --show-key \
	--keyid-format long --with-subkey-fingerprints \
	"$_tmp_dir/master-certify-only.pub"
