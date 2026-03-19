# Prompt-to-PLY Pipeline (v2 Architecture)

## Overview

This document is the canonical architecture and implementation spec for the Prompt-to-PLY MVP. It supersedes `Architecture-v1.md` for current product and engineering decisions.

The system converts **text or speech prompts into 3D Gaussian splats (`.ply`)** using Apple's `ml-sharp`, with a macOS-first orchestration layer and a later visionOS client.

The canonical MVP pipeline is:

> **prompt -> still images -> user selects one -> ml-sharp -> .ply -> viewer**

This architecture treats `ml-sharp` as a **single-image reconstruction backend** for MVP and explicitly avoids requiring synthetic multi-view inputs.

## Design Principles

- macOS-first orchestration and system of record
- Single-image SHARP pipeline for MVP
- Reproducibility via bundles, logs, and provenance
- Pluggable image-generation and reconstruction backends
- Viewer decoupled from pipeline success
- Vision Pro as a thin client coordinated by the Mac

## System Architecture

### Control Plane (macOS App)

The macOS app is the authoritative system.

Responsibilities:
- Prompt entry by text and dictation
- Image generation orchestration
- Candidate selection UI
- Job lifecycle and state machine ownership
- Selected-still QC
- `ml-sharp` execution
- Artifact storage and bundle writing
- Provenance capture and retry control
- Viewer launch as an optional post-processing step
- Vision Pro pairing, delivery, and job synchronization

### Worker Plane (RTX Service)

The RTX worker is optional for MVP but recommended for GPU-backed workloads.

Responsibilities:
- Local image generation with FLUX
- Hosting asynchronous generation jobs and generated assets
- Optional preprocessing and preview offload
- Future experimental reconstruction or image-to-3D backends such as TRELLIS

### Viewer Plane

- macOS: MetalSplatter or another compatible `.ply` viewer
- visionOS: embedded or forked MetalSplatter-derived viewer

Viewer support is a convenience feature. Pipeline success is defined before viewer launch.

### Repository Layout

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
```

`/third_party/ml-sharp` should be managed as a pinned submodule or pinned external checkout handled by bootstrap scripts.

## Core Pipeline

### MVP Flow

1. User enters or dictates a prompt on macOS.
2. The system generates 4 still candidates at the configured target resolution.
3. The user selects 1 candidate.
4. The system runs selected-still QC.
5. The macOS app invokes `ml-sharp` on the selected still.
6. The system produces `output.ply` and any available preview artifacts.
7. The macOS app writes the output bundle, logs, and provenance.
8. The system optionally opens the result in a viewer.
9. In the later visionOS flow, the bundle is transferred from the Mac to the headset and opened automatically.

### Selected-Still QC

Selected-still QC is part of the canonical MVP flow.

Minimum QC checks:
- image file exists and is readable
- image dimensions are non-zero and supported by the configured `ml-sharp` invocation
- image is not obviously corrupted
- image format is supported by the ingest path
- provenance records the chosen candidate, backend, and seed when available

Rejected stills must fail before reconstruction starts and transition the job into `qc_failed`.

## State Machine

```text
created
-> generating_stills
-> stills_ready
-> candidate_selected
-> selected_still_qc
-> reconstruction_running
-> reconstruction_succeeded
-> bundle_written
-> viewer_ready
-> completed
```

Error states:

```text
generation_failed
qc_failed
reconstruction_failed
bundle_failed
viewer_failed
transfer_failed
```

The macOS app is responsible for owning state transitions, retry policy, and persisted job metadata.

## Backends

### Still Generation

Cloud default:
- Google Gemini image generation

Local default:
- FLUX.1-dev on the RTX worker

### Reconstruction Backend

Primary MVP backend:
- Apple `ml-sharp`

Future experimental backends:
- TRELLIS
- other image-to-3D or reconstruction systems that can emit compatible artifacts

### Backend Policy

- MVP contracts must assume single-image `ml-sharp`.
- Additional backends must plug into the same job lifecycle and bundle contract.
- Experimental backends must not change the MVP success boundary or required API surface.

## Public Interfaces and Contracts

### Core Types

- `GenerationJob(id, prompt, inputSource, stillBackend, status, selectedCandidateIndex, artifacts, provenance)`
- `StillCandidate(index, seed, backend, imageURL, thumbnailURL, qcReport)`
- `SharpResult(plyURL, previewImageURL?, previewVideoURL?, logURL, durationMs)`
- `BundleManifest(jobId, prompt, selectedStill, sharpResult, provenance, viewerCompatibilityVersion)`

Recommended semantics:
- `GenerationJob.status` must map directly to the state machine in this document.
- `GenerationJob.artifacts` must include candidate, selected, output, log, QC, and provenance locations.
- `StillCandidate.qcReport` may be empty before selection-time QC, but the field should exist for consistent serialization.
- `SharpResult.previewImageURL` and `SharpResult.previewVideoURL` are optional because preview generation depends on environment and backend.
- `BundleManifest` is the canonical persisted summary of a completed or partially completed job bundle.

### macOS-Side Interfaces

- `StillGenerator.generate(prompt, count, styleHints)`
- `StillQC.evaluate(selectedStillURL, prompt)`
- `SharpExecutor.run(selectedStillURL)`
- `BundleWriter.write(jobArtifacts)`
- `AssetPublisher.publish(bundleURL, target)`

Interface expectations:
- `StillGenerator.generate` returns candidate metadata including backend identity and seed when available.
- `StillQC.evaluate` returns a machine-readable pass/fail result plus reasons suitable for logs and UI.
- `SharpExecutor.run` returns a `SharpResult` plus execution logs and exit status.
- `BundleWriter.write` is responsible for deterministic bundle layout and manifest creation.
- `AssetPublisher.publish` handles post-bundle delivery targets such as visionOS clients or local viewer interop.

### RTX Worker API

MVP-required endpoints:
- `POST /v1/stills`
- `GET /v1/jobs/{id}`
- `GET /v1/assets/{jobId}/{name}`

Contract notes:
- `POST /v1/stills` may be synchronous or asynchronous, but the job model exposed to macOS must be stable.
- `GET /v1/jobs/{id}` must expose terminal success and failure states for generation work.
- `GET /v1/assets/{jobId}/{name}` must provide access to generated candidate artifacts and related metadata.
- Worker-side preprocessing endpoints may be added later, but they are not required for MVP.

Not part of the canonical MVP API:
- `POST /v1/orbit-set`

### Bundle Contract

Every successful job must emit:
- a valid `.ply`
- a manifest
- execution logs
- provenance metadata

Viewer assets and previews are optional conveniences, not the definition of success.

## Bundle Layout

```text
/job-<id>/
  manifest.json
  prompt.txt
  /candidates/
    candidate-0.png
    candidate-1.png
    candidate-2.png
    candidate-3.png
  /selected/
    selected.png
  /output/
    output.ply
    preview.png
    preview.mp4
  /logs/
    generation.log
    sharp.log
  /qc/
    selected-still-qc.json
  /provenance/
    generation.json
    reconstruction.json
```

Bundle rules:
- `manifest.json` must be present for all completed bundles.
- `output/output.ply` is required for success.
- `output/preview.png` is recommended but optional.
- `output/preview.mp4` is optional and may be absent on Apple Silicon-only runs.
- Partial or failed jobs should preserve whatever logs, QC, and provenance were produced before failure.

## Local Network Transport

- Bonjour advertisement on `_splatpipe._tcp`
- One-time 6-digit pairing code on first connect
- WebSocket for control, status, and event streaming
- HTTP for artifact transfer

Transport requirements:
- Vision Pro talks only to the Mac control plane.
- The Mac talks to cloud services, the RTX worker, and local `ml-sharp`.
- Pairing credentials must be persisted and revocable.
- Interrupted artifact transfers must surface a recoverable `transfer_failed` state.

## Tests and Acceptance Scenarios

### Unit Tests

- job state transitions
- manifest serialization and deserialization
- backend selection logic
- provenance capture
- viewer-failure classification
- selected-still QC rules
- pairing-token validation

### Integration Tests

- mocked Google Gemini still generation
- fake RTX worker responses for generation jobs and asset fetches
- real `ml-sharp` invocation on selected stills
- preview artifact optionality on Apple Silicon versus CUDA environments
- MetalSplatter compatibility checks for emitted `.ply`

### End-to-End Tests

- macOS typed prompt -> 4 stills -> choose 1 -> selected-still QC -> `ml-sharp` -> bundle -> optional viewer launch
- macOS dictated prompt -> 4 stills -> choose 1 -> `ml-sharp` -> bundle
- visionOS pairing and delivery path
- successful job where viewer launch fails but the bundle remains valid

### Failure Scenarios

- RTX worker offline
- cloud timeout
- `ml-sharp` missing or misconfigured
- selected still fails QC
- bundle write failure
- viewer not installed on macOS
- interrupted LAN transfer

### MVP Acceptance Criteria

- A user can complete the macOS flow without touching Terminal.
- Every successful job leaves a reusable output bundle plus a valid `.ply`.
- Viewer failures do not invalidate job success.
- Provenance and logs are preserved for both successful and failed jobs.

## Milestones

### Milestone 0: Feasibility Harness

- Create a fixed suite of 10 tabletop-vignette prompts plus 2 captured-image baselines.
- Validate the full path: still generation, candidate selection, selected-still QC, `ml-sharp`, bundle writing, and MetalSplatter viewing.
- Pass gate: at least 7/10 generated jobs complete without manual file surgery, and at least 5/10 are visually acceptable in MetalSplatter.
- If this fails, generated input stays experimental and captured-image input remains the primary debug path.

### Milestone 1: macOS MVP

- Build a SwiftUI macOS app with typed prompt entry and a native dictation button.
- Generate 4 candidate stills at `1024x1024`.
- Support two still backends from day one:
  - Google image generation
  - local RTX generation via FLUX.1-dev
- Run selected-still QC before reconstruction.
- Run `ml-sharp` locally on the Apple Silicon Mac, package the result bundle, and open the `.ply` in MetalSplatter if installed.
- Manual Vision Pro handoff is acceptable in this milestone.

### Milestone 2: visionOS Client and Automatic Delivery

- Build a visionOS SwiftUI app that pairs to the Mac over the local network.
- The headset app handles speech and text prompt entry, shows the 4 still candidates, lets the user choose one, displays job status, downloads the finished bundle, and opens it automatically.
- Use the Mac as the control hub: Vision Pro talks only to the Mac; the Mac talks to cloud services, the RTX worker, and `ml-sharp`.
- Replace third-party viewer handoff on Vision Pro by embedding or forking the MetalSplatter viewer code.
- Keep `.ply` as the canonical stored artifact.

### Post-MVP

- Improve local-only generative quality and reduce dependence on cloud still generation.
- Add automatic candidate scoring and prompt refinement loops.
- Add multi-PLY composition as a separate scene-assembly feature.
- Attempt room-fragment scenes only after tabletop-vignette quality is stable.
- Evaluate experimental reconstruction pipelines without changing the canonical MVP contract.

## Assumptions and Defaults

- `ARCHITECTURE-v2.md` is the canonical architecture and implementation spec.
- MVP uses single-image `ml-sharp`, not synthetic multiview reconstruction.
- The macOS app is the system of record for jobs, files, logs, and retries.
- Apple Silicon Mac hardware is available for `ml-sharp`.
- An RTX worker is optional for MVP but supported for GPU-backed still generation and auxiliary tasks.
- Generated-content scope is tabletop vignettes, not room corners.
- Google Gemini is the default cloud still backend.
- FLUX.1-dev is the default local still backend.
- Viewer launch is optional convenience, not part of the success boundary.
- TRELLIS remains future and experimental and must not shape MVP contracts.

## References and External Dependencies

- [apple/ml-sharp](https://github.com/apple/ml-sharp): canonical MVP reconstruction backend
- [MetalSplatter](https://github.com/scier/MetalSplatter): reference viewer for macOS MVP and the basis for future viewer interop
- [Google Gemini image generation docs](https://ai.google.dev/gemini-api/docs/image-generation): default cloud still-generation reference
- [FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev): default local still-generation reference
- [TRELLIS](https://github.com/microsoft/TRELLIS): future experimental reconstruction or image-to-3D path only

Custom orchestration is justified because there is no turnkey end-to-end prompt -> `ml-sharp` -> automatic Vision Pro delivery pipeline. Existing apps such as [PhotoSplat3D](https://www.photosplat3d.com/) and [Spatial 3D Studio](https://www.spatial3dstudio.com/) demonstrate related viewer experiences, but they do not replace the orchestration and artifact-management requirements defined here.

## v2.1 Corrections and Clarifications

### SHARP Output Expectations

This system does not perform full 3D reconstruction.

Apple `ml-sharp` produces a single-image Gaussian splat representation that supports:

- limited viewpoint changes
- small camera translations
- parallax-like motion near the original viewpoint

It does not guarantee:

- full geometric consistency
- occluded surface recovery
- walk-around or 360-degree scene fidelity

All product and UX expectations should reflect this constraint.

### Preview Artifact Policy

Preview artifacts are optional and backend-dependent.

- `ml-sharp` prediction works on CPU, CUDA, and MPS
- `ml-sharp --render` currently requires CUDA

Implications:

- macOS Apple Silicon runs may not produce `preview.mp4`
- preview generation may be omitted
- preview generation may be replaced with a static preview image
- preview generation may be offloaded to the RTX worker

Updated output contract:

```text
/output/
  output.ply
  preview.png
  preview.mp4
```

`preview.png` is recommended but optional. `preview.mp4` is optional and CUDA-dependent.

### Success Boundary Definition

The pipeline defines success at:

> **bundle_written**

A job is considered successful if:

- a valid `.ply` is generated
- a complete bundle is written
- provenance and logs are preserved

Viewer launch is not part of the success criteria.

Viewer-related failures:

- do not invalidate the job
- are treated as post-processing side effects

### Content Scope Constraint (MVP)

MVP generation is explicitly constrained to:

> **tabletop vignette scenes**

Characteristics:

- single dominant subject
- limited spatial extent
- minimal occlusion ambiguity
- controlled composition

Out of scope:

- room-scale scenes
- architectural interiors
- multi-room environments

### Camera Model Assumption

Generated still images may lack EXIF metadata.

`ml-sharp` internally falls back to a default focal length of about 30mm when metadata is absent.

Implications:

- generated images are valid inputs without modification
- no camera calibration step is required for MVP

Provenance should record:

```json
{
  "camera_model": "assumed",
  "focal_length": "30mm_default"
}
```

### Output Variability and Input Sensitivity

The quality of SHARP outputs is highly dependent on the selected still image.

Factors that influence output quality include:

- subject clarity and separation from background
- lighting consistency
- occlusion ambiguity
- scene complexity
- presence of text or flat textures

Implications:

- not all generated stills will produce usable splats
- candidate selection is a critical step in the pipeline
- multiple candidates should always be generated and reviewed

Future iterations may introduce:

- automatic candidate scoring
- heuristics for SHARP suitability
- prompt refinement loops

These are not part of the MVP, but should be considered expected extensions.

### Layered System Architecture

The system is intentionally structured as a set of separable layers:

```text
Prompt Layer
    ->
Image Generation Layer
    ->
Candidate Selection Layer
    ->
Reconstruction Layer (`ml-sharp`)
    ->
Bundle Layer
    ->
Viewer Layer (optional)
```

Each layer should:

- expose clear inputs and outputs
- be independently replaceable
- avoid leaking implementation details across boundaries

This enables:

- swapping image-generation backends
- adding new reconstruction methods
- running headless pipelines
- supporting multiple viewer targets

The reconstruction layer is the only component that produces the canonical `.ply` artifact in MVP.

## Future Experimental Paths

The following items are explicitly out of the canonical MVP contract:

- orbit synthesis as a required stage
- 16 rendered views as a required reconstruction input contract
- orbit QC as the primary reconstruction gate
- `POST /v1/orbit-set` as an MVP-required API

These ideas may still be explored as future experimental paths:

- selected still -> image-to-3D or orbit synthesis -> multi-view reconstruction
- TRELLIS-backed preprocessing or reconstruction
- worker-generated preview renders and richer artifact derivatives

If experimental paths are implemented, they must be isolated behind optional backend flags and must not redefine MVP success, required bundle contents, or the default job lifecycle.
