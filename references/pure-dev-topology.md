# Pure DEV Topology Reference

This reference records owner-supplied topology and manually collected Pure CLI observations. The snapshot's exact collection timestamp was not supplied. Array versions and connections are observations, not guarantees of current state. Runtime promotion, connection, pod, mediator, and link states must not be treated as permanent topology.

## Arrays and relationship

| Array | Array ID | Observed software | Observed version |
|---|---|---|---|
| `KBKA-PSBG23-001` | `d7fd222e-a151-4b4d-ba91-83ab1d4d903d` | Purity//FA | `6.9.3-security_patch_fa_2026_A` |
| `KBKA-PSBG23-002` | `391599d9-e945-457b-8d52-b4c3429108a5` | Purity//FA | `6.9.3-security_patch_fa_2026_A` |

The supplied `purearray list --connect` observation describes a `sync-replication` relationship using `ip` transport between these arrays. It reported `connected` at collection; that status is point-in-time, not a baseline.

## Pods and hosts

| Array | Pod | Pure host | AIX role |
|---|---|---|---|
| `KBKA-PSBG23-001` | `pod-ka001-ultracs` | `kbdvultdev01` | Pure Storage automation development/test LPAR |
| `KBKA-PSBG23-002` | `pod-ka002-ultracs` | `kbdvultdev02` | Pure Storage automation development/test LPAR |

The owner identifies these pod views as corresponding sides of the DEV Ultracs replication test environment. Pod names alone do not prove replication direction. `kbdvultdev03` is a standalone DEV host, outside this partnership; promotion/demotion rules do not apply to it.

The supplied `purepod list` and `purepod list --mediator` views reported both pods `online`, mediator `purestorage` with mediator status `online`, and link count `1`. These values are point-in-time observations only. See [pure-runtime-context.md](pure-runtime-context.md) for runtime handling.

## Storage and connection model

The supplied host connection views classify pod-qualified volumes as pod/replicated storage and the separately named boot/root and alt-root volumes as local/non-pod storage. See the [Pure-side volume map](pure-dev-volume-map.md) for array, host, volume, and LUN observations.

`purehost list --connect` reported host group `-` for the DEV mappings, and the supplied `purehgroup list` did not show DEV01 or DEV02 as members. Model the captured mappings as direct host-volume connections; a host-group relationship is not established. Revalidate connections from independently supplied evidence when assessing a later time.

A Pure volume name containing `kbdvultdev01` does not mean that it belongs only to DEV01. Use the actual host connection, pod membership, and confirmed topology. Neither a name nor a LUN alone establishes an AIX disk, VG, or filesystem mapping.

## Confirmed Pure-to-AIX device identity

The owner supplied Pure CLI `purevol list` serials and AIX disk serial output collected with the owner-operated read-only disk inventory process. The ten DEV01/DEV02 Pure volume-to-AIX disk identities are **CONFIRMED BY EXACT SERIAL MATCH**; the complete host-qualified table is in [pure-dev-volume-map.md](pure-dev-volume-map.md).

Exact Pure/AIX serial equality is the correlation method. Do not infer identity from Pure volume names, device names, sizes, LUNs, or VG names alone. The three paired Pod volume identities have different serials on the two arrays; pair them by the confirmed Pod volume identity and host connection, not by serial equality across arrays.

The confirmed two local/non-pod volumes on each host are outside Pod promotion/demotion evaluation. For all mapped disks, current AIX VG role comes from current AIX LVM evidence, never from the Pure volume name. The serial mapping establishes device identity only; it does not establish a current Pure site state or an unconditional AIX VG/filesystem expectation. Independently timestamped Pure runtime context and applicable VG/LV/filesystem expectations remain necessary for conditional evaluation.
