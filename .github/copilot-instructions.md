# Copilot Instructions

This repository builds a safe, evidence-based IBM AIX audit agent for platform engineers. Follow [AGENT.md](../AGENT.md) as the governing audit contract.

## Non-negotiable safety

**READ-ONLY BY DEFAULT.** The collector and any generated workflow must never automatically remediate an AIX system. Keep remediation entirely outside the audit workflow. If remediation appears necessary, report **HUMAN APPROVAL REQUIRED** and provide only read-only investigation guidance.

Never connect to an AIX server automatically, use SSH, access production autonomously, or use or request credentials. A failed or partial collection is not evidence of health. Missing evidence must never be reported as Healthy; classify it as **Insufficient Evidence**.

The collector's only permitted host-side write is creating exactly one new, internally named, timestamped evidence file in the current trusted directory. Never modify, overwrite, or append to an existing file; create temporary files; delete or rename files; or change permissions or ownership of existing files. Never modify AIX configuration or operational state. Never add automated actions that change permissions, ownership, users, groups, or passwords; modify devices; run `cfgmgr`, `chdev`, or `rmdev`; change networking, routes, LVM, filesystems, mounts, volume group state, MPIO state, diagnostics, statistics, services, software, cron, or SAN/storage; kill processes; reboot; or shut down. Never start, stop, or restart services.

A command name is not proof of safety. Independently review the exact command form, options, shell behavior, redirections, and target AIX level. Commands with read-only and modifying modes are not safe merely because one mode is observational. This specifically applies to `no`, `nfso`, `vmo`, `ioo`, `ifconfig`, and `lsmpio`; do not add them to automated collection without exact-form review. When uncertain, omit the command and explain the evidence gap.

## Engineering requirements

- Keep collection explicit, minimal, and read-only; prefer fixed command invocations over dynamic dispatch or `eval`.
- Permit only the collector's single new timestamped evidence file in the current trusted directory; do not modify existing files, create temporary files, or change host state.
- Do not claim a result that is not supported by collected evidence. Preserve command context and label uncertainty.
- Use the four confidence classifications and the required finding fields defined in `AGENT.md`.
- Keep changes focused and compatible with AIX KornShell conventions. Review every added command and option for the supported AIX release before use.
- Do not copy code or files from the separate `sasi-chand` repository into this project.
