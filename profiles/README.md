# Host profiles

Profiles may document expected platform context, approved collection scope, and workload-specific interpretation notes. They must not contain credentials or instructions that change system state.

Before adding a profile or command, independently review its exact command form and options for the target AIX release. Profiles must follow the read-only boundary in [AGENT.md](../AGENT.md) and must never enable automatic remediation. Record the source, owner, applicable AIX level, and review date for platform assumptions.
