SHELL:=/bin/bash
.DEFAULT_GOAL := _help
.SHELLFLAGS = -ec

# Scripts
GPG_MANAGER := $(PYTHON) ./scripts/gpg_manager.py
# Optional arguments passed to GPG Manager (e.g. make uninstall ARGS="--dry-run")
ARGS ?=

.PHONY: _help help
help: _help
_help:
	@printf "\nUsage: make <command>, valid commands:\n\n"
	@awk 'BEGIN {FS = ":.*?##H "}; \
		/##H/ && !/@awk.*?##H/ { \
			target=$$1; doc=$$2; \
			category="General"; \
			if (doc ~ /^@/) { \
				category=substr(doc, 2, index(doc, " ")-2); \
				doc=substr(doc, index(doc, " ")+1); \
			} \
			if (length(target) > max) max = length(target); \
			targets[NR] = target; docs[NR] = doc; cats[NR] = category; \
		} \
		END { \
			last_cat = ""; \
			for (i = 1; i <= NR; i++) { \
				if (cats[i] != "") { \
					if (cats[i] != last_cat) { \
						printf "\n\033[1;36m%s Commands:\033[0m\n", cats[i]; \
						last_cat = cats[i]; \
					} \
					printf "  \033[1;34m%-*s\033[0m  %s\n", max, targets[i], docs[i]; \
				} \
			} \
			print ""; \
		}' $(MAKEFILE_LIST)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Print Helpers
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
define print_err
	printf "\033[1;31m%s\033[0m\n" "$(1)"
endef

define print_warn
	printf "\033[1;33m%s\033[0m\n" "$(1)"
endef

define print_success
	printf "\033[1;34m✓ %s\033[0m\n" "$(1)"
endef

define print_info
	printf "\033[1;36m%s\033[0m\n" "$(1)"
endef

.PHONY: vars
vars:	##H @General Debug: Print project variables
	@$(foreach v,$(sort $(.VARIABLES)), \
		$(if $(filter file command line override,$(origin $(v))), \
			$(info $(v) = $($(v))) \
		) \
	)

.PHONY: keys
keys:	##H @General List the keys in this repository
	gpg --list-key --keyid-format LONG $(shell find keys/ -name *.asc -printf "%f\n" | xargs -I % basename % .asc)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Install, sign, & remove
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.PHONY: install
install: _venv	##H @GPG Import my current signing keys
	@$(call print_info,Importing current keys...)
	$(GPG_MANAGER) import keys/active/personal keys/active/work $(ARGS)
	@$(call print_info,Importing deprecated keys...)
	$(GPG_MANAGER) import keys/deprecated/personal keys/deprecated/work $(ARGS)
	@$(call print_success,Install complete.)

.PHONY: retired
retired: _venv	##H @GPG Import my retired signing keys
	@$(call print_info,Importing retired keys...)
	$(GPG_MANAGER) import keys/retired/personal keys/retired/work $(ARGS)
	@$(call print_success,Retired keys imported.)

.PHONY: sign
sign: _venv	##H @GPG Locally sign my keys
	@$(call print_info,Signing all keys...)
	$(GPG_MANAGER) sign keys/active keys/deprecated keys/retired $(ARGS)
	@$(call print_success,Signing complete.)

.PHONY: uninstall
uninstall: _venv	##H @GPG Remove signing keys
	@$(call print_info,Removing all keys...)
	$(GPG_MANAGER) delete keys/active keys/deprecated keys/retired $(ARGS)
	@$(call print_success,Uninstall complete.)


.PHONY: github/install
github/install:	##H @GPG Install my keys (based on GitHub GPG)
	# Import GitHub web-flow signing key
	curl https://github.com/web-flow.gpg | gpg --import
	# Import my keys
	curl https://github.com/sjjctl.gpg | gpg --import
	curl https://github.com/gamesguru.gpg | gpg --import

KEYS_WORK_GH_RM ?= $(shell curl https://github.com/sjjctl.gpg | gpg --show-keys | grep '^ ')
KEYS_HOME_GH_RM ?= $(shell curl https://github.com/gamesguru.gpg | gpg --show-keys | grep '^ ')

.PHONY: github/uninstall
github/uninstall:	##H @GPG Uninstall my keys (based on GitHub GPG)
	@-for key in ${KEYS_WORK_GH_RM}; \
	    do gpg --batch --delete-keys --yes $$key; \
	done
	@-for key in ${KEYS_HOME_GH_RM}; \
	    do gpg --batch --delete-keys --yes $$key; \
	done

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Edit specific commands
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
KEY ?=
GPG_PUB_DIR ?= ~/Documents/pub
GPG_SEC_DIR ?= ~/Documents/sec
GPG_PUB_KEY ?= $(shell find $(GPG_PUB_DIR) -name $(KEY).asc)
GPG_SEC_KEY ?= $(shell find $(GPG_SEC_DIR) -name $(KEY).asc)

.PHONY: export
export:	##H @GPG Export an updated public/secret key pair
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

.PHONY: import-secret
import-secret:	##H @GPG Import a secret key (to edit)
	# Check KEY is set
	test -n "${KEY}"
	# Check ${KEY} was found in ${GPG_SEC_DIR}"
	test -n "${GPG_SEC_KEY}"
	# Import ${KEY} (SECRET KEY)
	gpg --import ${GPG_SEC_KEY}

.PHONY: delete-secret
delete-secret:	##H @GPG Delete a retired secret key
	# Check KEY is set
	test -n "${KEY}"
	# Delete ${KEY} (SECRET KEY)
	gpg --delete-secret-and-public-keys ${KEY}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Test and extras
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.PHONY: test
test: 	##H @Dev Test local keys and GitHub keys, show git log sigs
	# Test local keys (in git repository)
	@for key in $(shell find keys/ -name *.asc); do gpg --import --dry-run $$key; done
	# Test keys on GitHub GPG store
	curl https://github.com/sjjctl.gpg | gpg --import --dry-run
	curl https://github.com/gamesguru.gpg | gpg --import --dry-run
	@$(call print_success,Check complete.)
	git --no-pager log -n 20 --branches --graph --abbrev-commit --show-signature

.PHONY: check/parity
check/parity: _venv ##H @Dev Verify parity between local keys and GitHub keys
	@$(call print_info,Verifying GitHub key parity...)
	$(GPG_MANAGER) verify-parity $(ARGS)
	@$(call print_success,Parity verified.)

.PHONY: sync
sync: _venv ##H @Dev Check parity with GitHub and Secret Store
	@$(call print_info,Checking key parity...)
	$(GPG_MANAGER) verify-parity $(ARGS)

# Virtual Environment
VENV := .venv
PYTHON := $(VENV)/bin/python3
PIP := $(VENV)/bin/pip

.PHONY: _venv
_venv:
	@test -d $(VENV) || (echo "Virtual environment not found. Run 'make deps'." && exit 1)
	# test that which python points to the virtual environment
	@test $(PYTHON) -ef $(VENV)/bin/python3 || (echo "Virtual environment not found. Run 'make deps'." && exit 1)

.PHONY: deps
deps:	##H @Dev Install dev dependencies
	@$(call print_info,Installing dependencies...)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install -r requirements-dev.txt
	@$(call print_success,Dependencies installed.)

.PHONY: format
format: _venv	##H @Dev Format code with Black, Ruff, and isort
	@$(call print_info,Formatting code...)
	$(VENV)/bin/isort .
	$(VENV)/bin/black .
	$(VENV)/bin/ruff check --fix .
	@$(call print_success,Formatting complete.)

.PHONY: lint
lint: _venv	##H @Dev Lint scripts (Ruff, Black, isort check)
	@$(call print_info,Linting code...)
	@# Shellcheck
	shellcheck scripts/*.sh
	@# isort check
	$(VENV)/bin/isort --check-only --diff .
	@# Black check
	$(VENV)/bin/black --check .
	@# Ruff check
	$(VENV)/bin/ruff check .
	@$(call print_success,Linting complete.)


.PHONY: csv
csv:	##H @Reports Generate summary_of_keys.csv from key files
	@echo "key_id,fingerprint,algorithm,capabilities,created,primary_uid,category,status" > summary_of_keys.csv
	@for key in $$(find keys/ -name '*.asc' | sort); do \
	    gpg --show-keys --with-colons "$$key" 2>/dev/null | awk -F: -v file="$$key" ' \
	        /^pub/ { algo=$$4; caps=$$12; created=$$6 } \
	        /^fpr/ && !fpr { fpr=$$10 } \
	        /^uid/ && !uid { uid=$$10 } \
	        END { \
	            if (fpr) { \
	                key_id=substr(fpr, length(fpr)-15); \
	                n=split(file, parts, "/"); \
	                category=parts[2]; status=parts[3]; \
	                gsub(/,/, ";", uid); \
	                print key_id","fpr","algo","caps","created","uid","category","status \
	            } \
	        }' >> summary_of_keys.csv; \
	done
	@echo "Generated summary_of_keys.csv with $$(( $$(wc -l < summary_of_keys.csv) - 1 )) keys"


.PHONY: verify
verify:	##H @Reports Verify that key files match their content
	@echo "Verifying key files..."
	@failed=0; \
	for key in $$(find keys/ -name '*.asc' | sort); do \
		fpr=$$(gpg --show-keys --with-colons "$$key" 2>/dev/null | awk -F: '/^fpr/ {print $$10; exit}'); \
		long_id=$${fpr: -16}; \
		filename=$$(basename "$$key" .asc); \
		if [ "$$filename" = "$$fpr" ]; then \
			echo "[OK] $$key (matches Fingerprint)"; \
		elif [ "$$filename" = "$$long_id" ]; then \
			echo "[OK] $$key (matches Long ID)"; \
		else \
			echo "[FAIL] $$key: Filename '$$filename' does not match Key ID '$$long_id' or Fingerprint '$$fpr'"; \
			failed=1; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then echo "Verification failed: Some keys have mismatched filenames."; exit 1; fi
	@echo "Verification passed: All keys match their filenames (either Fingerprint or Long ID)."


