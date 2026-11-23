# Pure DEV Volume-to-AIX Device Correlation

This reference records the ten owner-supplied DEV01/DEV02 Pure volume-to-AIX disk mappings. The identity correlation is **CONFIRMED BY EXACT SERIAL MATCH** between Pure CLI `purevol list` serials and AIX disk serial output collected through the owner-operated read-only disk inventory process.

Use exact serial equality as the correlation method. Do not infer identity from device names, Pure volume-name substrings, size, LUN, or VG name alone. The table's Pure and AIX serial values are the matching identifiers. AIX PVID and captured VG are additional host evidence where supplied, not the method used to identify the Pure volume. DEV02 PVID values were not supplied and are intentionally not populated.

The Pure CLI and AIX serial inventory collection timestamps were not supplied. These identity mappings do not establish Pure promotion state or prove that a historical Pure snapshot applies at an AIX evidence timestamp. Obtain independently timestamped runtime context for each assessment; see [pure-runtime-context.md](pure-runtime-context.md).

## Confirmed mappings

| Host | Array | Pod | Pure volume | Classification | Pure serial | AIX disk serial | AIX device | AIX PVID | VG in captured AIX evidence |
|---|---|---|---|---|---|---|---|---|---|
| `kbdvultdev01` | `KBKA-PSBG23-001` | `pod-ka001-ultracs` | `pod-ka001-ultracs::vol-ka-aix-t2-kbdvultdev01-data1vg-1` | Pod | `D7FD222EA1514B4D0056F693` | `D7FD222EA1514B4D0056F693` | `ultracs_hdisk1` | `00fc088a6191f7d0` | `data1vg` |
| `kbdvultdev01` | `KBKA-PSBG23-001` | `pod-ka001-ultracs` | `pod-ka001-ultracs::vol-ka-aix-t2-kbdvultdev01-data1vg-2` | Pod | `D7FD222EA1514B4D0056F694` | `D7FD222EA1514B4D0056F694` | `ultracs_hdisk2` | `00fc088a6191f657` | `data1vg` |
| `kbdvultdev01` | `KBKA-PSBG23-001` | `pod-ka001-ultracs` | `pod-ka001-ultracs::vol-ka-aix-t2-kbdvultdev01-data2vg` | Pod | `D7FD222EA1514B4D005C1225` | `D7FD222EA1514B4D005C1225` | `hdisk2` | `00fc088a34b05cec` | `None` / unassigned |
| `kbdvultdev01` | `KBKA-PSBG23-001` | Local / non-pod | `vol-ka-aix-t2-kbdvultdev01-boot` | Local / non-pod | `D7FD222EA1514B4D00012019` | `D7FD222EA1514B4D00012019` | `hdisk1` | `00fa87a66165a14c` | `old_rootvg`, inactive |
| `kbdvultdev01` | `KBKA-PSBG23-001` | Local / non-pod | `vol-ka-aix-t5-kbdvultdev01-altrootvg` | Local / non-pod | `D7FD222EA1514B4D001545AC` | `D7FD222EA1514B4D001545AC` | `hdisk0` | `00fa87a64f00d7f4` | `rootvg`, active |
| `kbdvultdev02` | `KBKA-PSBG23-002` | `pod-ka002-ultracs` | `pod-ka002-ultracs::vol-ka-aix-t2-kbdvultdev01-data1vg-1` | Pod | `391599D9E945457B00146598` | `391599D9E945457B00146598` | `ultracs_hdisk2` | Not supplied | `None` / unassigned |
| `kbdvultdev02` | `KBKA-PSBG23-002` | `pod-ka002-ultracs` | `pod-ka002-ultracs::vol-ka-aix-t2-kbdvultdev01-data1vg-2` | Pod | `391599D9E945457B00146597` | `391599D9E945457B00146597` | `ultracs_hdisk1` | Not supplied | `None` / unassigned |
| `kbdvultdev02` | `KBKA-PSBG23-002` | `pod-ka002-ultracs` | `pod-ka002-ultracs::vol-ka-aix-t2-kbdvultdev01-data2vg` | Pod | `391599D9E945457B00163C49` | `391599D9E945457B00163C49` | `hdisk1` | Not supplied | `None` / unassigned |
| `kbdvultdev02` | `KBKA-PSBG23-002` | Local / non-pod | `vol-ka-aix-t2-kbdvultdev02-rootvg` | Local / non-pod | `D7FD222EA1514B4D000124D6` | `D7FD222EA1514B4D000124D6` | `hdisk5` | Not supplied | `old_rootvg`, inactive |
| `kbdvultdev02` | `KBKA-PSBG23-002` | Local / non-pod | `vol-ka-aix-t5-kbdvultdev02-altrootvg` | Local / non-pod | `D7FD222EA1514B4D001545AD` | `D7FD222EA1514B4D001545AD` | `hdisk0` | Not supplied | `rootvg`, active |

The captured Pure host connections additionally reported LUNs 2, 3, and 6 for the three DEV01 pod volumes; LUNs 3, 2, and 5 for their DEV02 paired volumes; and LUNs 1 and 4 for each host's two local volumes. LUNs are connection context only and are not the correlation key.

There are five mappings per host: three Pod volumes and two local/non-pod volumes. The serials are unique within each host's five mappings. Each paired Pod identity has a different serial on each array; pair by the confirmed pod/volume identity and host connection, not by expecting equal cross-array serials.

## Paired Pod volume identities

Pair the corresponding host-side entries in the confirmed mapping table by their owner-confirmed Pod volume identities and host connections:

- `...data1vg-1`
- `...data1vg-2`
- `...data2vg`

These suffixes refer to the full Pure volume names in the table. Do not assume paired copies have identical serials.

## AIX VG/LV/filesystem correlation

**CONFIRMED:** Pure volume -> AIX disk identity for all ten rows above, by exact serial match.

**PARTIALLY CONFIRMED:** AIX disk -> VG -> LV -> filesystem. The owner-supplied AIX evidence confirms that DEV01 `data1vg` contains `ultracs_hdisk1` and `ultracs_hdisk2`, and reports these LV/filesystem associations:

| DEV01 AIX VG | LV | Filesystem |
|---|---|---|
| `data1vg` | `fslv03` | `/u3` |
| `data1vg` | `fslv06` | `/usr/spool/uv` |

This records the VG/LV/filesystem association, not an unconditional mount requirement. In particular, `/usr/spool/uv` must not be declared expected mounted solely because it is configured or because the DEV01 side is promoted. Assess it only against applicable, owner-confirmed runtime and filesystem expectations.

The three `data2vg`-named Pod volume identities map to `hdisk2` on DEV01 and `hdisk1` on DEV02 by serial. Those disks were captured as unassigned. The name `data2vg` does not prove a current or promoted-side VG, LV, or filesystem definition.

**UNKNOWN / REQUIRES OWNER CONFIRMATION:** The promoted-side VG/LV/filesystem expectation for the `data2vg` volume.

### Still required

- DEV02 PVID values, if needed as an additional durable correlation.
- Promoted-side VG/LV/filesystem mapping for the `data2vg` volume.
- Independently timestamped Pure runtime context for each audit, including host, array, Pod, state, and applicability to the AIX evidence time.

## Conditional promotion/demotion interpretation

Pure site state must be supplied or independently confirmed for the host, array, Pod, and AIX evidence time. Do not infer it from disk assignment, VG state, filesystem mount state, MPIO state, volume name, or this historical map.

- If DEV01 is independently confirmed `PROMOTED` and DEV02 `DEMOTED`, DEV01 Pod disks may be expected to participate according to the confirmed VG/filesystem mapping; corresponding DEV02 Pod disks may legitimately remain unassigned.
- If DEV02 is independently confirmed `PROMOTED` and DEV01 `DEMOTED`, DEV02 Pod disks may be expected to participate according to an applicable confirmed VG/filesystem mapping; corresponding DEV01 Pod disks may legitimately remain unassigned.
- The confirmed `data1vg` association is described above. Apply promoted-side expectations only when the runtime state and mapping applicability are independently established for the audit.
- The promoted-side `data2vg` VG/LV/filesystem expectation remains **UNKNOWN / REQUIRES OWNER CONFIRMATION** in either direction.
- The two local/non-pod volumes per host are outside Pod promotion/demotion evaluation. Their current AIX VG roles are determined by current AIX LVM evidence, not by Pure volume names.
- With runtime state `UNKNOWN`, do not generate state-dependent Pod disk/VG/filesystem compliance findings.
