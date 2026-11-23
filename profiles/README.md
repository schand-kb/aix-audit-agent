# AIX expected-state profiles

Profiles document owner-confirmed expectations for interpreting collected AIX audit evidence. They are not evidence, do not assert health, and must never override a collection result, collection failure, or evidence limitation. An observed value is not an expected value until an authorized owner confirms it.

## Files

- [standard-aix.md](standard-aix.md): reusable template for owner-reviewed profile data.
- [pure-automation-dev.md](pure-automation-dev.md): shared confirmed role and conditional Pure replication rules for DEV01/DEV02 only.
- [kbdvultdev01.md](kbdvultdev01.md), [kbdvultdev02.md](kbdvultdev02.md), and [kbdvultdev03.md](kbdvultdev03.md): DEV drafts populated with observations from the approved audit reports. These values remain unconfirmed unless individually marked **CONFIRMED EXPECTED**.

## Item classifications

Every profile item must use exactly one of these classifications:

- **CONFIRMED EXPECTED** — confirmed by an authorized owner or approved standard, with source, scope, and review date.
- **OBSERVED - EXPECTATION NOT YET CONFIRMED** — directly observed in evidence, but not accepted as a baseline.
- **NOT APPLICABLE** — explicitly confirmed as not applicable; do not use as a synonym for missing or uncollected data.
- **UNKNOWN / REQUIRES OWNER CONFIRMATION** — no approved expected value is available.

Keep the observed value, expected value, evidence/source, owner, applicable scope, and review date distinguishable. Use UNKNOWN rather than deriving intent from current configuration, labels, service state, or absence of output. In particular, do not infer that inactive VGs, unassigned PVs, MPIO counts/states, or inoperative SRC services are expected. Configured-but-not-mounted filesystems are expected-state verification items until the server-role baseline confirms the mount state.

## Pure replication state

`pure-automation-dev.md` applies only to `kbdvultdev01` and `kbdvultdev02`. It defines the confirmed shared role and conditional storage expectations for their development Pure Pod. `kbdvultdev03` is standalone; Pure replication state is **NOT APPLICABLE** there, and no DEV01/DEV02 promotion, demotion, target-disk, replicated-VG, or replicated-filesystem rules apply.

For DEV01/DEV02, the runtime Pure site state must be explicitly supplied or independently confirmed as `PROMOTED`, `DEMOTED`, or `UNKNOWN`. Do not infer it from disk assignment, VG state, filesystem mount state, or MPIO state in the evidence being audited. That would be circular reasoning. With state `UNKNOWN`, report **UNKNOWN / REQUIRES OWNER CONFIRMATION** for dependent replicated-storage expectations and do not generate compliance findings about them. Only compare storage with the conditional baseline after state and the applicable replicated target mapping are independently confirmed.

Topology and observed Pure-side connections are documented in [pure-dev-topology.md](../references/pure-dev-topology.md) and [pure-dev-volume-map.md](../references/pure-dev-volume-map.md). The owner-supplied ten DEV01/DEV02 Pure-volume-to-AIX-disk mappings are confirmed by exact Pure/AIX serial equality. The volume-map reference records the partial AIX VG/LV/filesystem correlation and the unresolved promoted-side `data2vg` expectation. The [runtime context](../references/pure-runtime-context.md) must independently establish the host, array, Pod, promotion state, and applicability at the AIX collection time; a historical topology or volume map is not runtime state. Current AIX VG roles come from current AIX LVM evidence, not Pure volume names. Historical observations must not become unconditional profile defaults.

## Assessment order

Analyze in this order:

1. Collected evidence.
2. Collection validity.
3. Applicable server profile.
4. Deviations from **confirmed** expectations only.
5. Engineering findings.

An UNKNOWN profile item must not generate a configuration-compliance finding. A deviation is meaningful only when evidence is valid and an applicable expected value has been confirmed. Conflicting or incomplete evidence remains an evidence limitation; profiles cannot repair that gap.

Repository filesystem thresholds are 85% warning, 90% high, and 95% critical. A host-specific threshold requires owner approval and documented scope; do not treat these thresholds as a universal health conclusion.

## Profile lifecycle and safety

All new profiles begin **DRAFT - OWNER VALIDATION REQUIRED**. Owners should confirm identity, role, environment, service expectations, and configuration baselines before readiness is changed. Record who approved each expectation, when, and for which host/role/AIX scope. Review profiles when a host role or approved configuration changes.

Profiles may contain internal configuration information; handle them under approved internal controls. Never include credentials or remediation instructions. The audit process remains read-only and follows [AGENT.md](../AGENT.md). Before adding a collection command, independently review its exact form and options for the target AIX release; a profile does not authorize or cause new collection commands.
