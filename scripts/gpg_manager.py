#!/usr/bin/env python3
"""
GPG Manager
-----------
A unified script to manage GPG keys (import, sign, delete) found in directories.
Replaces legacy shell scripts: _import.sh, _sign.sh, _delete.sh.
"""

import argparse
import logging
import os
import shutil
import subprocess
import tempfile
import urllib.request
from typing import List, Optional


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


def get_key_data(key_file: str) -> dict:
    """
    Parse a GPG key file into a structured dictionary.
    Returns: { "uid_text": set(signature_key_ids), ... }
    Includes the primary key signature set under key "PRIMARY".
    Uses a temporary keyring to ensure all signatures are listed.
    """
    with tempfile.TemporaryDirectory() as temp_home:
        try:
            # Import key into temp keyring
            subprocess.run(
                ["gpg", "--batch", "--homedir", temp_home, "--import", key_file],
                capture_output=True,
                check=True,  # Import might warn but exit 0 usually
            )

            # Run gpg --list-sigs --with-colons
            result = subprocess.run(
                [
                    "gpg",
                    "--batch",
                    "--homedir",
                    temp_home,
                    "--with-colons",
                    "--list-sigs",
                ],
                capture_output=True,
                text=True,
                check=True,
            )

            data = {}
            current_uid = "PRIMARY"
            data[current_uid] = set()

            for line in result.stdout.splitlines():
                parts = line.split(":")
                if not parts:
                    continue

                record_type = parts[0]

                if record_type == "uid":
                    # parts[9] is the user ID text
                    current_uid = parts[9]
                    if current_uid not in data:
                        data[current_uid] = set()
                elif record_type == "sig":
                    # parts[4] is signature key ID
                    signer_id = parts[4]
                    if current_uid in data:
                        data[current_uid].add(signer_id)
                    else:
                        # Should not happen if structure is valid
                        data[current_uid] = {signer_id}

            return data

        except subprocess.CalledProcessError as e:
            # If import fails or listing fails
            logger.error(
                f"Error parsing key structure for {key_file} (subprocess): {e}"
            )
            if e.stderr:
                logger.error(f"Stderr: {e.stderr.decode('utf-8')}")
            return {}
        except Exception as e:
            logger.error(f"Error parsing key structure for {key_file}: {e}")
            return {}


def cmd_verify_parity(secret_dir: str):
    """Verify parity between local, GitHub, and Secret Store keys."""
    github_keys = {
        # "sjjctl": "https://github.com/sjjctl.gpg",  # retired (May 2024)
        "gamesguru": "https://github.com/gamesguru.gpg",
    }

    all_passed = True

    with tempfile.TemporaryDirectory() as tmpdirname:
        for name, url in github_keys.items():
            try:
                logger.info(
                    f"{Colors.HEADER}Checking parity for {name}...{Colors.ENDC}"
                )

                # 1. Download GitHub key
                gh_key_path = os.path.join(tmpdirname, f"{name}.gpg")
                if dry_run:
                    logger.info(f"[DRY-RUN] Downloading {url} for comparison...")

                # Always download to temp for comparison
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
                gh_data = get_key_data(gh_key_path)

                # 2. Find Local Public Key
                local_keys = find_keys(["keys"])
                local_match = None
                for k in local_keys:
                    if get_fingerprint(k) == fpr:
                        local_match = k
                        break

                # 3. Find Secret Store Key
                secret_match = None
                if secret_dir and os.path.exists(secret_dir):
                    secret_keys = find_keys([secret_dir])
                    for k in secret_keys:
                        if get_fingerprint(k) == fpr:
                            secret_match = k
                            break
                else:
                    logger.warning(
                        f"{Colors.WARNING}Secret directory not found: {secret_dir}{Colors.ENDC}"
                    )

                # Comparisons
                sources = {"GitHub": gh_data}

                if local_match:
                    logger.info(
                        f"{Colors.OKGREEN}[OK] Local Public key found: {local_match}{Colors.ENDC}"
                    )
                    sources["LocalPublic"] = get_key_data(local_match)
                else:
                    logger.error(
                        f"{Colors.FAIL}[FAIL] No local public key found!{Colors.ENDC}"
                    )
                    all_passed = False

                if secret_match:
                    logger.info(
                        f"{Colors.OKGREEN}[OK] Secret Store key found: {secret_match}{Colors.ENDC}"
                    )
                    sources["SecretStore"] = get_key_data(secret_match)
                else:
                    # Not necessarily a fail if missing from secret store? User said "make sure ... is also in sync"
                    # Implies it SHOULD be there.
                    logger.warning(
                        f"{Colors.WARNING}[WARN] No key found in Secret Store ({secret_dir}){Colors.ENDC}"
                    )

                # Compare GitHub vs LocalPublic
                if "LocalPublic" in sources:
                    compare_keys(
                        "GitHub", gh_data, "LocalPublic", sources["LocalPublic"]
                    )

                # Compare GitHub vs SecretStore (if exists)
                if "SecretStore" in sources:
                    compare_keys(
                        "GitHub", gh_data, "SecretStore", sources["SecretStore"]
                    )

                    # Also Compare LocalPublic vs SecretStore
                    if "LocalPublic" in sources:
                        compare_keys(
                            "LocalPublic",
                            sources["LocalPublic"],
                            "SecretStore",
                            sources["SecretStore"],
                        )

            except Exception as e:
                logger.error(f"{Colors.FAIL}Error checking {name}: {e}{Colors.ENDC}")
                all_passed = False

    if not all_passed:
        sys.exit(1)


def compare_keys(name_a, data_a, name_b, data_b):
    """Compare two parsed key data structures and verify subset/superset status."""
    logger.info(f"--- Comparing {name_a} vs {name_b} ---")

    # Merge all signatures
    sigs_a_all = set()
    for s in data_a.values():
        sigs_a_all.update(s)

    sigs_b_all = set()
    for s in data_b.values():
        sigs_b_all.update(s)

    if sigs_a_all == sigs_b_all:
        logger.info(f"{Colors.OKGREEN}[OK] Signatures match perfectly.{Colors.ENDC}")
        return True

    logger.warning(f"{Colors.WARNING}[WARN] Mismatch detected!{Colors.ENDC}")

    # Check UIDs
    missing_uids_in_b = set(data_a.keys()) - set(data_b.keys())
    missing_uids_in_a = set(data_b.keys()) - set(data_a.keys())

    if missing_uids_in_b:
        logger.warning(f"UIDs in {name_a} but missing in {name_b}:")
        for u in missing_uids_in_b:
            logger.warning(f"  - {u}")

    if missing_uids_in_a:
        logger.warning(f"UIDs in {name_b} but missing in {name_a}:")
        for u in missing_uids_in_a:
            logger.warning(f"  - {u}")

    # Check Signatures per UID
    for uid in data_a:
        if uid in data_b:
            sigs_a = data_a[uid]
            sigs_b = data_b[uid]

            missing_in_b = sigs_a - sigs_b
            if missing_in_b:
                logger.warning(f"UID '{uid}' missing signatures in {name_b}:")
                for s in missing_in_b:
                    logger.warning(f"  - {s}")

    for uid in data_b:
        if uid in data_a:
            sigs_b = data_b[uid]
            sigs_a = data_a[uid]
            missing_in_a = sigs_b - sigs_a
            if missing_in_a:
                logger.warning(f"UID '{uid}' missing signatures in {name_a}:")
                for s in missing_in_a:
                    logger.warning(f"  - {s}")

    return False


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

    verify_parser = subparsers.add_parser(
        "verify-parity",
        parents=[parent_parser],
        help="Verify parity with GitHub and Secret Store",
    )
    verify_parser.add_argument(
        "--secret-dir",
        help="Path to secret keys directory",
        default=os.path.expanduser("~/Documents/sec"),
    )

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    if args.command == "verify-parity":
        cmd_verify_parity(args.secret_dir)
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
