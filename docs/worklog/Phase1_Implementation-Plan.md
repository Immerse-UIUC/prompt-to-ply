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
- support Google Gemini still generation from macOS when credentials are available
- build a fixture-backed Python worker stub that matches the MVP worker contract
- avoid requiring RTX access for completion of the phase

## Scope

In scope:

- Apple Silicon SHARP bootstrap
- Swift CLI control plane
- captured-image baseline flow
- Google Gemini still generation flow
- bundle writing, QC, provenance, and logs
- Python FastAPI worker stub
- fixture assets and worker-stub integration
- runbooks and validation docs

Out of scope:

- SwiftUI app
- visionOS client
- real FLUX/TRELLIS execution
- CUDA-only preview rendering requirements
- real RTX deployment and scheduling
- multiview/orbit pipelines

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
- `select-candidate`
- `run-reconstruction`
- `validate-bundle`
- `show-job`

Command behavior:

- `check-sharp-env` verifies the local SHARP bootstrap and reports MPS readiness
- `run-captured` auto-selects the one captured candidate
- `generate-cloud-stills` writes a bundle at `stills_ready`
- `select-candidate` marks one candidate
- `run-reconstruction` runs QC, SHARP, and bundle writing
- `validate-bundle` checks bundle layout and manifest shape
- `show-job` prints manifest-driven state

CLI implementation defaults:

- default job root: `~/Library/Application Support/PromptToPLY/jobs/<job-id>/`
- allow `--output-root` override for all commands
- do not require interactivity
- if candidate selection is needed, it must happen through `--index` on `select-candidate`

## Track B1: Still Sources For The CLI

Implement three still-source paths behind one internal abstraction in the Swift CLI:

- `CapturedStillSource`
- `GeminiStillSource`
- `WorkerStillSource`

Behavior:

- `CapturedStillSource` writes one candidate and auto-selects it for baseline or debug runs
- `GeminiStillSource` generates four candidates using Google Gemini and stops at `stills_ready`
- `WorkerStillSource` talks to the Python worker stub over HTTP and mirrors the same still-generation lifecycle

Configuration:

- `GeminiStillSource` uses `GOOGLE_API_KEY`
- `WorkerStillSource` uses `PROMPT_TO_PLY_WORKER_BASE_URL`
- all three must produce candidate metadata that serializes into the same `BundleManifest`

Cloud behavior choice for this phase:

- captured-image baselines and cloud stills are both first-class
- captured-image path must work with zero external credentials
- cloud path is enabled only when `GOOGLE_API_KEY` is present
- if `GOOGLE_API_KEY` is absent, `generate-cloud-stills` should fail cleanly with a configuration error, not a crash

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

Success boundary:

- bundle success is reached at `bundle_written`
- viewer launch is post-processing only
- if viewer launch fails after a valid bundle is written, record `viewer_failed` but preserve the successful bundle artifacts and logs

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

- `generate-cloud-stills` remains direct Gemini
- add a separate CLI path such as `generate-worker-stills` for the worker stub
- the CLI polls `GET /v1/jobs/{id}` until terminal worker status
- the CLI downloads candidate assets from `GET /v1/assets/{jobId}/{name}`
- the CLI writes them into the canonical bundle layout and transitions to `stills_ready`

This is the bridge that proves the contract boundary before the real RTX worker exists.

## Public APIs, Interfaces, And Types

Swift domain types:

- `GenerationJob`
- `JobStatus`
- `StillCandidate`
- `SelectedStill`
- `QCReport`
- `SharpResult`
- `BundleManifest`
- `ArtifactLayout`
- `ProvenanceRecord`

Worker API:

- `POST /v1/stills`
- `GET /v1/jobs/{id}`
- `GET /v1/assets/{jobId}/{name}`

Environment variables:

- `GOOGLE_API_KEY`
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

## Testing And Validation

Unit tests:

- job state transitions
- illegal transitions
- manifest encode and decode shape
- QC rule coverage
- provenance defaults
- viewer-failure classification
- CLI argument parsing
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
- worker stub lifecycle and asset fetch
- bundle validation after local SHARP execution

Local SHARP integration:

- `check-sharp-env` succeeds after bootstrap
- one captured baseline image runs end-to-end on Apple Silicon and reaches `bundle_written`
- logs and provenance files are present after reconstruction
- missing SHARP environment produces `reconstruction_failed` with a readable error

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
- prompt -> worker stub stills -> selection -> SHARP -> bundle
- bundle success with viewer failure
- QC failure before reconstruction
- reconstruction failure after valid selection

Expanded end-to-end phrasing:

- captured baseline image -> auto-selected candidate -> QC -> SHARP -> bundle -> optional viewer launch
- prompt -> Gemini stills -> bundle at `stills_ready` -> explicit candidate selection -> SHARP -> bundle
- prompt -> worker stub stills -> bundle at `stills_ready` -> explicit candidate selection -> SHARP -> bundle
- bundle success followed by viewer launch failure
- reconstruction failure after a valid selected still
- QC failure before reconstruction starts

## Acceptance Criteria

- local `ml-sharp` bootstrap succeeds on Apple Silicon
- `ml-sharp` can run a real prediction path on this Apple Silicon Mac
- Swift CLI can complete a captured-image baseline to `bundle_written`
- Swift CLI can generate Gemini stills when `GOOGLE_API_KEY` is present
- Python worker stub is runnable locally
- Swift CLI can fetch stills from the worker stub and write them into the canonical bundle layout
- manifests, QC reports, logs, and provenance are preserved for success and failure
- nothing in this phase requires RTX hardware or a second worktree
- documentation exists for bootstrap, local runs, and fixture-backed worker use

## Failure Modes And Handling

- if Miniforge or bootstrap fails, stop the SHARP setup path and document exact remediation in the runbook
- if SHARP installs but MPS inference fails, keep the wrapper and mark local SHARP execution blocked while continuing with bundle and worker work
- if `GOOGLE_API_KEY` is missing, captured baselines remain the primary path and cloud generation is skipped cleanly
- if the local viewer app is missing, treat viewer launch as optional and non-blocking
- if worker fixtures are missing or invalid, fail deterministically with `generation_failed` and a clear error

Additional handling notes:

- if MetalSplatter is absent, viewer launch remains optional and must not block bundle success
- if Gemini credentials are absent, captured-image flow remains the primary path and cloud still generation is skipped, not blocking the phase

## Assumptions And Defaults

- single worktree
- Swift CLI for local control plane
- Python FastAPI for worker stub
- captured baselines and cloud stills both in scope
- local SHARP bootstrap happens now
- architecture document remains canonical
- `third_party/ml-sharp` is a pinned checkout, not a submodule, in this phase
- viewer launch is optional
- preview video is optional on Apple Silicon
- real RTX, FLUX, and TRELLIS work is deferred
