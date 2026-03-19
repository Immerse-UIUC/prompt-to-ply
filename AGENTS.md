# AGENTS.md

## Purpose

This repository holds the planning, architecture, and delivery documentation for the Prompt-to-PLY project.

## Source Of Truth

- Canonical architecture: `docs/architecture/ARCHITECTURE-v2.md`
- Historical architecture: `docs/architecture/Architecture-v1.md`
- Durable decisions: `docs/decisions/DECISIONS-LOG.md`
- Active tasks and sequencing: `docs/worklog/NEXT-STEPS.md`
- Ongoing execution notes: `docs/worklog/WORKLOG.md`

## Working Rules

- Update the canonical architecture doc before implementation if an architectural assumption changes.
- Record durable decisions in the decisions log, not only in issue threads or chats.
- Keep runbooks procedural and step-based.
- Keep prompt artifacts reproducible and labeled with their intended model or workflow.
- Use the worklog for active tasks, sequencing, and open blockers.
- Treat `docs/architecture/Architecture-v1.md` as historical context, not the active spec.

## Documentation Layout

- `docs/architecture`: system architecture and design docs
- `docs/api`: API contracts and interface notes
- `docs/qa`: test strategy, acceptance criteria, and validation notes
- `docs/prompts`: prompts, fixtures, and prompt workflow references
- `docs/research`: investigations, experiments, and external comparisons
- `docs/operations`: environments, deployment, monitoring, and operational policies
- `docs/runbooks`: step-by-step operational procedures
- `docs/decisions`: ADR-style records and the decisions log
- `docs/worklog`: near-term tasks, milestones, and execution notes
- `docs/agents`: agent-specific guidance beyond this root file
