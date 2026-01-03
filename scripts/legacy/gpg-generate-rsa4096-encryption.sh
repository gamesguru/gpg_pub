#!/bin/bash

cat <<EOT >batch-cmds
%echo Generating an RSA encryption key
# %no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: encrypt
Name-Real: ???
Name-Comment: encryption key - ??? [???]
Name-Email: ???
Expire-Date: 0
Passphrase: ???
%pubring rsa.pub
# %secring foo.sec  # no-op as of v2.1
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOT

gpg --batch --gen-key batch-cmds
gpg --keyid-format long rsa.pub
