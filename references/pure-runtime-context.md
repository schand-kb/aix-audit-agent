# Pure Runtime Context

Promotion status is point-in-time context, not a permanent host or array property. For each audit or automation test, supply independently confirmed context for the relevant host, pod, array, and time. Never infer promotion from AIX disk assignment, VG state, filesystem mount state, or MPIO state.

## Runtime context schema

| Field | Value |
|---|---|
| Collection timestamp | `<timestamp and timezone, or UNKNOWN>` |
| Array | `<array name, or UNKNOWN>` |
| Pod | `<pod name, or UNKNOWN>` |
| Promotion status | `PROMOTED`, `DEMOTED`, or `UNKNOWN` |
| Pod status | `<observed status, or UNKNOWN>` |
| Mediator status | `<observed status, or UNKNOWN>` |
| Link count | `<observed count, or UNKNOWN>` |
| Source command | `<independent human-collected source, or UNKNOWN>` |

Record the host being assessed as well, and validate it against the array/pod association in [pure-dev-topology.md](pure-dev-topology.md). A source command is provenance for already supplied information, not an instruction to execute it.

Compare the runtime timestamp with the AIX evidence collection time. A later or earlier observation does not by itself prove state at the AIX capture. When time, host/pod/array identity, or applicability is unknown or materially different, report the limitation and do not assess dependent expectations unless independent evidence establishes that the state applied at the AIX collection time. Confirm the applicable Pure-to-AIX target mapping separately; see [pure-dev-volume-map.md](pure-dev-volume-map.md).

## POINT-IN-TIME EXAMPLE - NOT A BASELINE

The manually supplied `purepod list` and `purepod list --mediator` snapshot reported:

| Array | Pod | Promotion status |
|---|---|---|
| `KBKA-PSBG23-001` | `pod-ka001-ultracs` | `PROMOTED` |
| `KBKA-PSBG23-002` | `pod-ka002-ultracs` | `DEMOTED` |

The exact timestamp and timezone were not supplied. These are historical observations only, not profile defaults or evidence of state at any AIX capture. Obtain independently confirmed, time-applicable context for each future assessment.
