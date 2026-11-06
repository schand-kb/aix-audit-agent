# aix-audit-agent

A safe, evidence-based, **read-only by default** audit toolkit for IBM AIX platform engineers. The agent gathers observations and reports uncertainty; it never automatically remediates an AIX system.

## Contents

- [AGENT.md](AGENT.md): audit role, evidence standards, confidence classifications, and safety boundary.
- [scripts/aix_readonly_audit.ksh](scripts/aix_readonly_audit.ksh): intentionally empty placeholder; no AIX commands are approved or executable yet.
- [profiles/README.md](profiles/README.md): guidance for future host profiles.
- [evidence/](evidence/): reserved for evidence managed by the operator.
- [reports/](reports/): reserved for reports managed by the operator.

## Use

The script is empty and must not be used as a collector. Design and independently review an exact command allowlist before adding any executable collection code. Review command forms, options, and target AIX level; command names alone do not establish safety. No AIX collection is performed by this project yet.

## Safety

No automatic remediation is permitted. If remediation appears necessary, report **HUMAN APPROVAL REQUIRED** and keep remediation outside this audit workflow. See [AGENT.md](AGENT.md) and [.github/copilot-instructions.md](.github/copilot-instructions.md).
