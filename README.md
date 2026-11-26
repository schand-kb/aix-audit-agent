# aix-audit-agent

A safe, evidence-based, **read-only by default** audit toolkit for IBM AIX platform engineers. The agent gathers observations and reports uncertainty; it never automatically remediates an AIX system.

## Contents

- [AGENT.md](AGENT.md): audit role, evidence standards, confidence classifications, and safety boundary.
- [scripts/aix_readonly_audit.ksh](scripts/aix_readonly_audit.ksh): local AIX collector with the original 19 V1 commands and a separately accounted V1.5 extended phase.
- [scripts/collect_remote_aix_evidence.py](scripts/collect_remote_aix_evidence.py): workstation wrapper; each connection requires owner approval.
- [references/aix-pilot-review.md](references/aix-pilot-review.md): command review and pilot limitations.
- [references/aix-readonly-command-catalogue.md](references/aix-readonly-command-catalogue.md): exact command dispositions and privileged pilot boundary.
- [references/as-built-collection-design.md](references/as-built-collection-design.md): evidence authorities and HMC/VIOS designs.
- [profiles/README.md](profiles/README.md): guidance for future host profiles.
- [evidence/](evidence/): reserved for evidence managed by the operator.
- [reports/](reports/): reserved for reports managed by the operator.

## Use

V1.5 has been validated on db2test only; this does not authorize another connection or production use. After explicit approval, run the collector manually on the local AIX LPAR from an engineer-controlled trusted directory that is not writable by untrusted users; do not run it from `/tmp` or another shared writable directory. With no arguments it retains file mode, creating one new file named `aix_audit_YYYYMMDD_HHMMSS_PID.txt` in the current directory. `umask 077` normally gives owner-only permissions; `set -C` provides noclobber protection but is not claimed to be universally race-free. `--stdout` emits evidence on standard output and creates no evidence file or temporary file itself. Redirection by the caller can still create a file. `--privileged-readonly` explicitly selects controlled sudo; duplicate or other arguments are rejected. The script accepts no hostname, command, output path or configuration file.

Pre-collection errors go to standard error. Within evidence sections, command stderr is deliberately merged with stdout and labelled; it is not separately attributable in the evidence. File mode prints the evidence filename to the original stdout after collection; stdout mode does not print that control message. Each collection identifies the version, observed hostname, UTC start/end and per-section results. The stdout streaming path has been validated on db2test; this does not validate all failure modes or other AIX systems.

The workstation wrapper requires explicit target, SSH account, existing private evidence root and pre-verified known-hosts file. It currently permits only the owner-approved `db2test` pilot account and route via the configured jump host. It checks local SSH settings, then streams the retained, hashed collector snapshot to `/usr/bin/ksh -n` over a preflight SSH connection. Only after that succeeds and the snapshot and SSH configuration hashes remain unchanged does it stream the same snapshot to `/usr/bin/ksh -s -- --stdout` over a second SSH connection, adding `--privileged-readonly` only when explicitly selected. It does not stage a script or evidence file on the target. The manifest records the mode and both SSH exit statuses. **Specific owner approval is required before either connection.** It uses Python 3, OpenSSH and Git on the workstation; the evidence root must be owned by the operator, mode 0700, and outside all Git repositories. It does not change or discover host keys.

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

The original 19 V1 command forms and order are retained. The extended phase uses `lsvg -o`, `mount` (no flags or operands), and `df -i`; dynamic forms using validated names are `lsvg "$validated_vg"`, `lsvg -p "$validated_vg"`, `lsvg -l "$validated_vg"`, `lspv "$validated_pv"`, `lsattr -El "$validated_fcs"`, `lscfg -vl "$validated_device"` and `lslv "$validated_lv"`. Name validation does not establish target-level command safety. It also records fresh `lspv`, `lsdev -Cc disk`, and `lsdev -Cc adapter` discovery snapshots. Other extended queries include `uname -L`, `who -b`, `cat /etc/resolv.conf`, `lssrc -s xntpd`, `ntpq -pn`, and `lslpp -L`. NTP peer output is runtime state, not persistent configuration; zero-exit output without a recognizable peer row is failed.

V1.4 added `lsattr -El proc0`, `lsattr -El sys0`, `ifconfig -a`, `no -a`, `nfso -a`, and `lspath -F 'path_id status parent connection'` without collector-requested elevation. V1.5 adds `bootlist -m normal -o` to the fixed privileged dispatcher; it runs without sudo only in default mode. Empty boot-list output is inconclusive and makes the run incomplete. The eight fixed ID-dispatched forms are `bootinfo -b`, `bootlist -m normal -o`, `sysdumpdev -l`, `emgr -l`, `vmo -a`, `ioo -a`, `schedo -a`, and `errdemon -l`. In default mode they are queried without sudo. In explicitly selected controlled mode, they alone use `sudo -n`, with fixed absolute command paths and no fallback. The collector first requires AIX and observed hostname `db2test`. It selects the first executable fixed sudo path, `/usr/bin/sudo` or `/opt/freeware/bin/sudo`; trusted ownership must be verified before a pilot. Missing sudo or any failed sudo command stops collection. Existing native AIX setuid/setgid/RBAC can still confer authority in default mode; no sudo is not equivalent to no native privilege.

The owner reports that the eight-command `AIX_READONLY` policy is **APPLIED AND VALIDATED BY OWNER** on db2test. Broader estate deployment is **NOT APPLIED**; other AIX LPARs are **NOT AUTHORIZED**.

V1.2 removes both `lsmpio` invocations to comply with the existing policy. `lspath` and `lscfg` offer path and device evidence but are not equivalent to all `lsmpio` details; those details are unknown unless obtained via a separately approved method. Changes in V1.2 are not covered by the earlier V1/V1.1 validation.

The extended phase validates discovery-row structure, not only the first token. It rejects malformed rows and lines containing control characters other than normal spaces or tabs. Rejected applicable rows are recorded as skipped evidence, making the phase `INCOMPLETE / UNASSESSED`. VG names must be 1–15 ASCII letters, digits, or underscores, starting with a letter; PV and disk names must be `hdisk` or `ultracs_hdisk` followed by digits; FC adapter names must be `fcs` followed by digits. LV names must be 1–64 ASCII letters, digits, underscore, dot or hyphen, starting with a letter, and are taken only from a successfully collected active VG's recognized `lsvg -l` table. Disk rows require a valid name, expected state, location and description. The maximums are 64 VGs, 256 PVs, 256 disks, 64 FC adapters, and 256 LV detail queries globally. A cap, rejected row or failed LV discovery makes the run incomplete. Detailed PV information uses validated active-VG inventory; inactive or unassigned PVs are not queried. The collector does not vary on a VG. These are collection classifications, not health conclusions.

Each section records its number, name, command or skipped operation, collection timestamp, output and stderr, return code when executed, and status. The eight dispatched sections also record catalogue ID and execution mode. Unavailable commands are not substituted and have no invented return code. Nonzero results are `FAILED`; permission denial is not inferred. Unprivileged section failures do not stop later independent collection; missing or failed sudo stops controlled collection. V1 and the V1.5 extended phase have separate counters and statuses; overall status is `COMPLETE` only when both are complete and UTC timestamps were obtained. Skips, failures, unavailable commands, caps, or accounting mismatches make the extended phase incomplete. Complete collection is not proof of complete as-built coverage or system health.

The evidence file can contain sensitive internal system configuration data, including hostname, IP addresses, routes, PVIDs, storage and adapter topology, SRC service details, and `errpt` information. Handle it as internal system configuration data and store or share it only through approved controls. The collector targets supported IBM AIX 7.x systems. Runtime validation remains limited to non-production LPARs; additional validation is recommended before production use.

## V1.5 sandbox validation

The db2test controlled-readonly pilot completed on 27-Nov-2026: native KornShell syntax and all eight fixed privileged forms succeeded, including a nonempty normal boot list. The original 19 sections and 58 extended sections were collected; one extended section was not applicable. The efix query reported no fixes, a valid empty inventory. Evidence remains restricted outside Git. This is not authorization for other hosts or production use.

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
