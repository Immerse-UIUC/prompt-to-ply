# Feasibility Harness

This document defines Milestone 0 from the canonical architecture.

## Goal

Validate the end-to-end MVP path:

`prompt -> still candidates -> candidate selection -> selected-still QC -> ml-sharp -> bundle -> viewer`

This harness also defines the Phase 1 local pre-headset validation path. Artifacts should pass local checks on a normal Mac before Vision Pro, WebXR, or WebSpatial viewing is attempted.

## Harness Inputs

- 10 fixed tabletop-vignette prompts
- 2 captured-image baselines
- supplied pre-existing equirectangular images for panorama checks
- fixed target resolution of `1024x1024` for generated stills
- default still backends under evaluation:
  - OpenAI GPT Image 2
  - Google Gemini as an optional comparison provider
  - FLUX.1-dev on the RTX worker
- optional equirectangular inputs for the Phase 1 viewport prototype

Prompt fixtures are defined in `docs/prompts/feasibility-harness-prompts.md`.

## Procedure

1. Run each prompt through the still-generation pipeline.
2. Generate 4 candidate stills for each prompt.
3. Generate a candidate contact sheet for desktop review.
4. Select the best candidate manually.
5. Run selected-still QC and record pass or failure reasons.
6. Execute `ml-sharp`.
7. Run `.ply` structural validation.
8. Write the bundle and capture logs.
9. Open the resulting `.ply` in MetalSplatter when available.
10. Record visual acceptability and any operational failures.

## Provider Matrix

Captured baseline:
- works without cloud credentials
- uses a supplied image as candidate `0`
- remains the primary fallback path

OpenAI cloud stills:
- default cloud provider
- uses `OPENAI_API_KEY`
- default model is `gpt-image-2`
- produces four candidates for normal still jobs

Gemini cloud stills:
- optional comparison provider
- uses `GOOGLE_API_KEY`
- produces the same `StillCandidate` records as OpenAI when selected

Worker fixture stills:
- uses the local Python worker stub
- validates the worker API flow before RTX generation exists

## Panorama Viewport Prototype

The Phase 1 360 harness validates a viewport prototype, not a stitched 360 scene.

Procedure:

1. Ingest a supplied equirectangular image or generate one through OpenAI.
2. Verify that the source image is 2:1.
3. Run panorama QC and record dimensions, 2:1 status, and any seam or horizon heuristics that are implemented.
4. View the raw equirectangular source as a 360 gut check when a lightweight viewer is available.
5. Extract six perspective viewports using yaw angles `0, 60, 120, 180, 240, 300`, pitch `0`, and field of view `90`.
6. Generate a viewport contact sheet for desktop review.
7. Run QC independently for each viewport.
8. Run `ml-sharp` independently for each viewport.
9. Run `.ply` structural validation for each viewport output.
10. Write one `.ply` per viewport.
11. Validate that the bundle records the panorama source, viewport images, per-viewport outputs, QC, logs, and provenance.

This harness must not treat the viewport outputs as a stitched or geometrically consistent 360 reconstruction.

## Local Pre-Headset Validation

Local validation should catch obvious bad artifacts before immersive viewing.

Image checks:
- file exists
- file decodes
- dimensions are non-zero
- format is supported by the ingest path
- generated candidates are visible in a contact sheet

Panorama checks:
- equirectangular source decodes
- source dimensions are 2:1
- seam heuristic is recorded when available
- horizon heuristic is recorded when available
- extracted viewport count and filenames match the configured viewport set

PLY checks:
- file exists
- file is non-empty
- PLY header is readable
- expected vertex or element declaration is present when emitted by the backend
- local desktop viewer result is recorded when MetalSplatter or another viewer is available

## Viewer Track Notes

- Phase 1 records viewer compatibility metadata but does not require headset viewing for success.
- Native visionOS is the first planned immersive viewer target after the local Mac flow is stable.
- A WebXR/WebSpatial-style viewer is a parallel future portability target.
- Single-PLY headset viewing should be validated before multi-PLY viewport-set inspection.

## Pass Gate

- at least 7 of 10 generated jobs complete without manual file surgery
- at least 5 of 10 generated jobs are visually acceptable in MetalSplatter
- all successful jobs have image QC, `.ply` QC, logs, and provenance
- panorama jobs have panorama QC and viewport QC before any headset testing

If the pass gate is not met:

- keep generated input experimental
- keep captured-image input as the primary debug path

## Per-Run Record

Each run should capture:

- prompt id
- prompt source
- still backend
- selected provider
- candidate chosen
- QC result
- reconstruction result
- panorama source and viewport id when applicable
- raw equirectangular gut-check result when applicable
- local validation result
- `.ply` structural validation result
- bundle-written result
- viewer result
- visual acceptability notes
- major failure mode, if any

## Output Expectations

Harness runs should preserve:

- bundle artifacts
- generation logs
- `ml-sharp` logs
- selected-still QC report
- panorama extraction report when applicable
- backend and seed provenance where available
