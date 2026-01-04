********************
 My public PGP keys
********************

Summary
-------

If a key is revoked (removed from this GitHub account),
it will have a retired date.

Keys appear in order of descending importance (frequency of use).
Retired keys will be moved to the bottom.

Run ``make csv`` to generate ``summary_of_keys.csv`` with details on all keys.

NOTE: You may be prompted to sign with an existing key.

If you don't have one, create one with ``gpg --expert --full-gen-key``.

In the ``scripts/legacy/`` folder, you can also use
``gpg-generate-ed-sce-keypair.sh`` (Ed25519 signing + Cv25519 encryption).

Save your main key as ultimately trusted (5) with
``gpg --edit-key <key_id>``, ``trust``, ``5``, ``save``.

Importing
=========

You may wish to first import the public GitHub webflow-key
used to sign web commits.

.. code-block:: bash

    curl https://github.com/web-flow.gpg | gpg --import
    gpg --lsign-key 4AEE18F83AFDEB23
    gpg --lsign-key B5690EEEBB952194

Import my **signing keys** to your keyring, and sign them as trusted.

.. code-block:: bash

    make install
    make sign

    # or, import from GitHub
    curl https://github.com/sjjctl.gpg | gpg --import
    curl https://github.com/gamesguru.gpg | gpg --import

They can be removed just as easily.

.. code-block:: bash

    make uninstall

    # or, delete based on GitHub
    curl https://github.com/sjjctl.gpg | gpg | grep '^ ' | gpg --batch --delete-keys --yes
    curl https://github.com/gamesguru.gpg | gpg | grep '^ ' | gpg --batch --delete-keys --yes

Verifying
=========

My commit signatures can then be verified
(``git show --show-signature``, ``git log --show-signature``, etc).

Keys may be retired at any time, if lost or compromised.

::

    make test

You may find the following git alias useful.

::

    git config --global alias.lgb "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%aN>%Creset%n' --abbrev-commit --date=relative"

Note that replacing ``%an`` with ``%aN`` and
``%ae`` with ``%aE`` is what tells git to respect
the ``.mailmap`` file, if it exists.  You can
configure a separate alias for ignoring the mailmap
and showing real names. Both git log and git show should
respect the mailmap by default.

::

    git config --global alias.lgbn = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)%an <%ae>%Creset%n' --abbrev-commit --date=relative


Deleting
========

Public keys can be easily removed from your keyring.

.. code-block:: bash

    make uninstall

Generating Your own PGP keys
----------------------------

All keys use Ed25519 for signing and Cv25519 for encryption.
RSA is no longer recommended for new keys.

Run the below script(s) for generating key(s).

.. code-block:: text

    scripts/legacy/
    ├── gpg-generate-ed-sce-keypair.sh   # Ed25519+Cv25519 key pair
    ├── gpg-generate-rsa4096-encryption.sh  # (legacy)

**NOTE:** Remove the ``%no-protection`` comment for faster key generation
(for testing purposes only, do not use insecure keys in production).

Then import, edit and run: ``passwd`` as well as ``adduid``, ``primary``,
``trust``, and finally ``save``.

.. code-block:: text

    gpg --import ed25519.pub
    gpg --edit-key <KEY_ID>
