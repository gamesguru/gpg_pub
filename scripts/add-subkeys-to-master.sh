#!/bin/bash
# scripts/add-subkeys-to-master.sh
# Usage: ./add-subkeys-to-master.sh <path-to-master-sec-asc>

INPUT_KEY="$1"

if [ -z "$INPUT_KEY" ]; then
	echo "Usage: $0 <path-to-master-key.asc>"
	exit 1
fi

if [ ! -f "$INPUT_KEY" ]; then
	echo "Error: Key file '$INPUT_KEY' not found."
	exit 1
fi

# Setup Temp Home
TMP_DIR=$(mktemp -d -t gpg-subkeys-XXXXXX)
export GNUPGHOME="$TMP_DIR"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

echo "Using temp GPG home: $GNUPGHOME"

# Loopback config
echo "pinentry-mode loopback" >"$GNUPGHOME/gpg.conf"
echo "allow-loopback-pinentry" >"$GNUPGHOME/gpg-agent.conf"

# Start agent
gpg-agent --daemon --home-dir "$GNUPGHOME" >/dev/null 2>&1
gpg-connect-agent reloadagent /bye >/dev/null 2>&1

# Import Master Key
echo "Importing master key..."
gpg --batch --import "$INPUT_KEY"

# Get FPR
FPR=$(gpg --list-keys --with-colons | grep "^fpr" | head -n1 | cut -d: -f10)
echo "Master Key FPR: $FPR"

if [ -z "$FPR" ]; then
	echo "Error: Could not get fingerprint."
	rm -rf "$TMP_DIR"
	exit 1
fi

# Add Subkeys
# 1. Signing (Ed25519)
echo "Adding SIGNING subkey..."
gpg --batch --yes --pinentry-mode loopback --passphrase '' --quick-add-key "$FPR" ed25519 sign 0

# 2. Encryption (cv25519)
echo "Adding ENCRYPTION subkey..."
gpg --batch --yes --pinentry-mode loopback --passphrase '' --quick-add-key "$FPR" cv25519 encrypt 0

# 3. Authentication (Ed25519)
echo "Adding AUTHENTICATION subkey..."
gpg --batch --yes --pinentry-mode loopback --passphrase '' --quick-add-key "$FPR" ed25519 auth 0

# Export Results to ../.tmp/
OUT_DIR="$(dirname "$0")/../.tmp"
mkdir -p "$OUT_DIR"

FULL_KEY="${OUT_DIR}/full-keypair-${FPR}.asc"
LAPTOP_KEY="${OUT_DIR}/laptop-subkeys-${FPR}.asc"

# 1. Export FULL keypair (Master + Subkeys) -> For Vault
gpg --batch --pinentry-mode loopback --export-secret-keys --armor "$FPR" >"$FULL_KEY"
echo "Saved FULL keypair (Store Offline!): $FULL_KEY"

# 2. Export Laptop Keys (Subkeys ONLY) -> For Daily Use
# Logic: Export secret subkeys with valid commands using '!' syntax to exclude master secret
# Note: `gpg --export-secret-subkeys` usually exports master public + secret subkeys (but stubbed master secret).
gpg --batch --pinentry-mode loopback --export-secret-subkeys --armor "$FPR" >"$LAPTOP_KEY"
echo "Saved Laptop keys (Safe for device): $LAPTOP_KEY"

# Cleanup
gpg-connect-agent --home-dir "$GNUPGHOME" killagent /bye >/dev/null 2>&1
rm -rf "$TMP_DIR"
