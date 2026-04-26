# Phase 1 Implementation Plan

## Purpose

This is the active execution plan for the current Apple-Silicon-first phase. It exists to convert the canonical architecture into concrete implementation work that can be done now on macOS without requiring RTX hardware.

## Source Of Truth

- canonical architecture: `docs/architecture/ARCHITECTURE-v2.md`
- worker API detail: `docs/api/rtx-worker-api.md`
- worker machine-readable contract: `packages/contracts/rtx-worker.openapi.yaml`
- bundle detail: `docs/api/bundle-manifest.md`
- bundle machine-readable schema: `packages/bundle-schema/manifest.schema.json`
- feasibility harness reference: `docs/qa/feasibility-harness.md`

Rule:

- if this document conflicts with `docs/architecture/ARCHITECTURE-v2.md`, update the architecture first and then reconcile this plan

## Phase Goal

The goal of this phase is to:

- make one local end-to-end path runnable on macOS using `ml-sharp`
- support captured-image baselines now
- support OpenAI GPT Image 2 still generation from macOS when credentials are available
- keep Google Gemini available as an optional swappable provider
- build a fixture-backed Python worker stub that matches the MVP worker contract
- add a Phase 1 equirectangular viewport prototype
- keep prompt UX minimal while allowing future sister services to submit prompts or jobs
- avoid requiring RTX access for completion of the phase

## Scope

In scope:

- Apple Silicon SHARP bootstrap
- Swift CLI control plane
- captured-image baseline flow
- OpenAI GPT Image 2 still generation flow
- optional Google Gemini still generation flow
- bundle writing, QC, provenance, and logs
- Python FastAPI worker stub
- fixture assets and worker-stub integration
- equirectangular image ingestion or generation
- raw equirectangular image gut-check viewing as a lightweight validation step
- perspective viewport extraction and per-viewport SHARP runs
- runbooks and validation docs

Out of scope:

- SwiftUI app
- visionOS client
- WebXR/WebSpatial viewer implementation
- advanced prompt UX, speech-to-text, palette selection, or prompt-refinement service implementation
- real FLUX/TRELLIS execution
- CUDA-only preview rendering requirements
- real RTX deployment and scheduling
- stitched 360 scene composition
- multiview/orbit pipelines for the normal MVP still path

## Worktree Strategy

- single worktree now
- commit the current uncommitted scaffold as the baseline before starting new implementation work
- no second worktree until real RTX-specific work begins
- create a later dedicated worktree only when CUDA or lab-specific dependencies become active
- when that later split is needed, use branch `codex/rtx-worker-lab` for real RTX integration only

## Deliverables

- lock the documentation contract for this phase
- local `ml-sharp` bootstrap procedure and wrapper
- Swift CLI package for local control-plane execution
- shared `job-core` Swift library with job and domain types
- Python FastAPI worker stub
- fixture catalog and still-set assets
- equirectangular viewport extraction prototype
- supplied equirectangular image ingestion path
- local pre-headset validation harness
- panorama viewport bundle validation
- bundle manifest examples and validation flow
- updated runbooks and worklog references

Documentation contract for this phase:

- architecture doc defines system behavior
- runbooks define operator steps
- API docs define surface behavior
- schemas and OpenAPI define machine-readable truth
- worklog tracks sequencing and blockers

## Track A: Local SHARP On Apple Silicon

Implementation choices:

- use Miniforge via Homebrew if `conda` is missing
- use a dedicated environment named `prompt-to-ply-sharp`
- target the Python version required by the pinned upstream `ml-sharp` revision, defaulting to Python 3.13 unless the pinned revision says otherwise
- pin upstream `ml-sharp` under `third_party/ml-sharp/upstream`
- store the pin in `third_party/ml-sharp/VERSION`
- add:
  - `third_party/ml-sharp/bootstrap-macos.sh`
  - `third_party/ml-sharp/run-predict.sh`

Responsibilities:

- bootstrap the local environment
- pin the upstream revision
- verify upstream CLI imports
- run local prediction on Apple Silicon using MPS when available
- capture logs to explicit paths
- avoid designing phase success around CUDA-only `preview.mp4`

`bootstrap-macos.sh` must:

- install Miniforge only if `conda` is missing
- clone `apple/ml-sharp` into `third_party/ml-sharp/upstream`
- check out the exact pinned commit from `third_party/ml-sharp/VERSION`
- create or update the `prompt-to-ply-sharp` conda environment
- install upstream dependencies for the pinned revision
- run a smoke check proving the upstream CLI imports and responds

`run-predict.sh` must:

- accept a selected still image path plus output directory
- stage the input into the format expected by the pinned upstream revision
- run prediction on Apple Silicon using MPS when available
- capture stdout and stderr to a log path provided by the caller
- return non-zero on failure so the CLI can map it to `reconstruction_failed`

## Track B: Swift CLI Control Plane

Implementation choices:

- implement as a Swift Package
- use `packages/job-core` for domain logic
- use `apps/mac-studio` for the CLI executable
- use Swift ArgumentParser
- use Foundation networking
- use `Process` for SHARP wrapper invocation

Required package paths:

- `packages/job-core/Package.swift`
- `packages/job-core/Sources/JobCore/`
- `packages/job-core/Tests/JobCoreTests/`
- `apps/mac-studio/Package.swift`
- `apps/mac-studio/Sources/PromptToPLYCLI/`
- `apps/mac-studio/Tests/PromptToPLYCLITests/`

`packages/job-core` must become the shared Swift library for domain logic with these concrete types:

- `GenerationJob`
- `JobStatus`
- `StillCandidate`
- `SelectedStill`
- `QCReport`
- `SharpResult`
- `BundleManifest`
- `ArtifactLayout`
- `ProvenanceRecord`

`JobStatus` must exactly cover the architecture state machine:

- `created`
- `generating_stills`
- `stills_ready`
- `candidate_selected`
- `selected_still_qc`
- `reconstruction_running`
- `reconstruction_succeeded`
- `bundle_written`
- `viewer_ready`
- `completed`
- `generation_failed`
- `qc_failed`
- `reconstruction_failed`
- `bundle_failed`
- `viewer_failed`
- `transfer_failed`

Required CLI commands:

- `check-sharp-env`
- `run-captured`
- `generate-cloud-stills`
- `generate-equirect`
- `extract-viewports`
- `run-panorama-viewports`
- `select-candidate`
- `run-reconstruction`
- `validate-bundle`
- `show-job`

Command behavior:

- `check-sharp-env` verifies the local SHARP bootstrap and reports MPS readiness
- `run-captured` auto-selects the one captured candidate
- `generate-cloud-stills --provider openai|gemini` writes a bundle at `stills_ready`
- `generate-equirect --provider openai` writes a panorama source image for the viewport prototype
- `extract-viewports` converts one equirectangular image into fixed perspective viewport images
- `run-panorama-viewports` runs QC, SHARP, and output writing per viewport
- `select-candidate` marks one candidate
- `run-reconstruction` runs QC, SHARP, and bundle writing
- `validate-bundle` checks regular still bundles and panorama viewport bundles
- `show-job` prints manifest-driven state

CLI implementation defaults:

- default job root: `~/Library/Application Support/PromptToPLY/jobs/<job-id>/`
- allow `--output-root` override for all commands
- do not require interactivity
- if candidate selection is needed, it must happen through `--index` on `select-candidate`
- accept prompts from CLI arguments or prompt files in this phase
- preserve the original prompt and any provider-returned revised prompt metadata in provenance

Prompt UX boundary:

- Phase 1 does not implement a full prompt-composition product.
- Advanced speech-to-text, pre-prompting palettes, iterative refinement, and creative prompt workflows may be handled by a later sister service or app.
- Any future prompt service should submit ordinary prompt/job requests into this control plane rather than taking ownership of reconstruction, bundles, or job state.

## Track B1: Still Sources For The CLI

Implement four still-source paths behind one internal abstraction in the Swift CLI:

- `StillSourceProvider`
- `CapturedStillSource`
- `OpenAIImageSource`
- `GeminiStillSource`
- `WorkerStillSource`

Behavior:

- `CapturedStillSource` writes one candidate and auto-selects it for baseline or debug runs
- `OpenAIImageSource` generates four candidates using OpenAI GPT Image 2 and stops at `stills_ready`
- `GeminiStillSource` generates four candidates using Google Gemini and stops at `stills_ready`
- `WorkerStillSource` talks to the Python worker stub over HTTP and mirrors the same still-generation lifecycle

Configuration:

- `OpenAIImageSource` uses `OPENAI_API_KEY`
- `OpenAIImageSource` defaults to `gpt-image-2`
- `OpenAIImageSource` allows `PROMPT_TO_PLY_OPENAI_IMAGE_MODEL` to override the model
- provider selection uses `PROMPT_TO_PLY_STILL_PROVIDER=openai|gemini|worker|captured`
- `GeminiStillSource` uses `GOOGLE_API_KEY`
- `WorkerStillSource` uses `PROMPT_TO_PLY_WORKER_BASE_URL`
- all providers must produce candidate metadata that serializes into the same `BundleManifest`

Cloud behavior choice for this phase:

- captured-image baselines and cloud stills are both first-class
- captured-image path must work with zero external credentials
- OpenAI is the default cloud path and is enabled only when `OPENAI_API_KEY` is present
- Gemini remains available only when `GOOGLE_API_KEY` is present
- if `GOOGLE_API_KEY` is absent and Gemini is selected, `generate-cloud-stills` should fail cleanly with a configuration error, not a crash
- if `OPENAI_API_KEY` is absent and OpenAI is selected, `generate-cloud-stills` should fail cleanly with a configuration error, not a crash
- use OpenAI's Image API for direct Phase 1 still generation
- keep OpenAI's Responses API image generation as future-friendly for multi-turn editing or reference-image workflows

## Track B1a: Equirectangular Viewport Prototype

Add an experimental 360 path that keeps `ml-sharp` on ordinary perspective stills.

Behavior:

- accept either a supplied equirectangular image or a generated one
- generate equirectangular images through `OpenAIImageSource` using a panorama/equirectangular prompt and a 2:1 output size when supported by the API
- store the equirectangular source image in the bundle
- support supplied pre-existing 360 images as first-class panorama inputs
- make the raw equirectangular image available for direct 360 viewing as a gut check before viewport extraction and SHARP runs
- validate that panorama inputs are 2:1 before extraction
- extract fixed perspective viewports from the equirectangular source
- run selected-still QC and `ml-sharp` separately for each viewport
- write one `.ply` per viewport
- package the result as a multi-output viewport set, not a stitched 360 scene

Viewport defaults:

- projection source: equirectangular
- viewport count: 6
- yaw angles: `0, 60, 120, 180, 240, 300`
- pitch: `0`
- field of view: `90`
- output naming: `viewport-000`, `viewport-060`, etc.
- stitching and composition: explicitly deferred

## Track B2: Bundle Writing, QC, And Provenance

All CLI job paths must write bundles exactly to the architecture layout:

- `manifest.json`
- `prompt.txt`
- `candidates/`
- `selected/`
- `output/`
- `logs/`
- `qc/`
- `provenance/`

Panorama viewport jobs must also write:

- `panorama/source-equirect.png`
- `panorama/extraction-report.json`
- optional `panorama/viewer-notes.json` or equivalent metadata for raw equirectangular gut-check viewing
- `viewports/viewport-000.png`, `viewports/viewport-060.png`, etc.
- `output/viewport-000.ply`, `output/viewport-060.ply`, etc.

Implement these concrete writers:

- `ManifestWriter`
- `ArtifactLayoutWriter`
- `QCReportWriter`
- `ProvenanceWriter`

Selected-still QC must include:

- file exists
- file readable
- non-zero dimensions
- supported file type
- no obvious corruption based on decode success

Provenance must always record:

- still source backend
- seed when available
- reconstruction backend as `ml-sharp`
- camera assumption as `assumed` with `30mm_default`
- whether preview image or preview video was generated
- still provider metadata, including generated or revised prompts when available
- prompt source metadata when the prompt originates from a file, CLI argument, or future external prompt service
- panorama source and viewport extraction metadata when running the equirectangular path

Success boundary:

- bundle success is reached at `bundle_written`
- viewer launch is post-processing only
- if viewer launch fails after a valid bundle is written, record `viewer_failed` but preserve the successful bundle artifacts and logs

## Track B3: Local Pre-Headset Validation Harness

Build validation checks that run on the Mac before any Vision Pro, WebXR, or WebSpatial viewer work.

Validation ladder:

- image QC for captured and generated stills
- candidate contact sheet for quick desktop review
- equirectangular source QC for supplied and generated panoramas
- raw equirectangular 360 gut-check viewing when a lightweight local viewer is available
- viewport extraction contact sheet
- `.ply` structural validation after SHARP execution
- MetalSplatter desktop inspection when installed

Required outputs:

- `qc/image-qc.json`
- `qc/panorama-qc.json` when a panorama source is present
- `qc/viewport-qc.json` when viewports are extracted
- `qc/ply-qc.json` for each emitted `.ply`
- `previews/candidates-contact-sheet.png` when multiple still candidates exist
- `previews/viewports-contact-sheet.png` when panorama viewports exist

Minimum validation rules:

- still images decode successfully
- dimensions are non-zero and supported
- generated candidate assets are preserved for inspection
- equirectangular images are 2:1 before viewport extraction
- seam and horizon heuristics are recorded when implemented
- extracted viewport count and names match the configured viewport set
- `.ply` files have a readable header and non-empty body
- local viewer failures are recorded but do not invalidate a valid bundle

## Track C: Python RTX Worker Stub

Implementation choices:

- framework: FastAPI
- server: uvicorn
- models: Pydantic v2
- local persistence: in-memory plus optional JSON state file
- no auth in this phase
- localhost default

Required paths:

- `services/rtx-worker/pyproject.toml`
- `services/rtx-worker/app/main.py`
- `services/rtx-worker/app/config.py`
- `services/rtx-worker/app/models.py`
- `services/rtx-worker/app/store.py`
- `services/rtx-worker/app/fixtures.py`
- `services/rtx-worker/app/routes.py`
- `services/rtx-worker/tests/`

Locked public endpoints:

- `POST /v1/stills`
- `GET /v1/jobs/{id}`
- `GET /v1/assets/{jobId}/{name}`

Explicit exclusion:

- no `POST /v1/orbit-set` route is allowed in this phase

Stub behavior:

- create deterministic jobs
- transition through `created -> generating_stills -> stills_ready`
- choose fixture sets deterministically from prompt and backend
- expose four candidates
- return `generation_failed` on fixture errors
- stream raw fixture assets

Additional stub requirements:

- on `POST /v1/stills`, create a deterministic job id and persist a job record
- choose a fixture set by hashing `prompt + backend` and taking modulo the available fixture sets
- expose four candidate assets and their metadata
- on fixture lookup failure, mark the job `generation_failed` with a retryable error only if the failure is transient
- stream raw fixture files through `GET /v1/assets/{jobId}/{name}`

## Track D: Fixtures And Supporting Docs

Required fixture structure:

- `services/orchestrator-test-fixtures/still-sets/`
- `services/orchestrator-test-fixtures/still-sets/tabletop-01/`
- `services/orchestrator-test-fixtures/still-sets/tabletop-02/`
- `services/orchestrator-test-fixtures/still-sets/tabletop-03/`
- `services/orchestrator-test-fixtures/fixture-index.json`

`fixture-index.json` must list:

- fixture set id
- intended backend compatibility
- candidate asset filenames
- optional thumbnail filenames
- width and height
- descriptive label

Fixture policy:

- use small tracked sample images for the stub
- keep fixture sets deterministic and stable across runs
- do not use real lab-only assets in this phase

Required supporting docs:

- `docs/runbooks/bootstrap-ml-sharp-on-macos.md`
- `docs/runbooks/run-local-captured-baseline.md`
- `docs/runbooks/run-cloud-still-job-on-macos.md`
- `docs/operations/local-env-macos.md`

Documentation updates required in this phase:

- update `docs/api/rtx-worker-api.md` to include worker stub behavior and fixture semantics
- update `docs/api/bundle-manifest.md` to include one successful manifest example and one failed manifest example
- update `docs/qa/feasibility-harness.md` to distinguish captured baseline runs from generated-still runs
- update `docs/worklog/NEXT-STEPS.md` to split macOS local phase work from later lab RTX phase work

## Track E: CLI Integration Against The Worker Stub

After the worker stub exists, wire `WorkerStillSource` in the Swift CLI to call it.

Required flow:

- `generate-cloud-stills` uses the selected cloud provider directly
- default `generate-cloud-stills` provider is OpenAI
- Gemini remains selectable via `--provider gemini`
- add a separate CLI path such as `generate-worker-stills` for the worker stub
- the CLI polls `GET /v1/jobs/{id}` until terminal worker status
- the CLI downloads candidate assets from `GET /v1/assets/{jobId}/{name}`
- the CLI writes them into the canonical bundle layout and transitions to `stills_ready`

This is the bridge that proves the contract boundary before the real RTX worker exists.

## Public APIs, Interfaces, And Types

Swift domain types:

- `GenerationJob`
- `JobStatus`
- `PromptInput`
- `StillSourceProvider`
- `StillCandidate`
- `SelectedStill`
- `QCReport`
- `SharpResult`
- `BundleManifest`
- `ArtifactLayout`
- `ProvenanceRecord`
- `PanoramaInput`
- `PerspectiveViewport`
- `ViewportSet`
- `ViewportSharpResult`
- `PanoramaRunManifest`
- `ValidationReport`
- `PLYValidationReport`

Worker API:

- `POST /v1/stills`
- `GET /v1/jobs/{id}`
- `GET /v1/assets/{jobId}/{name}`

Environment variables:

- `OPENAI_API_KEY`
- `GOOGLE_API_KEY`
- `PROMPT_TO_PLY_STILL_PROVIDER`
- `PROMPT_TO_PLY_OPENAI_IMAGE_MODEL`
- `PROMPT_TO_PLY_WORKER_BASE_URL`
- `PROMPT_TO_PLY_VIEWER_APP`
- `RTX_WORKER_FIXTURES_DIR`
- `RTX_WORKER_HOST`
- `RTX_WORKER_PORT`

Local wrapper interface:

- `third_party/ml-sharp/run-predict.sh <input-image> <output-dir> <log-path>`

Explicit exclusions:

- no orbit generation
- no multiview contract
- no `POST /v1/orbit-set`
- no CUDA-only requirement for local success
- no stitched 360 scene claim in Phase 1
- no advanced prompt UX ownership in this repo during Phase 1
- no WebXR/WebSpatial viewer implementation in Phase 1

## Testing And Validation

Unit tests:

- job state transitions
- illegal transitions
- manifest encode and decode shape
- QC rule coverage
- provenance defaults
- viewer-failure classification
- CLI argument parsing
- prompt argument and prompt-file ingestion
- OpenAI provider configuration
- provider override selection
- panorama input validation
- viewport default generation
- contact-sheet manifest generation
- `.ply` header parsing
- worker request validation
- deterministic fixture selection

Swift `JobCore` unit coverage:

- all legal state transitions
- illegal state transitions
- manifest encode and decode compatibility with the schema shape
- QC rules for readable, unreadable, zero-dimension, and corrupt images
- provenance defaults for `30mm_default`
- viewer failure classification

Swift CLI unit coverage:

- command argument parsing
- output root resolution
- environment-variable configuration handling
- SHARP wrapper command construction
- worker polling behavior with mocked HTTP responses

Python worker unit coverage:

- request validation for `POST /v1/stills`
- job creation and state transitions
- prompt-to-fixture deterministic selection
- 404 behavior for missing jobs and assets
- response model conformance

Integration tests:

- local SHARP environment checks
- captured baseline end-to-end run
- Gemini path with config present and absent
- OpenAI path with config present and absent
- worker stub lifecycle and asset fetch
- bundle validation after local SHARP execution
- supplied equirectangular image ingestion and raw-image gut-check metadata
- candidate and viewport contact-sheet generation
- `.ply` structural validation
- panorama viewport bundle validation

Local SHARP integration:

- `check-sharp-env` succeeds after bootstrap
- one captured baseline image runs end-to-end on Apple Silicon and reaches `bundle_written`
- logs and provenance files are present after reconstruction
- missing SHARP environment produces `reconstruction_failed` with a readable error

OpenAI integration:

- missing `OPENAI_API_KEY` fails cleanly
- default model is `gpt-image-2`
- provider override can select Gemini or OpenAI
- generated candidates serialize into the same manifest shape
- request serialization is correct
- decoded image responses are written as four candidates
- generated or revised prompt metadata is preserved in provenance when available

Gemini integration:

- request serialization is correct
- decoded image responses are written as four candidates
- missing `GOOGLE_API_KEY` fails cleanly
- a recorded fixture-based network test exists so CI does not require live cloud access

Worker stub integration:

- start the FastAPI worker locally
- create a still-generation job
- poll until `stills_ready`
- fetch all candidate assets
- validate returned metadata against the OpenAPI models

End-to-end scenarios:

- captured baseline -> QC -> SHARP -> bundle
- prompt -> Gemini stills -> selection -> SHARP -> bundle
- prompt -> OpenAI GPT Image 2 stills -> selection -> SHARP -> bundle
- supplied equirectangular image -> viewport extraction -> per-viewport SHARP -> panorama viewport bundle
- supplied equirectangular image -> raw 360 gut-check view -> viewport extraction
- OpenAI-generated equirectangular image -> viewport extraction -> per-viewport SHARP -> panorama viewport bundle
- SHARP output -> `.ply` structural validation -> MetalSplatter desktop inspection
- prompt -> worker stub stills -> selection -> SHARP -> bundle
- bundle success with viewer failure
- QC failure before reconstruction
- reconstruction failure after valid selection

Expanded end-to-end phrasing:

- captured baseline image -> auto-selected candidate -> QC -> SHARP -> bundle -> optional viewer launch
- prompt -> Gemini stills -> bundle at `stills_ready` -> explicit candidate selection -> SHARP -> bundle
- prompt -> OpenAI stills -> bundle at `stills_ready` -> explicit candidate selection -> SHARP -> bundle
- equirectangular source -> fixed perspective viewports -> one SHARP result per viewport
- prompt -> worker stub stills -> bundle at `stills_ready` -> explicit candidate selection -> SHARP -> bundle
- bundle success followed by viewer launch failure
- reconstruction failure after a valid selected still
- QC failure before reconstruction starts

## Acceptance Criteria

- local `ml-sharp` bootstrap succeeds on Apple Silicon
- `ml-sharp` can run a real prediction path on this Apple Silicon Mac
- Swift CLI can complete a captured-image baseline to `bundle_written`
- Swift CLI can generate OpenAI GPT Image 2 stills when `OPENAI_API_KEY` is present
- Swift CLI can generate Gemini stills when `GOOGLE_API_KEY` is present and Gemini is selected
- Swift CLI can generate or ingest an equirectangular image, extract viewports, and package per-viewport PLY outputs
- Swift CLI preserves prompt source and refined/generated prompt metadata when available
- Swift CLI can run the local pre-headset validation harness and produce image, panorama, viewport, and `.ply` QC reports as applicable
- Python worker stub is runnable locally
- Swift CLI can fetch stills from the worker stub and write them into the canonical bundle layout
- manifests, QC reports, logs, and provenance are preserved for success and failure
- nothing in this phase requires RTX hardware or a second worktree
- documentation exists for bootstrap, local runs, and fixture-backed worker use

## Failure Modes And Handling

- if Miniforge or bootstrap fails, stop the SHARP setup path and document exact remediation in the runbook
- if SHARP installs but MPS inference fails, keep the wrapper and mark local SHARP execution blocked while continuing with bundle and worker work
- if `OPENAI_API_KEY` is missing, captured baselines remain available and OpenAI generation fails cleanly
- if `GOOGLE_API_KEY` is missing and Gemini is selected, captured baselines remain available and Gemini generation is skipped cleanly
- if an equirectangular source is not 2:1, fail panorama QC before viewport extraction
- if viewport extraction produces missing or unreadable viewport images, fail the panorama path before SHARP
- if `.ply` structural validation fails, preserve SHARP logs and mark the reconstruction or validation step failed before headset delivery
- if prompt input is missing or malformed, fail before still generation and preserve a readable configuration error
- if the local viewer app is missing, treat viewer launch as optional and non-blocking
- if worker fixtures are missing or invalid, fail deterministically with `generation_failed` and a clear error

Additional handling notes:

- if MetalSplatter is absent, viewer launch remains optional and must not block bundle success
- if Gemini credentials are absent, captured-image flow remains the primary path and cloud still generation is skipped, not blocking the phase
- if OpenAI credentials are absent, captured-image flow remains the primary path and OpenAI cloud still generation is skipped, not blocking the phase

## Assumptions And Defaults

- single worktree
- Swift CLI for local control plane
- Python FastAPI for worker stub
- captured baselines and cloud stills both in scope
- OpenAI GPT Image 2 is the default cloud still backend
- Gemini remains available as a swappable provider
- the first 360 deliverable is a viewport-based prototype, not scene stitching
- supplied equirectangular images are first-class Phase 1 inputs
- local pre-headset validation is required before Vision Pro or WebXR/WebSpatial viewer work
- rich prompt UX is deferred to a future app or sister service
- WebXR/WebSpatial-style viewing is a future parallel viewer track, not Phase 1 implementation
- local SHARP bootstrap happens now
- architecture document remains canonical
- `third_party/ml-sharp` is a pinned checkout, not a submodule, in this phase
- viewer launch is optional
- preview video is optional on Apple Silicon
- real RTX, FLUX, and TRELLIS work is deferred
