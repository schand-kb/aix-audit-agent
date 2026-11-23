# kbdvultdev01 Expected-State Profile

**Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

**Evidence reference:** `reports/kbdvultdev01_aix_audit_20261109_162151.md`, based on `evidence/aix_audit_20261109_162151_14418224.txt`, collected 2026-11-09 16:21:51. Earlier captures are summarized in that report.

**Role profile:** [pure-automation-dev.md](pure-automation-dev.md)

Observed values below are context only. They are not approved expectations unless explicitly classified **CONFIRMED EXPECTED**. Shared DEV01/DEV02 replicated-storage expectations are conditional on the independently confirmed Pure site state and target mapping in the role profile.

## Identity

| Item | Status | Expected value / observation |
|---|---|---|
| Hostname | OBSERVED - EXPECTATION NOT YET CONFIRMED | Evidence reports `kbdvultdev01`; confirm profile-to-host identity with owner. |
| Environment | CONFIRMED EXPECTED | DEV. |
| Server role | CONFIRMED EXPECTED | Pure Storage automation development/test LPAR. |
| Replication membership | CONFIRMED EXPECTED | DEV01/DEV02 development Pure Pod / replication partnership. |
| Pure site state | UNKNOWN / REQUIRES OWNER CONFIRMATION | Supply or independently confirm `PROMOTED`, `DEMOTED`, or `UNKNOWN` for each assessment. Never infer from storage evidence. |
| Expected AIX level | CONFIRMED EXPECTED | `7300-04-02-2633`. |

## PowerVM

| Item | Status | Expected value / observation |
|---|---|---|
| Expected processor mode | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed shared-SMT-8, uncapped; confirm intended mode. |
| Expected virtual processors | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 4 online, maximum 4; confirm expected count/range. |
| Expected entitled capacity or acceptable range | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 0.50; confirm expected entitlement/range. |
| Expected memory | OBSERVED - EXPECTATION NOT YET CONFIRMED | Observed 65,536 MB online, dedicated memory mode; confirm expected amount/mode. |

## Filesystems

| Item | Status | Expected value / observation |
|---|---|---|
| Expected mounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | Mount expectations for replicated/application filesystems depend on independently confirmed Pure site state and target mapping. Observed `df -g` includes `/`, `/usr`, `/var`, `/tmp`, `/home`, `/admin`, `/opt`, `/var/adm/ras/livedump`, and `/u3`; these are observations only. |
| `/usr/spool/uv` mount expectation | CONFIRMED EXPECTED | Expected mounted when its corresponding replicated/application storage is expected active on DEV01. Not unconditional: follow the Pure site-state and target mapping. |
| Expected intentionally unmounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | `/usr/spool/uv` is configured in `lsfs` but absent from `df -g`; `fslv06` is shown closed/synced. Whether it should be mounted depends on corresponding storage activity and the confirmed Pure site state. |
| Filesystem warning threshold | CONFIRMED EXPECTED | 85% used (repository default). |
| Filesystem high threshold | CONFIRMED EXPECTED | 90% used (repository default). |
| Filesystem critical threshold | CONFIRMED EXPECTED | 95% used (repository default). |
| Current utilization observations | OBSERVED - EXPECTATION NOT YET CONFIRMED | `/` 73%, `/usr` 65%, `/var` 36%, `/tmp` 1%, `/home` 55%, `/opt` 80%, `/u3` 66%. No trend is supplied. |

## LVM

| Item | Status | Expected value / observation |
|---|---|---|
| Expected active VGs | UNKNOWN / REQUIRES OWNER CONFIRMATION | Observed active `rootvg` and `data1vg`. Confirm host-local vs replicated roles; replicated VG expectation depends on Pure site state and target mapping. |
| Expected inactive VGs | CONFIRMED EXPECTED | `old_rootvg` is intentionally retained and inactive during normal operation. |
| Expected intentionally unassigned disks | UNKNOWN / REQUIRES OWNER CONFIRMATION | `hdisk2` reports VG `None`; determine its Pure Pod role and expected assignment from the confirmed site state and target mapping. Do not permanently baseline it assigned or unassigned. |
| Expected stale PP count | CONFIRMED EXPECTED | 0. |
| Other PV inventory | OBSERVED - EXPECTATION NOT YET CONFIRMED | `rootvg` uses `hdisk0`; `data1vg` uses `ultracs_hdisk1` and `ultracs_hdisk2`; `hdisk1` is assigned to inactive `old_rootvg`. Confirm inventory and intended roles. |

## Storage and MPIO

| Item | Status | Expected value / observation |
|---|---|---|
| Expected disks | UNKNOWN / REQUIRES OWNER CONFIRMATION | Five available disks observed: `hdisk0`, `hdisk1`, `hdisk2`, `ultracs_hdisk1`, `ultracs_hdisk2`. Confirm expected inventory, purpose, and which are replicated targets. |
| Expected storage type | OBSERVED - EXPECTATION NOT YET CONFIRMED | Disks identified as PURE MPIO Drive (Fibre); confirm expected storage platform/type. |
| Expected MPIO path count or acceptable range | CONFIRMED EXPECTED | 16 paths per applicable disk; applicability is determined by the approved disk/topology mapping. |
| Expected path states | UNKNOWN / REQUIRES OWNER CONFIRMATION | Captured active root/data volumes show selected/optimized paths; other devices show closed states. For replicated targets, compare with the independently confirmed site state and target mapping. |

## Fibre Channel

| Item | Status | Expected value / observation |
|---|---|---|
| Expected `fcs` adapters | CONFIRMED EXPECTED | `fcs0`, `fcs1`, `fcs2`, and `fcs3`; observed available at locations 10–13. |
| Relevant adapter attributes | OBSERVED - EXPECTATION NOT YET CONFIRMED | Captured values match across adapters: `num_cmd_elems=2048`, `num_io_queues=8`, `num_nvme_queues=4`, `sw_fc_class=2`; confirm which attributes have approved expected values. |

## Network

| Item | Status | Expected value / observation |
|---|---|---|
| Expected interface | OBSERVED - EXPECTATION NOT YET CONFIRMED | `en1` observed; confirm intended interface. |
| Expected subnet | OBSERVED - EXPECTATION NOT YET CONFIRMED | `10.24.65.115/24` observed; confirm expected address/subnet. |
| Expected default gateway | OBSERVED - EXPECTATION NOT YET CONFIRMED | `10.24.65.1` observed; confirm expected gateway. |

## Paging

| Item | Status | Expected value / observation |
|---|---|---|
| Expected paging space | OBSERVED - EXPECTATION NOT YET CONFIRMED | `hd6`, 512 MB, 4% used observed; confirm intended size/device. |
| Acceptable usage threshold | UNKNOWN / REQUIRES OWNER CONFIRMATION | No paging usage threshold supplied. |
| Expected active paging behavior | OBSERVED - EXPECTATION NOT YET CONFIRMED | `vmstat 2 6` shows `pi`/`po` zero in six rows; a short sample is not a paging baseline. |

## SRC Services

| Item | Status | Expected value / observation |
|---|---|---|
| Expected active services | CONFIRMED EXPECTED | `sshd`, `splunkd`. Both are reported active in the capture. |
| Expected intentionally inactive services | UNKNOWN / REQUIRES OWNER CONFIRMATION | A number of services are reported inoperative; no approved inactive-service list supplied. |

## Error Log Expectations

| Policy item | Status | Expected handling |
|---|---|---|
| Permanent hardware errors | CONFIRMED EXPECTED | Require review. |
| Repeated path failures | CONFIRMED EXPECTED | Require review and correlate recurrence/current path status. |
| FC adapter errors | CONFIRMED EXPECTED | Require review with adapter/path/topology context. |
| Historical recovered events | CONFIRMED EXPECTED | Distinguish historical recovered events from current faults. |

## Profile Confidence

- **Confirmed expected items:** Environment DEV; Pure Storage automation development/test role; DEV01/DEV02 Pure Pod membership; promotion/demotion may change replicated-storage ownership/activation; AIX `7300-04-02-2633`; `/usr/spool/uv` mounted when corresponding replicated/application storage should be active on DEV01; `old_rootvg` retained inactive during normal operation; 16 MPIO paths per applicable disk; expected FC adapters `fcs0`–`fcs3`; zero stale PPs; required active SRC services `sshd` and `splunkd`; repository filesystem thresholds and error-log review policy.
- **Observed but unconfirmed items:** Host identity, PowerVM values, filesystem utilization/mount observations, active VG/PV and disk inventory, storage type/path states, FC attributes, and network values.
- **Unknown items:** Runtime Pure site state until independently supplied/confirmed; replicated target mapping and expected role of each disk/VG/filesystem; expected active VGs by Pure state; `hdisk2` assignment by Pure state; filesystem mount state when corresponding replicated storage is not expected active; expected path states; server-specific network expectations; paging threshold; other SRC expectations.
- **NOT APPLICABLE items:** None established by the supplied evidence; none approved by an owner.
- **Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

## Assessment Order and Safety

Apply the sequence: collected evidence → collection validity → this host profile and [pure-automation-dev.md](pure-automation-dev.md) → independently confirmed Pure site state → deviations from confirmed expectations → engineering findings. Never infer Pure site state from the audited disk, VG, mount, or MPIO state. If state is UNKNOWN, do not generate state-dependent assignment/VG/mount findings. This profile does not override evidence or establish health. Investigation remains read-only; remediation is outside the audit workflow.
