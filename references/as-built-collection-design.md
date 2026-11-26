# As-built collection design

This is not an approved operational procedure. No remote collection is
authorized. The separately implemented workstation wrapper requires explicit
owner approval for each connection and collection. AIX V1.5 forms and stdout
streaming have been validated on db2test only, not across the estate.

## Evidence authorities

CMC supplies the owner-approved canonical inventory, system relationship and
partition category. HMC supplies current PowerVM configuration; AIX supplies
guest state; VIOS supplies virtual I/O state. Human-approved evidence supplies
purpose, ownership, DR architecture and business or recovery assertions that
host queries cannot prove. Record disagreements and unknowns rather than
substituting saved profiles or inferring facts from another partition.

## Workstation wrapper

The AIX wrapper requires an explicit canonical target, account, evidence root
and known-hosts file. It resolves the root physically and rejects prohibited
repositories, Git worktrees and roots that are not private. There is no default
evidence root. It uses `umask 077`, a private collection directory and
exclusive evidence files; it refuses collisions and retains incomplete runs.

It validates hostnames as DNS labels and validates the account separately. It
streams the local snapshot to a native KornShell syntax check, then, only on
success and unchanged snapshot/route hashes, to the fixed collector command.
These are separate connections, not an arbitrary user-supplied shell fragment
or a pre-positioned file. It uses SSH
`BatchMode=yes`, `StrictHostKeyChecking=yes`, `UpdateHostKeys=no`,
`ForwardAgent=no`, `ClearAllForwardings=yes`, a 10-second connection timeout,
and no interactive TTY. It requires pre-verified host keys and does not accept
new ones automatically, embed credentials or collect environment variables.
For this pilot only, it retains the reviewed `db2test` ProxyJump route and
requires strict, noninteractive settings on the transport and destination.

The owner reports that the eight-command `AIX_READONLY` sudo policy is
**APPLIED AND VALIDATED BY OWNER** on db2test. Broader estate deployment is
**NOT APPLIED**; other AIX LPARs are **NOT AUTHORIZED**.

It captures stdout, SSH stderr, exit status, UTC timestamps and a JSON manifest.
The wrapper defaults to `unprivileged`; an explicit `--privileged-readonly`
selects the collector's fixed eight-command `sudo -n` dispatcher and records
`controlled-readonly` in the manifest. The collector refuses controlled mode
unless its OS is AIX and observed hostname is `db2test`; dynamic inventory
queries remain outside sudo. It stops on a failed or unavailable sudo command.
The wrapper checks the evidence mode and eight dispatcher IDs against the
requested mode. There is no password prompt or automatic retry.
The collector combines individual command stderr with section output. The wrapper
checks the version, output mode, hostname section and final status; identity
mismatch, missing markers, failures or interruption are incomplete. It hashes
the exact local snapshot sent and both output files. This does not independently
prove target execution or protect against an untrusted target. Review raw
evidence before sharing. Hash any approved redacted derivative separately.

## HMC extension proposal

The existing `collect_hmc_cpu.sh` already records current processor allocation
and LPAR identity/state, and labels profiles as saved configuration. Its
outputs and SSH failure aggregation are not yet sufficient for this wrapper.
Before reuse, require explicit managed systems, strict input validation and
pinned host keys; remove all-system discovery from this workflow, distinguish
per-command errors, and make any failed section affect overall status. The
current command-prefix allow-list alone is not a safe arbitrary-input boundary.

After confirming exact syntax and field semantics with the installed HMC help,
consider adding separate, prominently labelled sections for current memory and
current virtual Ethernet, FC/NPIV and SCSI mappings. Candidate forms to validate:

```
lshwres -r mem -m <managed-system> --level lpar
lshwres -r virtualio --rsubtype eth -m <managed-system> --level lpar
lshwres -r virtualio --rsubtype fc -m <managed-system> --level lpar
lshwres -r virtualio --rsubtype scsi -m <managed-system> --level lpar
```

These are **PENDING HMC PILOT VALIDATION**, not established locally and not
implemented. Label profile sections `SAVED PROFILE - NOT CURRENT`; identify
current versus configured fields in all other sections. Profile values must
never be substituted for current state.

## VIOS collector proposal

No dedicated collector is implemented. Use an explicitly reviewed restricted
VIOS shell and stdout-only output; HMC owns CPU and memory configuration.
No sudo, su, oem_setup_env, target evidence files, mail, SCP, device changes,
mapping changes or backup commands. Each fixed command must be confirmed as
query-only for the exact installed VIOS level, syntax and account permissions.
Commands not confirmed remain unknown, not silently skipped as successful.

| Requirement | Candidate | Local review status |
|---|---|---|
| Identity and level | `hostname`, `ioslevel` | Narrow existing report uses ioslevel; restricted-shell hostname and version need validation. |
| Devices, Ethernet, FC, aggregation, SEA | `lsdev -type adapter`, `lsdev -type disk`, `lsdev -dev <validated-device> -attr` | Candidate syntax and attributes not established for target level; validate names and bound enumeration. |
| Network mappings | `lsmap -all -net` | Pending target-level help, permissions and output review. |
| NPIV and client mappings | `lsmap -all -npiv` | Pending target-level help, permissions and output review. |
| vSCSI/backing devices and clients | `lsmap -all` | Pending target-level help, permissions and output review. |
| Disk inventory | `lspv` | Pending VIOS restricted-shell help and permissions. |
| MPIO/path details, service status, DNS/NTP | No approved form | Not covered; review supported VIOS forms and sensitivity separately. |

Neither device inventory nor an adapter name alone proves active redundancy,
client ownership, SEA failover, backup success or a DR relationship.

## Common manifest

The AIX wrapper uses UTF-8 JSON with a schema version. Unknown values are JSON
`null`; never fill from an unrelated authority. Its fields are:

```
schema_version, collection_id, target_type, requested_target, privilege_mode,
observed_hostname, collector_name, collector_version, collector_sha256,
collection_start_utc, collection_end_utc, ssh_exit_status, evidence_filename,
evidence_sha256, stderr_filename, stderr_sha256, overall_status, known_gaps
```

Section results remain in the evidence, not the manifest. `overall_status` is
NOT_STARTED, IN_PROGRESS, COMPLETE, INCOMPLETE or FAILED. A complete capture
does not mean complete coverage. Do not put credentials, SSH headers, tokens or
unrestricted command environment in the manifest. HMC/VIOS manifest extensions,
including managed system, partition ID and operator, are future design work.
