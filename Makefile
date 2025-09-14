SHELL=/bin/bash
.DEFAULT_GOAL := _help


.PHONY: _help
_help:	## Comments like this, a tab character with two pound signs "<TAB>##" will show up unless you IGNORE_ME
ifeq ($(OS),Windows_NT)
	@echo This Makefile _help command does not support Windows right now!
	@echo   you can look at the Makefile, to see what it does
else
	@grep -h "##" $(MAKEFILE_LIST) | grep -v IGNORE_ME | sed -e 's/##//' | column -t -s $$'\t'
endif


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# List
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.PHONY: list
list:	## List the keys in this repository
	gpg --list-key --keyid-format LONG $(shell find keys/ -name *.asc -printf "%f\n" | xargs -I % basename % .asc)


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Install, sign, & remove
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.PHONY: install
install:	## Import my current signing keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Import current keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	./scripts/_import.sh \
	    keys/active/personal \
	    keys/active/work
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Import deprecated  keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	./scripts/_import.sh \
	    keys/deprecated/personal \
	    keys/deprecated/work

# TODO: Organize retired keys by year of retirement?
.PHONY: retired
retired:	## Install my retired signing keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Import retired keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	./scripts/_import.sh \
	    keys/retired/personal \
	    keys/retired/work

.PHONY: sign
sign:	## Locally sign my keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Sign all keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	./scripts/_sign.sh \
	    keys/active \
	    keys/deprecated \
	    keys/retired

.PHONY: uninstall
uninstall:	## Remove signing keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Remove all keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	./scripts/_delete.sh \
	    keys/active \
	    keys/deprecated \
	    keys/retired


.PHONY: github/install
github/install:	## Install my keys (based on GitHub GPG)
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Import GitHub keys
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Import GitHub web-flow signing key
	curl https://github.com/web-flow.gpg | gpg --import
	# Import my keys
	curl https://github.com/sjjctl.gpg | gpg --import
	curl https://github.com/gamesguru.gpg | gpg --import

KEYS_WORK_GH_RM ?= $(shell curl https://github.com/sjjctl.gpg | gpg --show-keys | grep '^ ')
KEYS_HOME_GH_RM ?= $(shell curl https://github.com/gamesguru.gpg | gpg --show-keys | grep '^ ')

.PHONY: github/uninstall
github/uninstall:	## Uninstall my keys (based on GitHub GPG)
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Remove GitHub keys (work)
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	@-for key in ${KEYS_WORK_GH_RM}; \
	    do gpg --batch --delete-keys --yes $$key; \
	done
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Remove GitHub keys (home/personal)
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	@-for key in ${KEYS_HOME_GH_RM}; \
	    do gpg --batch --delete-keys --yes $$key; \
	done


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Test and extras
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.PHONY: test
test:	## Do a self test using git log --show-signature
	git log --branches --graph --abbrev-commit --show-signature

.PHONY: check/only-self-sigs
check/only-self-sigs:
	# Test local keys (in git repository)
	@for key in $(shell find keys/ -name *.asc); do gpg --import --dry-run $$key; done
	# Test keys on GitHub GPG store
	curl https://github.com/sjjctl.gpg | gpg --import --dry-run
	curl https://github.com/gamesguru.gpg | gpg --import --dry-run



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##	------------------------------------------------------
##	Edit specific commands (export, import, delete), e.g.
##	KEY=3A6DD722E62891D0 make export
##	------------------------------------------------------
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
KEY ?=

GPG_PUB_DIR ?= ~/Documents/pub
GPG_SEC_DIR ?= ~/Documents/sec
GPG_PUB_KEY ?= $(shell find $(GPG_PUB_DIR) -name $(KEY).asc)
GPG_SEC_KEY ?= $(shell find $(GPG_SEC_DIR) -name $(KEY).asc)

.PHONY: export
export:	## Export an updated public/secret key pair
	# Clean up
	rm -rf tmp/*.asc
	# Check KEY is set
	test -n "${KEY}"
	# Check ${KEY} is found in "${GPG_PUB_DIR}" and "${GPG_SEC_DIR}"
	test -n "${GPG_PUB_KEY}"
	test -n "${GPG_SEC_KEY}"
	# Check we have the SECRET key
	gpg --list-secret-keys --keyid-format=long ${KEY}
	# Export ${KEY} (PUBLIC & SECRET KEYS)
	gpg --emit-version -a --export ${KEY} >${GPG_PUB_KEY}
	gpg --emit-version -a --export-secret-keys ${KEY} >tmp/${KEY}.asc
	# Secret key is done in separate step, (wrong password otherwise overwrites with empty secret key file)
	mv tmp/${KEY}.asc ${GPG_SEC_KEY}

.PHONY: import
import:	## Import a secret key (to edit the signatures/retire)
	# Check KEY is set
	test -n "${KEY}"
	# Check ${KEY} was found in ${GPG_SEC_DIR}
	test -n "${GPG_SEC_KEY}"
	# Import ${KEY} (SECRET KEY)
	gpg --import ${GPG_SEC_KEY}

.PHONY: delete
delete:	## Delete a retired secret key (after editing & exporting)
	# Check KEY is set
	test -n "${KEY}"
	# Delete ${KEY} (SECRET KEY)
	gpg --delete-secret-and-public-keys ${KEY}
