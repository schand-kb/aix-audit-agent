# aix-audit-agent

A safe, evidence-based, **read-only by default** audit toolkit for IBM AIX platform engineers. The agent gathers observations and reports uncertainty; it never automatically remediates an AIX system.

## Contents

- [AGENT.md](AGENT.md): audit role, evidence standards, confidence classifications, and safety boundary.
- [scripts/aix_readonly_audit.ksh](scripts/aix_readonly_audit.ksh): V1 local AIX collector using the reviewed command allowlist.
- [profiles/README.md](profiles/README.md): guidance for future host profiles.
- [evidence/](evidence/): reserved for evidence managed by the operator.
- [reports/](reports/): reserved for reports managed by the operator.

## Use

Run the collector manually on the local AIX LPAR, from an engineer-controlled trusted directory that is not writable by untrusted users. Do not run it from `/tmp` or any shared writable directory. The script rejects all arguments and does not accept a hostname, server, output location, command, or configuration file. Its only permitted host-side write is exactly one new evidence file in the current directory named `aix_audit_YYYYMMDD_HHMMSS_PID.txt`. `umask 077` normally gives the new file owner-only permissions; `set -C` provides noclobber protection. V1 does not claim universally race-free file creation. It does not modify existing files, append, create temporary files, delete or rename files, change existing permissions or ownership, or modify AIX configuration or operational state.

V1 invokes only these reviewed command forms:

1. `hostname`
2. `uname -a`
3. `oslevel -s`
4. `prtconf`
5. `lparstat -i`
6. `vmstat 2 6`
7. `svmon -G`
8. `lsps -a`
9. `df -g`
10. `lsfs`
11. `lsvg`
12. `lspv`
13. `lsdev -Cc disk`
14. `lsdev -Cc adapter`
15. `lspath`
16. `netstat -rn`
17. `netstat -in`
18. `errpt`
19. `lssrc -a`

Each section records its number, name, literal display command, collection timestamp, output and stderr (captured together in the evidence file), return code when executed, and status. A command is checked with `command -v` against the fixed PATH before execution. Unavailable commands are not substituted and have no invented return code. Nonzero command results are classified as `FAILED`; `PERMISSION DENIED` is not inferred without separately captured diagnostic evidence. Failed or unavailable sections do not stop later collection. The overall status is `COMPLETE` only when all 19 commands succeed; otherwise it is `INCOMPLETE / UNASSESSED`. This is collection status only, not a system-health conclusion. Missing evidence must be reported as **Insufficient Evidence**.

The evidence file can contain sensitive internal system configuration data, including hostname, IP addresses, routes, PVIDs, storage and adapter topology, SRC service details, and `errpt` information. Handle it as internal system configuration data and store or share it only through approved controls. V1 is intended for supported IBM AIX 7.x systems; validation to date is limited to the non-production platform described below.

## V1 Validation Status

V1 was successfully runtime-tested on 06-Nov-2026 on one non-production IBM AIX 7.3 LPAR (7300-04-02-2633). The syntax check and collection completed successfully, with all 19 sections successful and no remediation changes. This does not constitute production approval; additional validation is required before production use.

## Safety

No automatic remediation is permitted. If remediation appears necessary, report **HUMAN APPROVAL REQUIRED** and keep remediation outside this audit workflow. See [AGENT.md](AGENT.md) and [.github/copilot-instructions.md](.github/copilot-instructions.md).
