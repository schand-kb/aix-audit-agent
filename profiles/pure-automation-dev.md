# Pure Storage Automation Development Role Profile

**Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

Applies only to `kbdvultdev01` and `kbdvultdev02`. Host-specific disk, VG, filesystem, and PowerVM values remain in the corresponding host profiles and are not established by this shared role.

## Confirmed Role

| Item | Status | Confirmed expectation |
|---|---|---|
| Environment | CONFIRMED EXPECTED | DEV |
| Role | CONFIRMED EXPECTED | Pure Storage automation development/test LPAR |
| Replication group | CONFIRMED EXPECTED | DEV01/DEV02 development Pure Pod / replication partnership |
| Replication behavior | CONFIRMED EXPECTED | Promotion/demotion testing may intentionally change which side owns or activates replicated storage. |

## Pure Site State

| Item | Status | Value / rule |
|---|---|---|
| Pure site state | UNKNOWN / REQUIRES OWNER CONFIRMATION | Runtime value must be one of `PROMOTED`, `DEMOTED`, or `UNKNOWN`. Default to `UNKNOWN` unless supplied or independently confirmed for this audit. |

Do not infer Pure site state from the storage configuration being audited, including disk assignment, VG state, filesystem mount state, or MPIO state. The state must be supplied or independently confirmed using information separate from those audited observations. Inferring it from the same storage state would be circular reasoning.

## Conditional Replicated-Storage Expectations

First identify, from an owner-confirmed automation-test configuration, which disks, VGs, and filesystems are replicated targets and their intended roles on each side. That mapping is not supplied by this shared profile. Do not apply these rules to host-local or non-replicated resources.

| Independently confirmed Pure site state | Conditional expected state for applicable replicated targets |
|---|---|
| `PROMOTED` | Target storage expected for that side should be available according to its defined automation-test configuration. Applicable replicated VGs should be active, applicable replicated filesystems mounted, and applicable replicated disks in their confirmed promoted-side assignments/states. Only confirmed deviations may generate findings. |
| `DEMOTED` | Replicated target disks may be visible but unassigned; replicated target VGs are not expected active on that side; replicated filesystems are not expected mounted on that side. These expected demoted states must not generate faults. |
| `UNKNOWN` | Return **UNKNOWN / REQUIRES OWNER CONFIRMATION** for state-dependent disk assignment, VG, and mount expectations. Do not generate compliance findings for those conditional states. |

| Conditional profile item | Status | Confirmed expectation / limitation |
|---|---|---|
| Replicated target disk/VG/filesystem mapping by host and site state | UNKNOWN / REQUIRES OWNER CONFIRMATION | Obtain from the approved Pure Pod automation-test configuration; do not derive it from current evidence. |
| MPIO paths | CONFIRMED EXPECTED | 16 paths per applicable disk; “applicable” disk identity and any topology-specific exceptions must be determined from the approved configuration. |

`old_rootvg` and other host-specific VGs/disks are governed by the host profile unless the owner explicitly identifies them as replicated targets.

## Profile Confidence

- **Confirmed expected items:** DEV environment, shared Pure Storage automation development/test role, DEV01/DEV02 Pure Pod membership, promotion/demotion testing may change replicated-storage ownership/activation, and 16 MPIO paths per applicable disk.
- **Observed but unconfirmed items:** Host-specific hardware/storage inventory and current configuration are recorded only in each host profile.
- **Unknown items:** Runtime Pure site state until independently supplied/confirmed; mapping and expected role of each replicated target disk, VG, and filesystem; any other state-dependent host-specific baseline.
- **NOT APPLICABLE items:** None assigned by this shared profile.
- **Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

## Assessment Order and Safety

Apply the sequence: collected evidence → collection validity → host profile and this role profile → independently confirmed Pure site state → deviations from confirmed conditional expectations → engineering findings.

Evidence must never be used to infer the Pure site state from the storage state being audited. For example, independently confirmed `DEMOTED` plus an unassigned replicated target disk may match the expected demoted state. An unassigned disk alone does not establish that the site is demoted. If site state is unknown, report **UNKNOWN / REQUIRES OWNER CONFIRMATION** and do not generate a state-dependent compliance finding.

Profiles do not override evidence or collection validity. Investigation remains read-only; remediation is outside the audit workflow.
