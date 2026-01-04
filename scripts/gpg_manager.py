#!/usr/bin/env python3
"""
GPG Manager
-----------
A unified script to manage GPG keys (import, sign, delete) found in directories.
Replaces legacy shell scripts: _import.sh, _sign.sh, _delete.sh.
"""

import argparse
import os
import subprocess
import sys
import logging
from typing import List, Optional


# Configure logging
class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)


def find_keys(directories: List[str]) -> List[str]:
    """Find all .asc files recursively in the given directories."""
    keys = []
    for d in directories:
        if not os.path.isdir(d):
            logger.warning(f"{Colors.WARNING}Directory not found: {d}{Colors.ENDC}")
            continue
        for root, _, files in os.walk(d):
            for file in files:
                if file.endswith(".asc"):
                    keys.append(os.path.join(root, file))
    return sorted(keys)


def get_fingerprint(key_file: str) -> Optional[str]:
    """Extract the fingerprint from a GPG key file."""
    try:
        # Run gpg --show-keys --with-colons
        result = subprocess.run(
            ["gpg", "--show-keys", "--with-colons", key_file],
            capture_output=True,
            text=True,
            check=True,
        )
        # Parse output for 'fpr' record
        for line in result.stdout.splitlines():
            parts = line.split(":")
            if parts[0] == "fpr":
                return parts[9]
    except subprocess.CalledProcessError as e:
        logger.warning(f"Failed to read key {key_file}: {e}")
    except Exception as e:
        logger.error(f"Error parsing fingerprint for {key_file}: {e}")
    return None


def run_gpg_command(args: List[str], dry_run: bool = False):
    """Run a GPG command, respecting dry-run mode."""
    cmd_str = " ".join(args)
    if dry_run:
        logger.info(f"{Colors.OKCYAN}[DRY-RUN] Would execute: {cmd_str}{Colors.ENDC}")
    else:
        logger.info(f"{Colors.OKBLUE}Executing: {cmd_str}{Colors.ENDC}")
        try:
            subprocess.run(args, check=True)
        except subprocess.CalledProcessError as e:
            logger.error(
                f"{Colors.FAIL}Command failed: {cmd_str}\nError: {e}{Colors.ENDC}"
            )


def cmd_import(keys: List[str], dry_run: bool):
    """Import keys."""
    if not keys:
        logger.info("No keys found to import.")
        return

    # GPG can handle multiple files at once, but let's do batches or one big command if length allows.
    # For safety/simplicity, we can do them one by one or all together.
    # The legacy script did `gpg --import ... $keys`.

    cmd = ["gpg", "--import", "--armor", "--yes"] + keys
    run_gpg_command(cmd, dry_run)


def cmd_sign(keys: List[str], dry_run: bool):
    """Sign keys."""
    if not keys:
        logger.info("No keys found to sign.")
        return

    for key_file in keys:
        fpr = get_fingerprint(key_file)
        if fpr:
            logger.info(
                f"{Colors.OKGREEN}Signing key {key_file} (Fingerprint: {fpr}){Colors.ENDC}"
            )
            # gpg --quick-lsign-key --yes "$fpr"
            cmd = ["gpg", "--quick-lsign-key", "--yes", fpr]
            run_gpg_command(cmd, dry_run)
        else:
            logger.warning(
                f"{Colors.WARNING}Skipping {key_file}: could not extract fingerprint.{Colors.ENDC}"
            )


def cmd_delete(keys: List[str], dry_run: bool):
    """Delete keys."""
    if not keys:
        logger.info("No keys found to delete.")
        return

    for key_file in keys:
        fpr = get_fingerprint(key_file)
        if fpr:
            logger.info(
                f"{Colors.WARNING}Deleting key {key_file} (Fingerprint: {fpr}){Colors.ENDC}"
            )
            # gpg --batch --delete-keys --yes "$fpr"
            cmd = ["gpg", "--batch", "--delete-keys", "--yes", fpr]
            run_gpg_command(cmd, dry_run)
        else:
            logger.warning(
                f"{Colors.WARNING}Skipping {key_file}: could not extract fingerprint.{Colors.ENDC}"
            )


import tempfile
import shutil
import urllib.request

# ... (logging setup) ...


def get_signatures(key_file: str) -> List[str]:
    """Extract signatures from a GPG key file."""
    try:
        # Run gpg --list-packets
        result = subprocess.run(
            ["gpg", "--list-packets", key_file],
            capture_output=True,
            text=True,
            check=True,
        )
        signatures = []
        for line in result.stdout.splitlines():
            # Basic signature extraction - looking for 'sig' packets
            # We want to capture the signature data to compare equivalence.
            # However, list-packets output is verbose.
            # A better approach for equivalence might be to check fingerprints and maybe key contents.
            # But the user asked for "signature equivalence".
            # Let's try to extract the signature packet lines or use --with-colons output for 'sig' records.
            if line.strip().startswith(":signature packet:"):
                signatures.append(line.strip())
            elif line.strip().startswith("digest"):
                signatures.append(line.strip())
        return signatures
    except Exception as e:
        logger.error(f"Error parsing signatures for {key_file}: {e}")
        return []


def cmd_verify_parity(dry_run: bool):
    """Verify parity between local and GitHub keys."""
    github_keys = {
        "sjjctl": "https://github.com/sjjctl.gpg",
        "gamesguru": "https://github.com/gamesguru.gpg",
    }

    all_passed = True

    with tempfile.TemporaryDirectory() as tmpdirname:
        for name, url in github_keys.items():
            try:
                logger.info(
                    f"{Colors.HEADER}Checking parity for {name}...{Colors.ENDC}"
                )

                # Download GitHub key
                gh_key_path = os.path.join(tmpdirname, f"{name}.gpg")
                if dry_run:
                    logger.info(f"[DRY-RUN] Would download {url} to {gh_key_path}")
                    continue

                logger.info(f"Downloading {url}...")
                with urllib.request.urlopen(url) as response, open(
                    gh_key_path, "wb"
                ) as out_file:
                    shutil.copyfileobj(response, out_file)

                # Get Fingerprint
                fpr = get_fingerprint(gh_key_path)
                if not fpr:
                    logger.error(
                        f"{Colors.FAIL}Could not extract fingerprint from GitHub key for {name}{Colors.ENDC}"
                    )
                    all_passed = False
                    continue

                logger.info(f"GitHub Fingerprint: {fpr}")

                # Find Local Key
                # We need to find a local key that matches this fingerprint.
                # Since we don't have the key list passed in (it's a separate command), we search standard locations.
                # Or we can search the current directory/subdirectories.
                # Better: Allow user to pass directories, defaulting to current.
                # But here we are hardcoding the logic as per the specific request.
                # Let's search in 'keys/' directory recursively.
                local_keys = find_keys(["keys"])
                match = None
                for k in local_keys:
                    lfpr = get_fingerprint(k)
                    if lfpr == fpr:
                        match = k
                        break

                if match:
                    logger.info(
                        f"{Colors.OKGREEN}[OK] Local key found: {match}{Colors.ENDC}"
                    )

                    # Compare Signatures/Content
                    # Simplest robust check: is the downloaded file identical to the local armored file?
                    # GitHub serves binary or armored? usually binary (.gpg) or armored (.asc) depending on url?
                    # The urls end in .gpg, but might be armored.
                    # Let's compare their "gpg --list-packets" output for structural equivalence.

                    gh_sigs = get_signatures(gh_key_path)
                    local_sigs = get_signatures(match)

                    if gh_sigs == local_sigs:
                        logger.info(
                            f"{Colors.OKGREEN}[OK] Signatures match perfectly.{Colors.ENDC}"
                        )
                    else:
                        logger.warning(
                            f"{Colors.WARNING}[WARN] Signature mismatch!{Colors.ENDC}"
                        )
                        logger.info(
                            f"GitHub sigs: {len(gh_sigs)}, Local sigs: {len(local_sigs)}"
                        )
                        # This might be expected if local has more signatures (not yet pushed) or fewer.
                        # But for "parity" we usually want equality.
                        all_passed = False

                else:
                    logger.error(
                        f"{Colors.FAIL}[FAIL] No local key found for fingerprint {fpr}{Colors.ENDC}"
                    )
                    all_passed = False

            except Exception as e:
                logger.error(f"{Colors.FAIL}Error checking {name}: {e}{Colors.ENDC}")
                all_passed = False

    if not dry_run:
        if all_passed:
            logger.info(
                f"{Colors.OKGREEN}{Colors.BOLD}Parity Check Passed!{Colors.ENDC}"
            )
            sys.exit(0)
        else:
            logger.error(f"{Colors.FAIL}{Colors.BOLD}Parity Check Failed!{Colors.ENDC}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Manage GPG keys.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Common arguments
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        "directories", nargs="*", default=["."], help="Directories to search for keys"
    )
    parent_parser.add_argument(
        "-n", "--dry-run", action="store_true", help="Simulate actions"
    )
    parent_parser.add_argument(
        "-v", "--verbose", action="store_true", help="Verbose output"
    )

    # Subcommands
    subparsers.add_parser("import", parents=[parent_parser], help="Import keys")
    subparsers.add_parser("sign", parents=[parent_parser], help="Sign keys")
    subparsers.add_parser("delete", parents=[parent_parser], help="Delete keys")
    subparsers.add_parser(
        "verify-parity", parents=[parent_parser], help="Verify parity with GitHub"
    )

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    if args.command == "verify-parity":
        cmd_verify_parity(args.dry_run)
        return

    keys = find_keys(args.directories)

    logger.info(
        f"{Colors.BOLD}Found {len(keys)} key(s) in {args.directories}{Colors.ENDC}"
    )

    if args.command == "import":
        cmd_import(keys, args.dry_run)
    elif args.command == "sign":
        cmd_sign(keys, args.dry_run)
    elif args.command == "delete":
        cmd_delete(keys, args.dry_run)


if __name__ == "__main__":
    main()
