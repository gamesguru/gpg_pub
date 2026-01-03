#!/bin/bash

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

gpg --batch --gen-key batch-cmds
gpg --show-key --keyid-format long --with-subkey-fingerprints ed-sce-keypair.pub
