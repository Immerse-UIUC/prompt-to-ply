# Bundle Manifest

This document describes the `manifest.json` written into each job bundle.

## Source Of Truth

- machine-readable schema: `packages/bundle-schema/manifest.schema.json`
- architecture reference: `docs/architecture/ARCHITECTURE-v2.md`

## Purpose

The manifest is the canonical persisted summary of a job bundle. It ties together:

- the user prompt
- prompt source and refined/generated prompt metadata when available
- current or terminal job status
- candidate and selected still metadata
- reconstruction outputs
- artifact paths
- provenance and camera assumptions
- local validation reports
- optional panorama viewport metadata for Phase 1 360 prototypes
- optional viewer-target metadata for non-blocking local or immersive previews

## Key Rules

- `output/output.ply` is required for successful jobs.
- `preview.png` is recommended but optional.
- `preview.mp4` is optional and environment-dependent.
- Viewer launch is not part of bundle success.
- The manifest status space follows the canonical job state machine from the architecture doc.
- Regular still bundles and panorama viewport bundles must both preserve logs, QC reports, and provenance.
- Successful bundles should preserve local pre-headset validation reports.
- Prompt provenance must preserve the original prompt even if a provider or future prompt service returns a refined prompt.

## Schema Notes

- `selectedStill` may be `null` before a candidate is chosen.
- `sharpResult` may be `null` before reconstruction succeeds.
- `provenance.cameraModel` encodes the MVP default camera assumption of `30mm_default`.
- `artifacts` stores path references for candidates, selected still, output files, logs, QC reports, and provenance records.
- `provenance.promptSource` should identify whether the prompt came from a CLI argument, prompt file, app UI, or external prompt service when known.

## Local Validation Artifacts

Phase 1 bundles should include local validation outputs before headset or immersive viewer testing.

Recommended paths:
- `qc/image-qc.json`
- `qc/panorama-qc.json`
- `qc/viewport-qc.json`
- `qc/ply-qc.json`
- `previews/candidates-contact-sheet.png`
- `previews/viewports-contact-sheet.png`

Validation reports should capture:
- pass or fail status
- artifact path under test
- dimensions or file size when relevant
- reasons for failure
- whether the check is blocking or advisory
- local viewer result when a desktop viewer is available

## Provider Metadata

Still-generation provenance should record the selected provider and provider-specific details when available.

Phase 1 providers:
- `captured`
- `openai`
- `gemini`
- `worker`

OpenAI defaults:
- model: `gpt-image-2`
- required credential: `OPENAI_API_KEY`
- model override: `PROMPT_TO_PLY_OPENAI_IMAGE_MODEL`

Gemini remains supported as an optional provider using `GOOGLE_API_KEY`.

Provider metadata should preserve generated or revised prompts when the upstream API returns them.

## Panorama Viewport Bundles

Phase 1 may emit a panorama viewport bundle for the experimental 360 path. This bundle represents a set of independent perspective SHARP runs derived from one equirectangular source image.

Required panorama concepts:
- `PanoramaInput`
- `PerspectiveViewport`
- `ViewportSet`
- `ViewportSharpResult`
- `PanoramaRunManifest`

Required behavior:
- store the equirectangular source image
- support supplied pre-existing equirectangular images as well as generated sources
- allow direct viewing of the raw equirectangular source as a 360 gut check
- validate the source image as 2:1 before viewport extraction
- store fixed perspective viewport images
- store one `.ply` output per viewport
- preserve QC, logs, and provenance per viewport
- do not claim the outputs are stitched into one 360 scene

Default viewport set:
- projection source: equirectangular
- viewport count: 6
- yaw angles: `0, 60, 120, 180, 240, 300`
- pitch: `0`
- field of view: `90`
- output naming: `viewport-000`, `viewport-060`, etc.

`packages/bundle-schema/manifest.schema.json` should be extended during implementation so `validate-bundle` can validate both regular still bundles and panorama viewport bundles.
