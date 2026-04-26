# Next Steps

## Current

Detailed phase guide:

- `docs/worklog/Phase1_Implementation-Plan.md`

### macOS local phase

1. Turn the bundle manifest schema into concrete successful and failed manifest examples plus validation checks.
2. Start `packages/job-core` as the shared Swift library for canonical job and artifact types.
3. Start `apps/mac-studio` as a Swift CLI using the Phase 1 command set.
4. Add Apple-Silicon `ml-sharp` bootstrap materials under `third_party/ml-sharp/`.
5. Add captured-image baseline and modular still-provider flows with OpenAI as the default and Gemini as optional.
6. Add prompt argument and prompt-file intake while keeping advanced prompt UX outside this repo.
7. Add local pre-headset validation: image QC, candidate contact sheets, panorama QC, viewport contact sheets, `.ply` structural checks, and desktop viewer result capture.
8. Add supplied and generated equirectangular ingestion, raw 360 gut-check viewing metadata, viewport extraction, and per-viewport SHARP bundle flow.
9. Add bundle writing, QC, provenance, and validation behavior for regular still bundles and panorama viewport bundles.

### later viewer phase

1. Validate single-PLY viewing in a native visionOS target after macOS bundles are stable.
2. Add panorama source viewing as a lightweight 360 gut check.
3. Add multi-PLY viewport-set inspection after the single-PLY path works.
4. Explore a platform-agnostic WebXR/WebSpatial-style viewer as a parallel portability target.

### later lab RTX phase

1. Build the real RTX worker after CUDA, FLUX, TRELLIS, or lab-network-specific dependencies are available.
2. Move RTX-specific implementation work into a dedicated worktree and branch when the lab path becomes active.
3. Replace fixture-backed worker responses with real generation backends without changing the public worker contract.

## Open Questions

- How should `third_party/ml-sharp` be pinned and bootstrapped in this repo?
- What pinned upstream `ml-sharp` revision should Phase 1 target?
- Which concrete fixture images should seed the first three worker stub still sets?
- What equirectangular fixture image should seed the first panorama viewport test?
- What external prompt UX or sister service, if any, should become the first producer of prompt/job requests?
