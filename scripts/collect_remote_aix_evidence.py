#!/usr/bin/env python3
"""Collect approved AIX stdout evidence on the workstation; never stage remotely."""

import argparse
from collections import deque
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

SSH = "/usr/bin/ssh"
GIT = "/usr/bin/git"
COLLECTOR = Path(__file__).resolve().with_name("aix_readonly_audit.ksh")
USER_SSH_CONFIG = Path("/home/schand14/.ssh/config")
PILOT_TRANSPORT_CONFIG = """Host kbpdunixmgt
    HostName kbpdunixmgt
    BatchMode yes
    ConnectTimeout 10
    StrictHostKeyChecking yes
    UpdateHostKeys no
    ForwardAgent no
    ForwardX11 no
    ClearAllForwardings yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    NumberOfPasswordPrompts 0
    PermitLocalCommand no
    ControlMaster no
    ControlPath none
    GlobalKnownHostsFile /dev/null
    UserKnownHostsFile /home/schand14/.ssh/known_hosts

Host *
    Include /home/schand14/.ssh/config
"""
PROHIBITED = tuple(Path(p).resolve() for p in (
    "/home/schand14/aix-audit-agent",
    "/home/schand14/power-capacity-analysis",
    "/home/schand14/sasi-chand",
))
HOST_LABEL = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\Z")
USER = re.compile(r"[A-Za-z_][A-Za-z0-9_.-]{0,31}\Z")
SAFE_PATH = re.compile(r"/[A-Za-z0-9_./-]+\Z")
VERSION = "1.5"
CATALOGUE_COMMANDS = {
    "AIX-BOOT-001": "/usr/sbin/bootinfo -b",
    "AIX-BOOT-003": "/usr/bin/bootlist -m normal -o",
    "AIX-DUMP-001": "/usr/bin/sysdumpdev -l",
    "AIX-SW-002": "/usr/sbin/emgr -l",
    "AIX-TUNE-002": "/usr/sbin/vmo -a",
    "AIX-TUNE-003": "/usr/sbin/ioo -a",
    "AIX-TUNE-004": "/usr/sbin/schedo -a",
    "AIX-OPS-002": "/usr/lib/errdemon -l",
}


def valid_hostname(name):
    return bool(name) and len(name) <= 253 and all(
        HOST_LABEL.fullmatch(label) for label in name.split(".")
    )


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def validate_root(value):
    if not value:
        raise ValueError("evidence root must not be empty")
    root = Path(value).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("evidence root is not a directory")
    if any(root == repo or repo in root.parents for repo in PROHIBITED):
        raise ValueError("evidence root is inside a prohibited repository")
    for ancestor in (root, *root.parents):
        if not os.access(ancestor, os.X_OK):
            raise ValueError("cannot inspect evidence-root ancestors")
        marker = ancestor / ".git"
        if marker.exists() or marker.is_symlink():
            raise ValueError("evidence root is inside a Git working tree")
    stat = root.stat()
    if stat.st_uid != os.geteuid() or stat.st_mode & 0o077:
        raise ValueError("evidence root must be owned by this user and mode 0700")
    env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "HOME": "/",
           "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"}
    result = subprocess.run(
        [GIT, "-C", str(root), "rev-parse", "--is-inside-work-tree",
         "--is-inside-git-dir"],
        capture_output=True, text=True, env=env, check=False,
    )
    if result.returncode == 0:
        if "true" in result.stdout.splitlines():
            raise ValueError("evidence root is inside a Git repository")
    elif "not a git repository" not in result.stderr:
        raise ValueError("unable to determine whether evidence root is in Git")
    return root


def validate_known_hosts(value):
    path = Path(value).resolve(strict=True)
    if not SAFE_PATH.fullmatch(str(path)) or not path.is_file() or not os.access(path, os.R_OK):
        raise ValueError("known-hosts file must be a readable regular file with a safe absolute path")
    return path


def validate_pilot_route(config_path, user):
    with USER_SSH_CONFIG.open("r", encoding="utf-8") as stream:
        for line in stream:
            match = re.match(r"\s*([A-Za-z]+)(?:\s|=)", line)
            if match and match.group(1).lower() in {
                "match", "include", "proxycommand", "localcommand",
                "remotecommand", "knownhostscommand",
            }:
                raise ValueError("SSH configuration contains a command or include requiring review")
    for host in ("db2test", "kbpdunixmgt"):
        command = [SSH, "-G", "-F", str(config_path)]
        if host == "db2test":
            command += [
                "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
                "-o", "UpdateHostKeys=no", "-o", "ForwardAgent=no",
                "-o", "ForwardX11=no",
                "-o", "ClearAllForwardings=yes", "-o", "PasswordAuthentication=no",
                "-o", "KbdInteractiveAuthentication=no", "-o", "NumberOfPasswordPrompts=0",
                "-o", "PermitLocalCommand=no", "-o", "ControlMaster=no",
                "-o", "ControlPath=none", "-l", user,
            ]
        result = subprocess.run(command + [host], capture_output=True, text=True, check=False)
        if result.returncode:
            raise ValueError("unable to review local SSH route")
        settings = {}
        for line in result.stdout.splitlines():
            key, _, value = line.partition(" ")
            settings.setdefault(key, []).append(value)
        expected = {
            "hostname": [host], "batchmode": ["yes"],
            "stricthostkeychecking": ["true"], "updatehostkeys": ["false"],
            "forwardagent": ["no"], "forwardx11": ["no"], "controlmaster": ["false"],
            "clearallforwardings": ["yes"], "numberofpasswordprompts": ["0"],
            "permitlocalcommand": ["no"],
            "passwordauthentication": ["no"], "kbdinteractiveauthentication": ["no"],
        }
        if any(settings.get(key) != value for key, value in expected.items()):
            raise ValueError("reviewed SSH security settings do not match pilot requirements")
        if host == "db2test":
            if settings.get("user") != [user] or settings.get("proxyjump") != ["kbpdunixmgt"]:
                raise ValueError("SSH destination route or account is not the approved pilot route")
        elif settings.get("proxyjump") not in (None, ["none"]):
            raise ValueError("nested jump route is not approved")
        if settings.get("proxycommand") not in (None, ["none"]):
            raise ValueError("SSH proxy command is not approved")


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def evidence_identity_and_status(path, expected_mode):
    first = None
    footer = deque(maxlen=13)
    hostname = None
    hostname_count = 0
    in_identity = False
    identity_ok = False
    version_ok = False
    stdout_ok = False
    start_ok = False
    sections = []
    statuses = []
    return_codes = []
    privilege_modes = []
    catalogue_sections = []
    current_section = None
    invalid_catalogue = False
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        for raw in stream:
            line = raw.rstrip("\n")
            if first is None:
                first = line
            footer.append(line)
            section = re.fullmatch(r"Section ([0-9]+): .+", line)
            if section:
                if current_section and "id" in current_section:
                    catalogue_sections.append(current_section)
                current_section = {}
                sections.append(int(section.group(1)))
            if line.startswith("Privilege mode: "):
                privilege_modes.append(line[len("Privilege mode: "):])
            if current_section is not None:
                for prefix, key in (
                    ("Display command or skipped operation: ", "command"),
                    ("Catalogue ID: ", "id"),
                    ("Execution mode: ", "mode"),
                    ("Sudo executable: ", "sudo"),
                ):
                    if line.startswith(prefix):
                        if key in current_section:
                            invalid_catalogue = True
                        current_section[key] = line[len(prefix):]
            if line.startswith("Section status: "):
                statuses.append(line[len("Section status: "):])
            if line.startswith("Command return code: "):
                return_codes.append(line[len("Command return code: "):])
            if line == "Collector version: " + VERSION:
                version_ok = True
            if line == "Evidence output mode: stdout":
                stdout_ok = True
            if re.fullmatch(r"Collection start UTC: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", line):
                start_ok = True
            if line == "Section 1: System hostname":
                in_identity = True
            elif line.startswith("Section 2: "):
                in_identity = False
            elif in_identity and line.startswith("Observed hostname: "):
                hostname_count += 1
                hostname = line[len("Observed hostname: "):]
            elif in_identity and line == "Section status: COLLECTED":
                identity_ok = True
    if current_section and "id" in current_section:
        catalogue_sections.append(current_section)
    if hostname_count != 1 or not hostname or not valid_hostname(hostname):
        hostname = None
    footer = list(footer)
    counters = []
    if len(footer) == 13:
        labels = ("total", "successful", "failed", "unavailable", "skipped",
                  "not applicable", "classified")
        for label, line in zip(labels, footer):
            match = re.fullmatch(r"V1\.5 extended " + label + r" sections: ([0-9]+)", line)
            if match is None:
                break
            counters.append(int(match.group(1)))
    footer_ok = False
    if len(counters) == 7:
        total, successful, failed, unavailable, skipped, not_applicable, classified = counters
        footer_ok = (
            total >= 26 and total == classified == successful + failed + unavailable + skipped + not_applicable
            and failed == unavailable == skipped == 0
            and footer[7] == (
                f"V1.5 extended counter invariant: {total} = {successful} + "
                f"{failed} + {unavailable} + {skipped} + {not_applicable}"
            )
            and footer[8:11] == [
                "V1 collection status: COMPLETE",
                "V1.5 extended collection status: COMPLETE",
                "UTC metadata status: COMPLETE",
            ]
            and re.fullmatch(r"Collection end UTC: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", footer[11])
            and footer[12] == "Overall collection status: COMPLETE"
            and sections == list(range(1, 20 + total))
            and len(statuses) == 19 + total
            and statuses.count("COLLECTED") == 19 + successful
            and statuses.count("NOT APPLICABLE") == not_applicable
            and len(return_codes) == 19 + successful
            and all(code == "0" for code in return_codes)
        )
    catalogue_ok = (
        not invalid_catalogue
        and len(catalogue_sections) == len(CATALOGUE_COMMANDS)
        and {section.get("id") for section in catalogue_sections} == set(CATALOGUE_COMMANDS)
        and all(
            section.get("command") == CATALOGUE_COMMANDS.get(section.get("id"))
            and section.get("mode") == expected_mode
            and (
                section.get("sudo") in ("/usr/bin/sudo", "/opt/freeware/bin/sudo")
                if expected_mode == "controlled-readonly" else "sudo" not in section
            )
            for section in catalogue_sections
        )
    )
    complete = (
        first == "AIX read-only audit evidence"
        and footer_ok
        and version_ok and stdout_ok and start_ok and identity_ok and hostname is not None
        and privilege_modes == [expected_mode] and catalogue_ok
    )
    return hostname, complete


def write_manifest(path, data):
    with path.open("w", encoding="utf-8") as stream:
        json.dump(data, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, help="canonical DNS hostname")
    parser.add_argument("--user", required=True, help="explicit SSH account")
    parser.add_argument("--evidence-root", required=True, help="existing private directory outside Git")
    parser.add_argument("--known-hosts", required=True, help="pre-verified known-hosts file")
    parser.add_argument("--privileged-readonly", action="store_true",
                        help="explicitly select the fixed noninteractive privileged catalogue")
    args = parser.parse_args(argv)
    if not valid_hostname(args.target):
        parser.error("invalid target hostname")
    if not USER.fullmatch(args.user):
        parser.error("invalid SSH account")
    if args.target.lower() != "db2test" or args.user != "schand13":
        parser.error("this pilot permits only db2test and its reviewed account")
    os.umask(0o077)
    manifest_error = False
    try:
        root = validate_root(args.evidence_root)
        known_hosts = validate_known_hosts(args.known_hosts)
        if not COLLECTOR.is_file() or not os.access(COLLECTOR, os.R_OK):
            raise ValueError("local collector source is missing or unreadable")
        if not os.path.isfile(SSH) or not os.access(SSH, os.X_OK):
            raise ValueError("SSH executable is unavailable")
        start = utc_now()
        collection_id = datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y%m%dT%H%M%SZ"
        ) + "-" + str(os.getpid())
        directory = root / (args.target.lower()[:80] + "-" + collection_id)
        directory.mkdir(mode=0o700)
    except (OSError, ValueError) as exc:
        print("Preflight failed: " + str(exc), file=sys.stderr)
        return 2

    evidence = directory / "evidence.txt"
    stderr = directory / "ssh-stderr.txt"
    snapshot = directory / "collector.ksh"
    transport_config = directory / "transport-ssh.conf"
    manifest_path = directory / "manifest.json"
    manifest = {
        "schema_version": 2,
        "collection_id": collection_id,
        "target_type": "AIX",
        "requested_target": args.target,
        "observed_hostname": None,
        "collector_name": COLLECTOR.name,
        "collector_version": VERSION,
        "privilege_mode": "controlled-readonly" if args.privileged_readonly else "unprivileged",
        "collector_sha256": None,
        "collection_start_utc": start,
        "collection_end_utc": None,
        "syntax_check_ssh_exit_status": None,
        "ssh_exit_status": None,
        "ssh_config_sha256": None,
        "transport_config_sha256": None,
        "evidence_filename": evidence.name,
        "evidence_sha256": None,
        "stderr_filename": stderr.name,
        "stderr_sha256": None,
        "overall_status": "NOT_STARTED",
        "known_gaps": [
            "Guest evidence only; PowerVM mappings, backup, monitoring integration, application and DR assertions require separate evidence.",
            "lsmpio-specific path details are not collected.",
            "NTP peer output is observed runtime state, not proof of persistent configuration.",
            "Collector command stderr is merged into evidence; SSH stderr is separate.",
        ],
    }
    try:
        write_manifest(manifest_path, manifest)
        with COLLECTOR.open("rb") as source, snapshot.open("xb") as destination:
            shutil.copyfileobj(source, destination)
        manifest["collector_sha256"] = sha256_file(snapshot)
        with transport_config.open("x", encoding="utf-8") as stream:
            stream.write(PILOT_TRANSPORT_CONFIG)
        ssh_config_sha256 = sha256_file(USER_SSH_CONFIG)
        validate_pilot_route(transport_config, args.user)
        if sha256_file(USER_SSH_CONFIG) != ssh_config_sha256:
            raise ValueError("SSH configuration changed during route review")
        manifest["ssh_config_sha256"] = ssh_config_sha256
        manifest["transport_config_sha256"] = sha256_file(transport_config)
        manifest["overall_status"] = "IN_PROGRESS"
        write_manifest(manifest_path, manifest)
        remote_command = "/usr/bin/ksh -s -- --stdout"
        if args.privileged_readonly:
            remote_command += " --privileged-readonly"
        command = [
            SSH, "-F", str(transport_config), "-T",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UpdateHostKeys=no",
            "-o", "ForwardAgent=no",
            "-o", "ForwardX11=no",
            "-o", "ClearAllForwardings=yes",
            "-o", "PermitLocalCommand=no",
            "-o", "ControlMaster=no",
            "-o", "ControlPath=none",
            "-o", "NumberOfPasswordPrompts=0",
            "-o", "PasswordAuthentication=no",
            "-o", "KbdInteractiveAuthentication=no",
            "-o", "GlobalKnownHostsFile=/dev/null",
            "-o", "UserKnownHostsFile=" + str(known_hosts),
            "-l", args.user, "--", args.target,
            remote_command,
        ]
        with snapshot.open("rb") as source, evidence.open("xb") as out, stderr.open("xb") as err:
            try:
                syntax_command = command[:-1] + ["/usr/bin/ksh -n"]
                result = subprocess.run(syntax_command, stdin=source, stdout=err, stderr=err, check=False)
                manifest["syntax_check_ssh_exit_status"] = result.returncode
                if result.returncode == 0:
                    if (sha256_file(snapshot) != manifest["collector_sha256"]
                            or sha256_file(USER_SSH_CONFIG) != manifest["ssh_config_sha256"]
                            or sha256_file(transport_config) != manifest["transport_config_sha256"]):
                        raise ValueError("collector snapshot or SSH configuration changed after preflight")
                    source.seek(0)
                    result = subprocess.run(command, stdin=source, stdout=out, stderr=err, check=False)
                    manifest["ssh_exit_status"] = result.returncode
                else:
                    manifest["known_gaps"].append("Native KornShell syntax preflight or SSH transport failed; collection was not started.")
            except OSError as exc:
                err.write(("Unable to start SSH: " + str(exc) + "\n").encode())
                manifest["known_gaps"].append("SSH could not be started; collection was not completed.")
            except KeyboardInterrupt:
                err.write(b"Collection interrupted locally.\n")
                manifest["known_gaps"].append("Collection interrupted locally.")
        manifest["observed_hostname"], collector_complete = evidence_identity_and_status(
            evidence, manifest["privilege_mode"]
        )
        manifest["evidence_sha256"] = sha256_file(evidence)
        manifest["stderr_sha256"] = sha256_file(stderr)
        snapshot_unchanged = sha256_file(snapshot) == manifest["collector_sha256"]
        identity_matches = (
            manifest["observed_hostname"] is not None
            and manifest["observed_hostname"].lower() == args.target.lower()
        )
        if manifest["ssh_exit_status"] == 0 and collector_complete and snapshot_unchanged and identity_matches:
            manifest["overall_status"] = "COMPLETE"
        else:
            manifest["overall_status"] = "INCOMPLETE"
            if not identity_matches:
                manifest["known_gaps"].append("Observed hostname missing or does not exactly match the requested target.")
            if not snapshot_unchanged:
                manifest["known_gaps"].append("Collector snapshot changed during collection.")
    except (OSError, ValueError) as exc:
        manifest["overall_status"] = "FAILED"
        manifest["known_gaps"].append("Local collection error: " + type(exc).__name__)
        print("Collection failed; evidence retained in " + str(directory) + ": " + str(exc), file=sys.stderr)
    finally:
        manifest["collection_end_utc"] = utc_now()
        try:
            write_manifest(manifest_path, manifest)
        except OSError as exc:
            print("Unable to finalize manifest in " + str(directory) + ": " + str(exc), file=sys.stderr)
            manifest_error = True
    if manifest_error:
        return 1
    print("Evidence directory: " + str(directory))
    print("Collection status: " + manifest["overall_status"])
    return 0 if manifest["overall_status"] == "COMPLETE" else 1


if __name__ == "__main__":
    sys.exit(main())
