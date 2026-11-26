# AIX read-only command catalogue and db2test pilot

The V1.5 collector implements the approved forms and a fixed privileged
dispatcher locally. This is not production approval or permission for another
connection, collector run, sudoers change, or target.

## Dispositions

* **APPROVED V1**: owner-approved exact forms, implemented locally; execution
  and any further elevation require separate approval.
* **SANDBOX TEST ONLY**: `lsmpio` with no arguments is approved for a db2test
  sandbox test; not approved for collector or production use.
* **DEFERRED**: `lssec`, security-database collection, and all other forms not
  specifically approved here.
* **FORBIDDEN**: the operations listed below; in particular `lsmpio -q` and
  `lsmpio -z`.

The paths below are the paths observed on db2test. Verify paths, command
identity, ownership, permissions, implementation and AIX version separately on
each target. A display invocation can still expose sensitive infrastructure
details or have operating-system overhead. Evidence is restricted; only
reviewed, necessary fields should be published in an as-built.

## Approved V1 exact-form candidates

These are read-only display or bounded sampling forms. The risk is R1 for a
query form with no relevant modifying mode, R2 where other forms can modify
state, and R3 for sensitive output; R3 can overlap another category. `U` means
the form succeeded without sudo in the db2test pilot or a later query; `P`
means the executable was present but not executable by the account; `F1`
means the form returned 1 without sudo, with the cause unconfirmed; `?` means
not validated. Native setuid/setgid behavior is distinct from sudo. The owner
subsequently reported that the original seven fixed privileged forms ran
successfully with `sudo -n` on db2test; those seven also succeeded in the V1.4
pilot. The owner reports that the exact privileged boot-list form also
succeeded manually. All eight dispatched forms succeeded in the V1.5
db2test collector validation.

| ID | db2test absolute command and arguments | Purpose | Risk | Validation |
|---|---|---|---|---|
| AIX-ID-001 | `/usr/bin/hostname` | Host identity | R2 | U |
| AIX-ID-002 | `/usr/bin/uname -a` | OS and system identity | R2/R3 | U |
| AIX-ID-003 | `/usr/bin/uname -L` | Partition identity | R2/R3 | U |
| AIX-ID-004 | `/usr/bin/oslevel -s` | AIX level | R1 | U |
| AIX-ID-005 | `/usr/sbin/prtconf` | Hardware and guest identity | R1/R3 | U |
| AIX-ID-006 | `/usr/bin/lparstat -i` | Guest CPU and memory | R1/R3 | U |
| AIX-CPU-001 | `/usr/bin/vmstat 2 6` | Bounded utilization sample | R1/R3 | U |
| AIX-MEM-001 | `/usr/bin/svmon -G` | Global memory state | R1/R3 | U |
| AIX-CPU-002 | `/usr/sbin/lsattr -El proc0` | Processor attributes | R1/R3 | U |
| AIX-ID-007 | `/usr/sbin/lsattr -El sys0` | System attributes | R1/R3 | U |
| AIX-BOOT-001 | `/usr/sbin/bootinfo -b` | Boot device | R2/R3 | P |
| AIX-BOOT-002 | `/usr/bin/who -b` | Last boot time | R1 | U |
| AIX-BOOT-003 | `/usr/bin/bootlist -m normal -o` | Normal boot list | R2/R3 | U returned empty output; privileged V1.5 collector returned nonempty output on db2test |
| AIX-STG-001 | `/usr/sbin/lsps -a` | Paging spaces | R1/R3 | U |
| AIX-FS-001 | `/usr/bin/df -g` | Filesystem capacity and usage | R1/R3 | U |
| AIX-FS-002 | `/usr/bin/df -i` | Filesystem inode usage | R1/R3 | U |
| AIX-FS-003 | `/usr/sbin/lsfs` | Filesystem definitions | R1/R3 | U |
| AIX-FS-004 | `/usr/sbin/mount` | Mounted filesystems | R2/R3 | U; no arguments only |
| AIX-STG-002 | `/usr/sbin/lsvg` | VG inventory | R1/R3 | U |
| AIX-STG-003 | `/usr/sbin/lsvg -o` | Active VG inventory | R1/R3 | U |
| AIX-STG-004 | `/usr/sbin/lsvg <vg>` | Active VG detail | R1/R3 | U on pilot inventory |
| AIX-STG-005 | `/usr/sbin/lsvg -p <vg>` | Active VG physical volumes | R1/R3 | U on pilot inventory |
| AIX-STG-006 | `/usr/sbin/lsvg -l <vg>` | Active VG logical volumes | R1/R3 | U on pilot inventory |
| AIX-STG-007 | `/usr/sbin/lspv` | PV inventory | R1/R3 | U |
| AIX-STG-008 | `/usr/sbin/lspv <pv>` | Active-VG PV detail | R1/R3 | U on pilot inventory |
| AIX-STG-009 | `/usr/sbin/lsdev -Cc disk` | Disk inventory | R1/R3 | U |
| AIX-STG-010 | `/usr/sbin/lsdev -Cc adapter` | Adapter inventory | R1/R3 | U |
| AIX-STG-011 | `/usr/sbin/lspath` | Configured path state | R1/R3 | U |
| AIX-STG-012 | `/usr/sbin/lscfg -vl <disk>` | Disk VPD/context | R1/R3 | U on pilot inventory |
| AIX-STG-013 | `/usr/sbin/lscfg -vl <fcs>` | FC adapter VPD | R1/R3 | U on pilot inventory |
| AIX-STG-014 | `/usr/sbin/lsattr -El <fcs>` | FC adapter attributes | R1/R3 | U on pilot inventory |
| AIX-STG-015 | `/usr/sbin/lslv <lv>` | LV attributes | R1/R3 | Executable with native privilege bit; not run |
| AIX-STG-016 | `/usr/sbin/lspath -F 'path_id status parent connection'` | Selected path fields | R1/R3 | U |
| AIX-NET-001 | `/usr/bin/netstat -rn` | Routes | R2/R3 | U |
| AIX-NET-002 | `/usr/bin/netstat -in` | Interface statistics | R2/R3 | U |
| AIX-NET-003 | `/usr/bin/cat /etc/resolv.conf` | Resolver configuration | R3 | U; never privileged generic `cat` |
| AIX-NET-004 | `/usr/sbin/ntpq -pn` | NTP peer state | R1/R3 | U; not persistent configuration |
| AIX-NET-005 | `/usr/sbin/ifconfig -a` | Interface configuration | R2/R3 | U |
| AIX-SVC-001 | `/usr/bin/lssrc -a` | SRC service state | R1/R3 | U |
| AIX-SVC-002 | `/usr/bin/lssrc -s xntpd` | NTP service state | R1/R3 | U |
| AIX-OPS-001 | `/usr/bin/errpt` | Error-event summary | R1/R3 | U; events are historical |
| AIX-OPS-002 | `/usr/lib/errdemon -l` | Error-log configuration | R2/R3 | P |
| AIX-DUMP-001 | `/usr/bin/sysdumpdev -l` | Dump configuration | R2/R3 | P |
| AIX-SW-001 | `/usr/bin/lslpp -L` | Installed filesets | R1/R3 | U |
| AIX-SW-002 | `/usr/sbin/emgr -l` | Interim fixes | R2/R3 | P |
| AIX-TUNE-001 | `/usr/sbin/no -a` | Network tunables | R2/R3 | U |
| AIX-TUNE-002 | `/usr/sbin/vmo -a` | Memory tunables | R2/R3 | F1 |
| AIX-TUNE-003 | `/usr/sbin/ioo -a` | I/O tunables | R2/R3 | F1 |
| AIX-TUNE-004 | `/usr/sbin/schedo -a` | Scheduler tunables | R2/R3 | F1 |
| AIX-TUNE-005 | `/usr/sbin/nfso -a` | NFS tunables | R2/R3 | U |
| AIX-META-001 | `/usr/bin/date '+%Y%m%d_%H%M%S'` | Local timestamps | R1 | U |
| AIX-META-002 | `/usr/bin/date -u '+%Y-%m-%dT%H:%M:%SZ'` | UTC provenance | R1 | U |

Placeholders in dynamic forms above are not raw caller input. They represent
validated names discovered from successful inventory. Existing bounds are 64
VGs, 256 PVs, 256 disks, 64 FC adapters and 256 LV detail queries globally.
LVs must appear in a recognized successful active-VG inventory and pass the
name and row validators. Only active VGs and their validated members are
queried. Do not activate a VG. These forms remain without collector-requested
elevation, and are not permitted through the sudo policy below.

The tested `vmstat`, `lsvg`, `lspv`, `lspath`, `netstat`, `errpt`, `lssrc`,
`lscfg` and `mount` binaries have a setuid or setgid bit, as does `lslv`.
Consequently, a default with no sudo is not necessarily free of native
operating-system privilege. Review effective AIX RBAC and native binary
privileges separately; do not describe the current collector as strictly
privilege-free.

## Sandbox, deferred and forbidden

| ID | Disposition | Form and rationale |
|---|---|---|
| AIX-MPIO-001 | SANDBOX TEST ONLY | `/usr/bin/lsmpio` with no arguments displays MPIO operational and extended path state. The executable exists on db2test; it has not been run. Review target/PCM support before the bounded sandbox test. |
| AIX-SEC-001 | DEFERRED | `lssec` and security-database collection; do not include or elevate. |
| — | FORBIDDEN | `lsmpio -q` issues device inquiries; `lsmpio -z` resets statistics. No other `lsmpio` forms are authorized. |

Also forbid `cfgmgr`, `chdev`, `rmdev`, `mkdev`, `varyonvg`, `varyoffvg`,
`importvg`, `exportvg`, `mklv`, `rmlv`, `chlv`, `chvg`, `mount` with
arguments, `umount`, changing `ifconfig` or `route` forms, tunable changes or
resets, `bootlist` forms without `-o` or with boot-order changes, `sysdumpdev`
changes, `emgr` installation/removal, `installp`, `inutoc`,
RPM installation/removal, `shutdown`, `reboot`, `halt`, `startsrc`, `stopsrc`,
`refresh`, `errdemon` without `-l`, error-log clearing, cron modification,
`passwd`, `chuser`, `chsec`, arbitrary security-database reads, `rm`, `mv`,
copying onto system configuration, shells or arbitrary scripts through sudo,
and generic privileged `cat`.

## db2test sandbox sudoers policy

**APPLIED AND VALIDATED BY OWNER on db2test only.** The owner reports that
the eight-command `AIX_READONLY` policy is installed and that the exact
privileged boot-list query returned the normal boot list. The original seven
forms also succeeded in the V1.4 pilot. Broader estate deployment is **NOT
APPLIED**; other AIX LPARs are **NOT AUTHORIZED**. The rule is **SANDBOX TEST
SCOPE ONLY**. This repository does not change sudoers.

```sudoers
Cmnd_Alias AIX_READONLY = /usr/sbin/bootinfo -b, \
    /usr/bin/bootlist -m normal -o, \
    /usr/bin/sysdumpdev -l, \
    /usr/sbin/emgr -l, \
    /usr/sbin/vmo -a, \
    /usr/sbin/ioo -a, \
    /usr/sbin/schedo -a, \
    /usr/lib/errdemon -l

Defaults!AIX_READONLY env_reset
# SANDBOX TEST SCOPE ONLY
schand13 db2test = (root) NOPASSWD: NOSETENV: AIX_READONLY
```

The host name must match the installed sudoers host-matching configuration;
do not replace it with a broad host selector. Validate syntax and support for
command-specific Defaults, `NOSETENV`, exact argument matching and the
noninteractive listing interface against the installed sudo version and
plugin. These single-argument specifications do not contain sudoers
wildcards. The grant does not override other effective permissions: the
administrator must inspect all applicable user, group, host and directory or
LDAP rules and ordering. The owner reports broader SYSADMINS rights requiring
authentication. A cached sudo credential could affect `sudo -n` authorization;
the fixed dispatcher, not a claim about all effective sudo rights, is the
collector's command boundary.

`env_reset` and `NOSETENV` are not sufficient alone: review effective
`env_keep`, `env_check`, command-specific and later Defaults, and AIX
`/etc/environment` and loader variables such as `LIBPATH`; exclude unsafe
values. Verify trusted ownership and non-writability of the executables,
symlinks, parent directories and invoked dependencies, and a trusted PATH for
any subprocesses. Command-specific Defaults can affect other users of those
commands; assess this before deployment. Review audit logging and any output
logging for sensitive data.

## Dispatcher and testing boundary

The owner instructed: **stop sudo-policy negative testing against actual AIX
commands**; never execute modifying variants. Local tests use mocked commands
and do not test db2test sudo policy.

The wrapper selects `--privileged-readonly` explicitly before collection and
records the mode in its manifest. Default mode never invokes sudo. Controlled
mode requires OS `AIX` and the observed hostname `db2test` and maps only the eight stable
IDs to fixed absolute paths and argument vectors. It selects the first
executable of `/usr/bin/sudo` and `/opt/freeware/bin/sudo`, then uses `sudo -n`
without retry, raw command input, environment-supplied commands, `eval` or a
privileged shell. A failed or unavailable sudo command stops collection. The
wrapper requires a successful native KornShell syntax preflight before
collection. The installed sudo path, ownership and effective environment
remain to be verified before an approved pilot.

Inventory-derived dynamic queries remain outside sudo. Each dispatched
section records its ID, command, mode and result. Restricted evidence also
identifies the host and timestamps; hashes do not prove target integrity.
No new collector run is authorized by implementation or local tests.
