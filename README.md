# aix-audit-agent

A safe, evidence-based, **read-only by default** audit toolkit for IBM AIX platform engineers. The agent gathers observations and reports uncertainty; it never automatically remediates an AIX system.

## Contents

- [AGENT.md](AGENT.md): audit role, evidence standards, confidence classifications, and safety boundary.
- [scripts/aix_readonly_audit.ksh](scripts/aix_readonly_audit.ksh): local AIX collector with the original 19 V1 commands and a separately accounted V1.1 collection phase.
- [profiles/README.md](profiles/README.md): guidance for future host profiles.
- [evidence/](evidence/): reserved for evidence managed by the operator.
- [reports/](reports/): reserved for reports managed by the operator.

## Use

Run the collector manually on the local AIX LPAR, from an engineer-controlled trusted directory that is not writable by untrusted users. Do not run it from `/tmp` or any shared writable directory. The script rejects all arguments and does not accept a hostname, server, output location, command, or configuration file. Its only permitted host-side write is exactly one new evidence file in the current directory named `aix_audit_YYYYMMDD_HHMMSS_PID.txt`. `umask 077` normally gives the new file owner-only permissions; `set -C` provides noclobber protection. V1 does not claim universally race-free file creation. It does not modify existing files, append, create temporary files, delete or rename files, change existing permissions or ownership, or modify AIX configuration or operational state.

V1 invokes these original 19 reviewed command forms:

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

The original 19 V1 command forms, order, and collection behavior are preserved. V1.1 adds separate numbered evidence sections after V1 for active VGs, LVM details, MPIO paths, FC adapter attributes, mounted filesystems, and inode usage. Its fixed forms are `lsvg -o`, `lsmpio`, `mount` (no flags or operands), and `df -i`. Dynamic forms are `lsvg "$validated_vg"`, `lsvg -p "$validated_vg"`, `lsvg -l "$validated_vg"`, `lspv "$validated_pv"`, `lsattr -El "$validated_fcs"`, and `lsmpio -l "$validated_disk"`. It also records fresh `lspv`, `lsdev -Cc disk`, and `lsdev -Cc adapter` discovery snapshots to drive bounded per-object queries; these snapshots supplement rather than replace the V1 inventory evidence.

V1.1 validates complete discovery-row structure, not only the first token. It rejects malformed rows and lines containing control characters other than normal spaces or tabs. Rejected applicable rows are represented safely and recorded as skipped evidence, which makes V1.1 `INCOMPLETE / UNASSESSED`. VG names must be 1–15 ASCII letters, digits, or underscores, starting with a letter; PV and disk names must be `hdisk` or `ultracs_hdisk` followed by digits; FC adapter names must be `fcs` followed by digits. Disk inventory rows require a valid name, an expected state, a nonempty location, and a nonempty description; descriptions may contain spaces and parentheses. The maximums are 64 VGs, 256 PVs, 256 disks, and 64 FC adapters. Candidates beyond a cap have skipped sections; non-FC adapter names are outside the FC query scope. PV inventory evidence is retained. Detailed PV information may require its VG to be active: V1.1 uses only a successfully collected and validated `lsvg -o` inventory to establish active membership. A PV in an inactive VG is retained in inventory evidence, but its detailed query is `NOT APPLICABLE`; V1.1 does not vary on the VG. A PV with VG `None` is also `NOT APPLICABLE`. These are collection classifications, not health conclusions. If active-VG discovery fails or is invalid, V1.1 does not infer that a VG is inactive and skips the dependent detail query, making V1.1 `INCOMPLETE / UNASSESSED`. V1.1 does not use `errpt -a`, `fcstat`, MPIO query/reset/probe options, or filesystem mount options. V1.1 is not production-approved; see the V1.1 validation status below.

Each section records its number, name, command or skipped operation, collection timestamp, output and stderr, return code when executed, and status. A command is checked with `command -v` against the fixed PATH before execution. Unavailable commands are not substituted and have no invented return code. Nonzero command results are classified as `FAILED`; `PERMISSION DENIED` is not inferred without separately captured diagnostic evidence. Failed or unavailable sections do not stop later independent collection. V1 and V1.1 have separate counters and statuses; overall collection status is `COMPLETE` only when both are complete. Any V1.1 skip, failure, unavailable command, cap, or accounting mismatch makes V1.1 `INCOMPLETE / UNASSESSED`. These are collection statuses only, not system-health conclusions. Missing evidence must be reported as **Insufficient Evidence**.

The evidence file can contain sensitive internal system configuration data, including hostname, IP addresses, routes, PVIDs, storage and adapter topology, SRC service details, and `errpt` information. Handle it as internal system configuration data and store or share it only through approved controls. The collector targets supported IBM AIX 7.x systems. Runtime validation remains limited to non-production LPARs; additional validation is recommended before production use.

## V1 Validation Status

V1 has been successfully runtime-tested on one non-production IBM AIX 7.3 LPAR. This validates the collector on `kbdvultdev01` running AIX `7300-04-02-2633` on 06-Nov-2026.

- `/usr/bin/ksh -n` and collector execution both returned 0.
- Exactly one evidence file was created with permissions `-rw-------`.
- All 19 sections were classified and successful; there were no failed or unavailable sections. Overall collection status: `COMPLETE`.
- Copilot Agent successfully analysed the resulting evidence. No remediation was performed.

This does **not** constitute production approval. Further non-production validation is recommended before production deployment. Evidence files remain excluded from Git and must not be committed.

## V1.1 Validation Status

V1.1 has successfully completed runtime validation on one non-production AIX 7.3 LPAR. This validates V1.1 on `kbdvultdev01` running AIX `7300-04-02-2633` on 06-Nov-2026.

- Native AIX `/usr/bin/ksh -n` validation passed; the collector completed with return code 0.
- V1 remained `COMPLETE`; V1.1 completed successfully; overall collection status was `COMPLETE`.
- V1.1 classified 27 sections: 25 successful, 0 failed, 0 unavailable, 0 skipped, and 2 `NOT APPLICABLE`. The counter invariant was `27 = 25 + 0 + 0 + 0 + 2`.
- The two `NOT APPLICABLE` results were detailed PV queries that did not apply; they are not health conclusions. No remediation or AIX configuration changes were performed.

This does **not** constitute general production approval. Additional validation is recommended before use across production AIX estates.

## Safety

No automatic remediation is permitted. If remediation appears necessary, report **HUMAN APPROVAL REQUIRED** and keep remediation outside this audit workflow. See [AGENT.md](AGENT.md) and [.github/copilot-instructions.md](.github/copilot-instructions.md).
