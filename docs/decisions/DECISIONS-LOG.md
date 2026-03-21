# Decisions Log

## Accepted

### D-0001 Canonical Architecture Doc

- Date: 2026-03-18
- Status: Accepted
- Decision: `docs/architecture/ARCHITECTURE-v2.md` is the canonical architecture and implementation spec for the project.
- Rationale: `Architecture-v1.md` contains useful historical context, but `v2` reflects the current single-image `ml-sharp` MVP and the current implementation contract.

### D-0002 Documentation Layout

- Date: 2026-03-18
- Status: Accepted
- Decision: Project documentation is organized under `docs/` with dedicated areas for architecture, API, QA, prompts, research, operations, runbooks, decisions, worklog, and agent guidance.
- Rationale: The repo needs a stable documentation home that separates durable specs, operational procedures, and active execution tracking.

### D-0003 Initial Repository Scaffold

- Date: 2026-03-18
- Status: Accepted
- Decision: The first implementation slice will materialize the architecture-defined repository layout and create language-neutral machine-readable contracts for the bundle manifest and RTX worker API before app-specific code is added.
- Rationale: The architecture is clear about boundaries and contracts, but the repo was still docs-only. Creating the scaffold and neutral contract artifacts gives subsequent app and service implementations a concrete source of truth without forcing premature framework choices.
