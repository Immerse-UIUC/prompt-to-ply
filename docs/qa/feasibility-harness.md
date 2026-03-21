# Feasibility Harness

This document defines Milestone 0 from the canonical architecture.

## Goal

Validate the end-to-end MVP path:

`prompt -> still candidates -> candidate selection -> selected-still QC -> ml-sharp -> bundle -> viewer`

## Harness Inputs

- 10 fixed tabletop-vignette prompts
- 2 captured-image baselines
- fixed target resolution of `1024x1024` for generated stills
- default still backends under evaluation:
  - Google Gemini
  - FLUX.1-dev on the RTX worker

Prompt fixtures are defined in `docs/prompts/feasibility-harness-prompts.md`.

## Procedure

1. Run each prompt through the still-generation pipeline.
2. Generate 4 candidate stills for each prompt.
3. Select the best candidate manually.
4. Run selected-still QC and record pass or failure reasons.
5. Execute `ml-sharp`.
6. Write the bundle and capture logs.
7. Open the resulting `.ply` in MetalSplatter when available.
8. Record visual acceptability and any operational failures.

## Pass Gate

- at least 7 of 10 generated jobs complete without manual file surgery
- at least 5 of 10 generated jobs are visually acceptable in MetalSplatter

If the pass gate is not met:

- keep generated input experimental
- keep captured-image input as the primary debug path

## Per-Run Record

Each run should capture:

- prompt id
- still backend
- candidate chosen
- QC result
- reconstruction result
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
- backend and seed provenance where available
