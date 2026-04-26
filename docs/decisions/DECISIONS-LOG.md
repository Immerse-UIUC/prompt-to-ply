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

### D-0004 Modular Image Providers and Phase 1 Panorama Viewports

- Date: 2026-04-25
- Status: Accepted
- Decision: Phase 1 will use a modular still-provider model with OpenAI GPT Image 2 as the default cloud provider, Gemini as an optional provider, and captured/worker-backed sources behind the same provider boundary. Phase 1 will also include an experimental equirectangular viewport prototype that extracts perspective viewports and runs `ml-sharp` per viewport without stitching outputs into one 360 scene.
- Rationale: GPT Image 2 is the preferred cloud still-generation path for current work, but the pipeline should avoid provider lock-in. The viewport prototype lets the project explore 360 inputs while preserving the canonical single-image SHARP path and avoiding premature claims about coherent 360 reconstruction.

### D-0005 Viewer Tracks and Prompt UX Boundary

- Date: 2026-04-26
- Status: Accepted
- Decision: The first immersive viewer target is native visionOS, with a platform-agnostic WebXR/WebSpatial-style viewer retained as a parallel future path. Phase 1 should also support raw equirectangular image viewing as a gut check before viewport extraction. Advanced prompt UX, speech-to-text, prompt refinement, and palette workflows are not owned by this repo in Phase 1 and may be provided later by a sister service or app.
- Rationale: Native visionOS best matches the Apple Silicon and Gaussian-splat viewer direction, while a web-based path preserves portability. Keeping prompt UX outside the core pipeline lets this repo stay focused on job intake, reconstruction, bundles, provenance, and viewer interoperability.

### D-0006 Local Pre-Headset Validation Harness

- Date: 2026-04-26
- Status: Accepted
- Decision: Phase 1 will include a local validation harness that checks starting images, generated candidates, equirectangular sources, extracted viewports, and emitted `.ply` files on macOS before headset or immersive viewer testing.
- Rationale: The fastest way to de-risk Vision Pro and WebXR/WebSpatial work is to catch malformed images, weak panorama assets, failed viewport extraction, malformed `.ply` outputs, and desktop viewer issues locally before adding headset transport and runtime variables.
