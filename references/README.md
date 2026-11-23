# AIX Audit Reference Models

These references contain internal infrastructure information, potentially including array names and IDs, pod names, hostnames, Pure volume names, LUN mappings, and replication relationships. Handle them under approved internal controls. Do not include passwords, tokens, private keys, API keys, or other credentials.

- **Profiles** define confirmed expected state; see [profiles/README.md](../profiles/README.md).
- **References** document topology and mappings, not live state: [pure-dev-topology.md](pure-dev-topology.md) and [pure-dev-volume-map.md](pure-dev-volume-map.md).
- **Runtime context** supplies independently confirmed, point-in-time state for a particular audit or test; see [pure-runtime-context.md](pure-runtime-context.md).
- **Evidence** records observed AIX state, with collection validity and limitations.
- **Reports** contain reviewed analysis; neither a report nor a reference overrides evidence.

The Pure data was supplied from manually collected read-only CLI observations. Its exact collection timestamp was not supplied. Connections, LUNs, versions, and status may change; a recorded observation is not automatically a current configuration or approved AIX device mapping.

The AIX collector remains AIX-only. Pure collection is a separate, human-controlled read-only process. These references do not authorize connections, command execution, or remediation.
