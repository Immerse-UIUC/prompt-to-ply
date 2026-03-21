# Prompt-to-PLY

Prompt-to-PLY is a macOS-first pipeline for turning text or speech prompts into 3D Gaussian splats (`.ply`) using Apple's `ml-sharp`.

The canonical architecture and implementation spec lives in `docs/architecture/ARCHITECTURE-v2.md`.

## Current Repository State

This repository currently contains:

- architecture and planning docs
- the initial project documentation layout
- the first implementation scaffold for apps, services, packages, and third-party integrations
- initial machine-readable contracts for the bundle manifest and RTX worker API
- Milestone 0 feasibility harness documentation and prompts

## Repository Layout

```text
/apps
  /mac-studio
  /visionos-client

/services
  /rtx-worker
  /orchestrator-test-fixtures

/packages
  /contracts
  /bundle-schema
  /job-core
  /viewer-interop

/third_party
  /ml-sharp

/docs
  /architecture
  /api
  /qa
  /prompts
  /research
  /operations
  /runbooks
  /decisions
  /worklog
  /agents
```

## Starting Points

- architecture: `docs/architecture/ARCHITECTURE-v2.md`
- worker API contract: `packages/contracts/rtx-worker.openapi.yaml`
- bundle manifest schema: `packages/bundle-schema/manifest.schema.json`
- milestone 0 harness: `docs/qa/feasibility-harness.md`
- active tasks: `docs/worklog/NEXT-STEPS.md`
