# Standard AIX Expected-State Profile Template

Use this template as an owner-reviewed starting point, not as a source of assumed host configuration. Replace placeholders only with expectations confirmed by the service/platform owner. Keep observations separate from approved expectations and cite the source, owner, applicable scope, and review date for each confirmed value.

The allowed item classifications are:

- **CONFIRMED EXPECTED** — an authorized owner or approved standard has confirmed the expected value.
- **OBSERVED - EXPECTATION NOT YET CONFIRMED** — evidence shows a current value, but that does not make it expected.
- **NOT APPLICABLE** — the owner confirms the item does not apply to this LPAR.
- **UNKNOWN / REQUIRES OWNER CONFIRMATION** — no expectation can yet be assigned.

Do not treat an unfilled field as healthy or compliant. Do not let a profile override, repair, or suppress collected evidence.

## Identity

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Hostname | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm hostname>` | `<fill in>` |
| Environment | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm environment>` | `<fill in>` |
| Server role | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm role and service purpose>` | `<fill in>` |
| Expected AIX level | CONFIRMED EXPECTED | `7300-04-02-2633` | Owner-confirmed common expectation; `<scope/review date>` |

## PowerVM

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Processor mode | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm shared/dedicated, SMT, capped/uncapped as applicable>` | `<fill in>` |
| Virtual processors | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm count or acceptable range>` | `<fill in>` |
| Entitled capacity | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm value or acceptable range>` | `<fill in>` |
| Memory | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm amount or acceptable range>` | `<fill in>` |

## Filesystems

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected mounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list owner-confirmed mounts>` | `<fill in>` |
| Expected intentionally unmounted filesystems | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list owner-confirmed unmounted filesystems>` | `<fill in>` |
| Warning threshold | CONFIRMED EXPECTED | 85% used (repository default) | Repository profile default; `<owner/scope/date if overridden>` |
| High threshold | CONFIRMED EXPECTED | 90% used (repository default) | Repository profile default; `<owner/scope/date if overridden>` |
| Critical threshold | CONFIRMED EXPECTED | 95% used (repository default) | Repository profile default; `<owner/scope/date if overridden>` |

Configured-but-not-mounted filesystems require expected-state verification against the server-role baseline. Do not classify their absence from mounted-filesystem output as a fault without an owner-confirmed requirement.

## LVM

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected active VGs | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list>` | `<fill in>` |
| Expected inactive VGs | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list>` | `<fill in>` |
| Expected intentionally unassigned disks | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list>` | `<fill in>` |
| Expected stale PP count | CONFIRMED EXPECTED | 0 | Owner-confirmed common expectation; `<scope/review date>` |

## Storage and MPIO

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected disks | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list disk identities and purpose>` | `<fill in>` |
| Expected storage type | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm>` | `<fill in>` |
| MPIO path count or acceptable range | CONFIRMED EXPECTED | 16 paths per applicable disk; applicable disk/topology scope must be established | Owner-confirmed common expectation; `<scope/review date>` |
| Expected path states | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm valid states by disk role/topology>` | `<fill in>` |

## Fibre Channel

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected `fcs` adapters | CONFIRMED EXPECTED | `fcs0`, `fcs1`, `fcs2`, `fcs3` | Owner-confirmed common expectation; `<scope/review date>` |
| Relevant adapter attributes | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list only attributes with an approved expected value>` | `<fill in>` |

## Network

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected interface | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm interface>` | `<fill in>` |
| Expected subnet | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm address/prefix or subnet>` | `<fill in>` |
| Expected default gateway | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm>` | `<fill in>` |

## Paging

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected paging space | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm device, size, and role if applicable>` | `<fill in>` |
| Acceptable usage threshold | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm workload-specific threshold>` | `<fill in>` |
| Expected active paging behavior | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<confirm expected baseline; interpret with interval and workload>` | `<fill in>` |

## SRC Services

| Item | Status | Expected value / observation | Source, owner, scope, review date |
|---|---|---|---|
| Expected active services | CONFIRMED EXPECTED | `sshd`, `splunkd` | Owner-confirmed common expectation; `<scope/review date>` |
| Expected intentionally inactive services | UNKNOWN / REQUIRES OWNER CONFIRMATION | `<list services expected to be inactive>` | `<fill in>` |

An inoperative SRC entry alone does not establish a fault. Require an owner-confirmed service baseline.

## Error Log Expectations

| Policy item | Status | Expected handling | Source |
|---|---|---|---|
| Permanent hardware errors | CONFIRMED EXPECTED | Require review; correlate with detailed records and current evidence. | Audit policy |
| Repeated path failures | CONFIRMED EXPECTED | Require review; distinguish recurrence/current path state from historical events and recoveries. | Audit policy |
| FC adapter errors | CONFIRMED EXPECTED | Require review; correlate with adapter, path, VIOS, and fabric context when available. | Audit policy |
| Historical recovered events | CONFIRMED EXPECTED | Distinguish historical recovered events from current faults; a historical entry alone is not proof of a current fault. | Audit policy |

## Profile Confidence

- **Confirmed expected items:** AIX `7300-04-02-2633`; 16 MPIO paths per applicable disk; expected FC adapters `fcs0`–`fcs3`; zero stale PPs; required active SRC services `sshd` and `splunkd`; repository filesystem thresholds; and error-log review policies above.
- **Observed but unconfirmed items:** `<record evidence-backed observations separately; do not promote them to expectations>`
- **Unknown items:** All fields still marked UNKNOWN / REQUIRES OWNER CONFIRMATION.
- **Profile readiness:** **DRAFT - OWNER VALIDATION REQUIRED**

## Assessment Order and Safety

Use this order:

1. Collected evidence.
2. Collection validity.
3. Applicable server profile.
4. Deviations from confirmed expectations.
5. Engineering findings.

An UNKNOWN profile item must not generate a configuration-compliance finding. A profile never overrides evidence, collection failures, or evidence limitations. Keep investigation read-only and all remediation outside the audit workflow.
