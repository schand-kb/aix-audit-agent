# kbdvultdev03 Expected-State Profile

**Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

**Evidence reference:** `reports/kbdvultdev03_aix_audit_20261109_162720.md`, based on `evidence/aix_audit_20261109_162720_17957160.txt`, collected 2026-11-09 16:27:20.

Observed values below are context only. They are not approved expectations unless explicitly classified **CONFIRMED EXPECTED**.

## Identity

| Item | Status | Expected value / observation |
|---|---|---|
| Hostname | OBSERVED - EXPECTATION NOT YET CONFIRMED | Evidence reports `kbdvultdev03`; confirm profile-to-host identity with owner. |
| Environment | CONFIRMED EXPECTED | DEV. |
| Server role | CONFIRMED EXPECTED | Standalone AIX development LPAR. |
| Replication membership | NOT APPLICABLE | Not part of the DEV01/DEV02 Pure Storage replication partnership. |
| Pure site state | NOT APPLICABLE | Pure promotion/demotion state and replicated-target rules do not apply. |
| Expected AIX level | CONFIRMED EXPECTED | `7300-04-02-2633`. |

## PowerVM

| Item | Status | Expected value / observation |
|---|---|---|
| Expected processor mode | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed shared-SMT-8, uncapped; confirm intended mode. |
| Expected virtual processors | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 1 online, maximum 2; confirm expected count/range. |
| Expected entitled capacity or acceptable range | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 0.20; confirm expected entitlement/range. |
| Expected memory | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 8,192 MB online, dedicated memory mode; confirm expected amount/mode. |

## Filesystems

| Item | Status | Expected value / observation |
|---|---|---|
| Expected mounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | No complete mount baseline supplied. `df -g` reports `/`, `/usr`, `/var`, `/tmp`, `/home`, `/admin`, `/audit`, `/opt`, `/var/adm/ras/livedump`, `/u1`, `/u2`, and `/uda`; these are observations only. |
| `/data1` mount expectation | CONFIRMED EXPECTED | Expected mounted = YES. |
| Expected intentionally unmounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | No intentionally unmounted filesystem set supplied. DEV01/DEV02 Pure replication rules do not apply. |
| Filesystem warning threshold | CONFIRMED EXPECTED | 85% used (repository default). |
| Filesystem high threshold | CONFIRMED EXPECTED | 90% used (repository default). |
| Filesystem critical threshold | CONFIRMED EXPECTED | 95% used (repository default). |
| Current utilization observations | OBSERVED - EXPECTATION NOT YET CONFIRMED | `/home` 70%, `/usr` 66%, `/` 57%, `/var` 44%, `/tmp` 31%, `/opt` 49%, `/u1`, `/u2`, and `/uda` each 1%. No trend is supplied. |

## LVM

| Item | Status | Expected value / observation |
|---|---|---|
| Expected active VGs | OBSERVED - EXPECTATION NOT YET CONFIRMED | `rootvg` observed active; owner has not confirmed the complete expected active VG set. |
| Expected inactive VGs | CONFIRMED EXPECTED | `old_rootvg` is intentionally retained and inactive. |
| Expected intentionally unassigned disks | UNKNOWN / REQUIRES OWNER CONFIRMATION | No unassigned disk is reported in the supplied inventory; expected unassigned set is still not established. |
| Expected stale PP count | CONFIRMED EXPECTED | 0. |
| Other PV inventory | OBSERVED - EXPECTATION NOT YET CONFIRMED | `rootvg` uses `hdisk5`; `hdisk0` is assigned to inactive `old_rootvg`. Confirm inventory and intended roles. |

## Storage and MPIO

| Item | Status | Expected value / observation |
|---|---|---|
| Expected disks | OBSERVED - EXPECTATION NOT YET CONFIRMED | Two available disks observed: `hdisk0` and `hdisk5`. Confirm expected inventory and purpose. |
| Expected storage type | OBSERVED - EXPECTATION NOT YET CONFIRMED | Disks identified as PURE MPIO Drive (Fibre); confirm expected storage platform/type. |
| Expected MPIO path count or acceptable range | CONFIRMED EXPECTED | 16 paths per applicable disk; applicability is determined by the approved disk/topology configuration. |
| Expected path states | OBSERVED - EXPECTATION NOT YET CONFIRMED | Active rootvg disk `hdisk5` shows selected/optimized paths; inactive-VG disk `hdisk0` shows closed states. Confirm against usage and topology. |

## Fibre Channel

| Item | Status | Expected value / observation |
|---|---|---|
| Expected `fcs` adapters | CONFIRMED EXPECTED | `fcs0`, `fcs1`, `fcs2`, and `fcs3`; observed available at locations 10–13. |
| Relevant adapter attributes | OBSERVED - EXPECTATION NOT YET CONFIRMED | Captured values match across adapters: `num_cmd_elems=2048`, `num_io_queues=8`, `num_nvme_queues=4`, `sw_fc_class=2`; confirm which attributes have approved expected values. |

## Network

| Item | Status | Expected value / observation |
|---|---|---|
| Expected interface | OBSERVED - EXPECTATION NOT YET CONFIRMED | `en0` observed; confirm intended interface. |
| Expected subnet | OBSERVED - EXPECTATION NOT YET CONFIRMED | `10.24.65.125/24` observed; confirm expected address/subnet. |
| Expected default gateway | OBSERVED - EXPECTATION NOT YET CONFIRMED | `10.24.65.1` observed; confirm expected gateway. |

## Paging

| Item | Status | Expected value / observation |
|---|---|---|
| Expected paging space | OBSERVED - EXPECTATION NOT YET CONFIRMED | `hd6`, 10,176 MB, 0% used observed; confirm intended size/device. |
| Acceptable usage threshold | UNKNOWN / REQUIRES OWNER CONFIRMATION | No paging usage threshold supplied. |
| Expected active paging behavior | OBSERVED - EXPECTATION NOT YET CONFIRMED | `vmstat 2 6` shows `pi`/`po` zero in six rows; a short sample is not a paging baseline. |

## SRC Services

| Item | Status | Expected value / observation |
|---|---|---|
| Expected active services | CONFIRMED EXPECTED | `sshd`, `splunkd`. Both are reported active in the capture. |
| Expected intentionally inactive services | UNKNOWN / REQUIRES OWNER CONFIRMATION | `nfsd` and `rpc.mountd` are examples reported inoperative; no approved inactive-service list supplied. |

## Error Log Expectations

| Policy item | Status | Expected handling |
|---|---|---|
| Permanent hardware errors | CONFIRMED EXPECTED | Require review. |
| Repeated path failures | CONFIRMED EXPECTED | Require review and correlate recurrence/current path status. |
| FC adapter errors | CONFIRMED EXPECTED | Require review with adapter/path/topology context. |
| Historical recovered events | CONFIRMED EXPECTED | Distinguish historical recovered events from current faults. |

## Profile Confidence

- **Confirmed expected items:** Environment DEV; standalone AIX development role; no DEV01/DEV02 replication membership and Pure site state not applicable; AIX `7300-04-02-2633`; `/data1` mounted; `old_rootvg` retained inactive; 16 MPIO paths per applicable disk; expected FC adapters `fcs0`–`fcs3`; zero stale PPs; required active SRC services `sshd` and `splunkd`; repository filesystem thresholds and error-log review policy.
- **Observed but unconfirmed items:** Host identity, PowerVM values, other filesystem utilization/mount inventory, active VG set and PV/disk inventory, storage type/path states, FC attributes, and network values.
- **Unknown items:** Server-specific PowerVM baselines; complete filesystem mount/unmount set; full active VG set; expected disk inventory/roles; path states; server-specific network expectations; paging threshold; other SRC expectations; any other item labeled UNKNOWN / REQUIRES OWNER CONFIRMATION.
- **NOT APPLICABLE items:** Pure replication membership and Pure site state; all DEV01/DEV02 promotion/demotion and replicated-target disk/VG/filesystem logic.
- **Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

## Assessment Order and Safety

Apply the sequence: collected evidence → collection validity → this server profile → deviations from confirmed expectations → engineering findings. An UNKNOWN profile item must not generate a configuration-compliance finding. This profile does not override evidence or establish health. Investigation remains read-only; remediation is outside the audit workflow.
