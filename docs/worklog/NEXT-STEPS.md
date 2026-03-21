# Next Steps

## Current

Detailed phase guide:

- `docs/worklog/Phase1_Implementation-Plan.md`

### macOS local phase

1. Turn the bundle manifest schema into concrete successful and failed manifest examples plus validation checks.
2. Start `packages/job-core` as the shared Swift library for canonical job and artifact types.
3. Start `apps/mac-studio` as a Swift CLI using the Phase 1 command set.
4. Add Apple-Silicon `ml-sharp` bootstrap materials under `third_party/ml-sharp/`.
5. Add captured-image baseline and Gemini still-generation flows.
6. Add bundle writing, QC, provenance, and validation behavior.

### later lab RTX phase

1. Build the real RTX worker after CUDA, FLUX, TRELLIS, or lab-network-specific dependencies are available.
2. Move RTX-specific implementation work into a dedicated worktree and branch when the lab path becomes active.
3. Replace fixture-backed worker responses with real generation backends without changing the public worker contract.

## Open Questions

- How should `third_party/ml-sharp` be pinned and bootstrapped in this repo?
- What pinned upstream `ml-sharp` revision should Phase 1 target?
- Which concrete fixture images should seed the first three worker stub still sets?
