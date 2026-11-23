# Pure Storage Automation Development Role Profile

**Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

Applies only to `kbdvultdev01` and `kbdvultdev02`. Host-specific disk, VG, filesystem, and PowerVM values remain in the corresponding host profiles and are not established by this shared role.

The [volume map](../references/pure-dev-volume-map.md) records ten owner-supplied Pure-volume-to-AIX-disk identities confirmed by exact serial match: three Pod and two local/non-pod volumes per host. The two local boot/altroot volumes per host are outside Pod promotion/demotion evaluation. [Topology](../references/pure-dev-topology.md) records the relationship; independently timestamped [runtime context](../references/pure-runtime-context.md) is still required for each audit. The serial mapping establishes volume identity, not current AIX VG role or promotion state.

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

Apply these rules only to the three mapped Pod disks per host in the [volume map](../references/pure-dev-volume-map.md); the two mapped local/non-pod disks per host are excluded from Pod promotion/demotion evaluation. Exact serial equality establishes Pure volume identity. Determine current AIX VG role from current AIX LVM evidence, not from volume names, device names, sizes, LUNs, or VG-name strings.

| Independently confirmed Pure site state | Conditional expected state for applicable replicated targets |
|---|---|
| `PROMOTED` | Target storage expected for that side should be available according to its defined automation-test configuration. Applicable replicated VGs should be active, applicable replicated filesystems mounted, and applicable replicated disks in their confirmed promoted-side assignments/states. Only confirmed deviations may generate findings. |
| `DEMOTED` | Replicated target disks may be visible but unassigned; replicated target VGs are not expected active on that side; replicated filesystems are not expected mounted on that side. These expected demoted states must not generate faults. |
| `UNKNOWN` | Return **UNKNOWN / REQUIRES OWNER CONFIRMATION** for state-dependent disk assignment, VG, and mount expectations. Do not generate compliance findings for those conditional states. |

## Confirmed device and conditional AIX role mapping

The detailed [Pure-to-AIX volume map](../references/pure-dev-volume-map.md) records all ten exact-serial correlations. Paired Pod volume identities are confirmed by the Pod volume identity and host connection; their serials differ across arrays and are not expected to match each other.

- A corresponding Pod disk may legitimately be unassigned on the independently confirmed demoted side. Do not report that state as a fault.
- The supplied AIX evidence confirms the DEV01 `data1vg` disk/LV/filesystem association: `ultracs_hdisk1` and `ultracs_hdisk2`; `fslv03` -> `/u3`; `fslv06` -> `/usr/spool/uv`. Apply it to promoted-side evaluation only when runtime state and mapping applicability are independently established. The association does not make `/usr/spool/uv` an unconditional mount requirement.
- The mapped DEV02 data1 Pod disks are identified, but paired identity alone does not determine their current VG/LV/filesystem state. Use current AIX LVM evidence and only the applicable confirmed promoted-side expectation.
- The three `data2vg`-named Pod volume identities map to AIX disks, but the promoted-side VG/LV/filesystem definition remains **UNKNOWN / REQUIRES OWNER CONFIRMATION**. Do not infer it from a Pure volume name.
- The mapped local boot/altroot volumes are outside Pod state evaluation; assess their current AIX state separately under the applicable host profile.

| Conditional profile item | Status | Confirmed expectation / limitation |
|---|---|---|
| Promoted-side `data2vg` VG/LV/filesystem mapping | UNKNOWN / REQUIRES OWNER CONFIRMATION | Obtain from the approved Pure Pod automation-test configuration; do not derive it from current evidence or volume names. |
| MPIO paths | OBSERVED - EXPECTATION NOT YET CONFIRMED | DEV evidence shows 16 paths per discovered disk. This is an observation, not a mandatory baseline; confirm the expected count or acceptable range and applicable disks with the owner. |

`old_rootvg` and other host-specific VGs/disks are governed by the host profile and current AIX LVM evidence, not by Pure volume names. The local/non-pod mapping excludes those local disks from Pod promotion/demotion evaluation.

## Profile Confidence

- **Confirmed expected items:** DEV environment, shared Pure Storage automation development/test role, DEV01/DEV02 Pure Pod membership, promotion/demotion testing may change replicated-storage ownership/activation, ten Pure-volume-to-AIX-disk identity mappings by exact serial equality, two local/non-pod disks per host excluded from Pod state evaluation, and the supplied DEV01 `data1vg` disk/LV/filesystem association.
- **Observed but unconfirmed items:** 16 paths per discovered disk in DEV evidence; host-specific current disk/VG/filesystem state and other configuration not explicitly established as conditional expected state.
- **Unknown items:** Runtime Pure site state until independently supplied/confirmed; time applicability of the Pure snapshot; promoted-side `data2vg` VG/LV/filesystem expectation; any other state-dependent host-specific baseline.
- **NOT APPLICABLE items:** None assigned by this shared profile.
- **Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

## Assessment Order and Safety

Apply the sequence: collected evidence → collection validity → host profile and this role profile → independently confirmed Pure site state → deviations from confirmed conditional expectations → engineering findings.

Evidence must never be used to infer the Pure site state from the storage state being audited. For example, independently confirmed `DEMOTED` plus an unassigned replicated target disk may match the expected demoted state. An unassigned disk alone does not establish that the site is demoted. If site state is unknown, report **UNKNOWN / REQUIRES OWNER CONFIRMATION** and do not generate a state-dependent compliance finding.

Profiles do not override evidence or collection validity. Investigation remains read-only; remediation is outside the audit workflow.
