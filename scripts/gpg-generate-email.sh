#!/bin/bash
# gpg-generate-email.sh

NAME="${1:-Shane}"
EMAIL="${2:-shane@example.com}"

# Change to script's directory
cd "$(dirname "$0")" || exit

# Use a fixed temporary GNUPGHOME for simplicity/performance
# This allows spec.sh to access it without parsing output
_tmp_dir="/tmp/gpg-gen-email-$USER"

if [ -d "$_tmp_dir" ]; then
	export GNUPGHOME="$_tmp_dir/.gnupg"
	# Reuse dir, delete previous key by name to avoid accumulating keys
	# preserving the keyring files so we don't get "created" messages
	gpg --batch --yes --pinentry-mode loopback --delete-secret-and-public-keys "$NAME" >/dev/null 2>&1 || true
else
	mkdir -p "$_tmp_dir"
fi

export GNUPGHOME="$_tmp_dir/.gnupg"
mkdir -p "$GNUPGHOME"
# Ensure priv keys dir exists just in case
mkdir -p "$GNUPGHOME/private-keys-v1.d"
chmod 700 "$GNUPGHOME"

# Check for pinentry
if ! which pinentry >/dev/null; then
	echo "WARNING: pinentry not found in PATH"
fi

# Config for loopback
# Write config only if missing to avoid IO waste
if [ ! -f "$GNUPGHOME/gpg.conf" ]; then
	echo "pinentry-mode loopback" >"$GNUPGHOME/gpg.conf"
fi
if [ ! -f "$GNUPGHOME/gpg-agent.conf" ]; then
	echo "allow-loopback-pinentry" >"$GNUPGHOME/gpg-agent.conf"
fi

# Ensure gpg-agent is running for this home
gpg-agent --daemon --home-dir "$GNUPGHOME" >/dev/null 2>&1
# Reload to be safe
gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || true

cat <<EOT >batch-cmds
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
%pubring $_tmp_dir/email-key.pub
%commit
%echo done
EOT

# Generate the key
gpg --batch --gen-key batch-cmds

# Show the key for spec.sh to parse
gpg --show-key \
	--keyid-format long --with-subkey-fingerprints \
	"$_tmp_dir/email-key.pub"
