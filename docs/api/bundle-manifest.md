# Bundle Manifest

This document describes the `manifest.json` written into each job bundle.

## Source Of Truth

- machine-readable schema: `packages/bundle-schema/manifest.schema.json`
- architecture reference: `docs/architecture/ARCHITECTURE-v2.md`

## Purpose

The manifest is the canonical persisted summary of a job bundle. It ties together:

- the user prompt
- current or terminal job status
- candidate and selected still metadata
- reconstruction outputs
- artifact paths
- provenance and camera assumptions

## Key Rules

- `output/output.ply` is required for successful jobs.
- `preview.png` is recommended but optional.
- `preview.mp4` is optional and environment-dependent.
- Viewer launch is not part of bundle success.
- The manifest status space follows the canonical job state machine from the architecture doc.

## Schema Notes

- `selectedStill` may be `null` before a candidate is chosen.
- `sharpResult` may be `null` before reconstruction succeeds.
- `provenance.cameraModel` encodes the MVP default camera assumption of `30mm_default`.
- `artifacts` stores path references for candidates, selected still, output files, logs, QC reports, and provenance records.
