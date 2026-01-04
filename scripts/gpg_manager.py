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
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

def find_keys(directories: List[str]) -> List[str]:
    """Find all .asc files recursively in the given directories."""
    keys = []
    for d in directories:
        if not os.path.isdir(d):
            logger.warning(f"Directory not found: {d}")
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
            check=True
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
        logger.info(f"[DRY-RUN] Would execute: {cmd_str}")
    else:
        logger.info(f"Executing: {cmd_str}")
        try:
            subprocess.run(args, check=True)
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {cmd_str}\nError: {e}")

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
            logger.info(f"Signing key {key_file} (Fingerprint: {fpr})")
            # gpg --quick-lsign-key --yes "$fpr"
            cmd = ["gpg", "--quick-lsign-key", "--yes", fpr]
            run_gpg_command(cmd, dry_run)
        else:
            logger.warning(f"Skipping {key_file}: could not extract fingerprint.")

def cmd_delete(keys: List[str], dry_run: bool):
    """Delete keys."""
    if not keys:
        logger.info("No keys found to delete.")
        return

    for key_file in keys:
        fpr = get_fingerprint(key_file)
        if fpr:
            logger.info(f"Deleting key {key_file} (Fingerprint: {fpr})")
            # gpg --batch --delete-keys --yes "$fpr"
            cmd = ["gpg", "--batch", "--delete-keys", "--yes", fpr]
            run_gpg_command(cmd, dry_run)
        else:
            logger.warning(f"Skipping {key_file}: could not extract fingerprint.")

def main():
    parser = argparse.ArgumentParser(description="Manage GPG keys.")
    
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Common arguments
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument("directories", nargs="*", default=["."], help="Directories to search for keys")
    parent_parser.add_argument("--dry-run", action="store_true", help="Simulate actions")
    parent_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    # Subcommands
    subparsers.add_parser("import", parents=[parent_parser], help="Import keys")
    subparsers.add_parser("sign", parents=[parent_parser], help="Sign keys")
    subparsers.add_parser("delete", parents=[parent_parser], help="Delete keys")

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    keys = find_keys(args.directories)
    logger.info(f"Found {len(keys)} key(s) in {args.directories}")

    if args.command == "import":
        cmd_import(keys, args.dry_run)
    elif args.command == "sign":
        cmd_sign(keys, args.dry_run)
    elif args.command == "delete":
        cmd_delete(keys, args.dry_run)

if __name__ == "__main__":
    main()
