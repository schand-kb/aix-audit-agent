# AIX guest pilot command review

Historical pre-pilot review. The later pilot results and owner dispositions are
recorded in [the read-only command catalogue](aix-readonly-command-catalogue.md);
the statements below describe the earlier review point, not current approval.

Static review only; the changed collector and streamed `/usr/bin/ksh -s`
transport have not run on the target AIX level. "Appropriate" below means a
candidate for a separately approved SIT pilot, not production approval. Each
form can fail because the command is unavailable or the executing account lacks
permission. Each is an independent section, so nonzero/unavailable status is
recorded and later sections continue. No privilege escalation is attempted.
All output is internal evidence and requires a sensitive-data review.

| Exact form | Purpose and expected observation | Privilege / availability | Sensitivity and expected size/runtime | Pilot |
|---|---|---|---|---|
| `uname -L` | Query partition identity. | Option support must be checked on the target AIX level. | Partition identifiers; normally small and quick. | Appropriate, pending native validation. |
| `bootinfo -b` | Query boot device. | Account access or command availability may prevent collection. | Device identity; normally small and quick. | Appropriate, pending native validation. |
| `who -b` | Query recorded last boot. | Command or accounting information may be unavailable. | Boot time; normally small and quick. | Appropriate, pending native validation. |
| `cat /etc/resolv.conf` | Read resolver configuration; does not change it. | File may be absent or unreadable; `cat` may be unavailable. | **Internal configuration evidence**, potentially including DNS names/addresses; normally small. | Appropriate after sensitive-data handling review. |
| `lssrc -s xntpd` | Query SRC status for xntpd. | SRC permissions or service registration can differ; unavailable is not proof no time service exists. | Service status; normally small and quick. | Appropriate, with other time services a gap. |
| `ntpq -pn` | Query local NTP peer status without name resolution. | Command/service may be missing, denied or unresponsive. | Peer addresses and timing data; normally modest. No timeout is enforced. | Owner approved for db2test; zero-exit output without a recognizable peer row is failed. |
| `sysdumpdev -l` | List dump configuration, not trigger a dump. | May be unavailable or permission restricted. | Dump-device names and configuration; normally small. | Appropriate, pending native validation. |
| `lslpp -L` | List installed filesets and levels; no installation. | May be unavailable or restricted. | Software inventory can be large and sensitive; output is bounded only by command completion, not a byte/time cap. | Appropriate if the owner accepts volume and runtime. |
| `emgr -l` | List interim fixes, not install or remove them. | May be unavailable or privilege restricted. No sudo is attempted. | Fix/software details; size depends on installed fixes. | Appropriate; failure remains unknown. |
| `lscfg -vl <device>` | Query verbose device configuration for validated disk or FC names; no device change or active probe is intended. | Command, options, device access and VPD behavior require target-level review. | Hardware identity, serials and topology; bounded to 256 disks and 64 FC adapters, but no per-command timeout. | Conditional on target-level review and acceptance of enumeration overhead. |

`lsmpio` remains excluded. `lspath` and `lscfg` are not equivalent to all
`lsmpio` path details. `ntpq`, `emgr` and every other failed section make the
overall result incomplete rather than stopping unrelated sections. Missing
evidence is never treated as a healthy result.

For SSH streaming, each external collector command receives `/dev/null` as
stdin so it cannot consume the rest of the script stream. The collector does
not explicitly create a file in stdout mode; shell/OS behavior, syntax, output
completeness and all exact forms still require native AIX validation. File mode
retains its default filename/permissions behavior, but output format and the
extended command set changed in V1.2 and V1.3.
