#!/bin/bash -e

cat <<EOT >batch-cmds
%echo Generating a CV25519 encryption key
# %no-protection
Key-Type: EDDSA
Key-Curve: cv25519
Key-Usage: encrypt
Name-Real: ???
Name-Comment: encryption key - ??? [???]
Name-Email: ???
Expire-Date: 0
Passphrase: ???
%pubring cv25519.pub
# %secring foo.sec  # no-op as of v2.1
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOT

gpg --batch --gen-key batch-cmds
gpg --keyid-format long cv25519.pub
