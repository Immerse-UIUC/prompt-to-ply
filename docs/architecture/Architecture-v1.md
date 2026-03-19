# Prompt-to-PLY Pipeline Architecture v1

## Summary

- Build a greenfield system with a native macOS orchestrator, a LAN-accessible RTX worker, and a later visionOS client.
- Keep [apple/ml-sharp](https://github.com/apple/ml-sharp) as the canonical reconstruction step; it already turns an image folder or video into a `.ply`.
- Reuse [MetalSplatter](https://github.com/scier/MetalSplatter) for MVP viewing. Existing apps such as [PhotoSplat3D](https://www.photosplat3d.com/) and [Spatial 3D Studio](https://www.spatial3dstudio.com/) exist, but there does not appear to be a turnkey prompt -> `ml-sharp` -> automatic Vision Pro pipeline, so custom orchestration is justified.
- Critical constraint: `ml-sharp` needs a coherent multi-view set, not a single still. The generated-input branch should therefore be `prompt -> 4 still candidates -> user selects 1 -> synthesize orbit views -> quality gate -> ml-sharp -> .ply`.
- Implement "prompt to multiview" as `selected still -> image-to-3D/orbit synthesis -> 16 rendered views`, because that is the most practical way to get stable inputs for `ml-sharp` today.
- Initial generated-content target is tabletop vignette scenes only. Room-corner scenes are explicitly deferred.

## Milestones

### Milestone 0: Feasibility Harness

- Create a fixed suite of 10 tabletop-vignette prompts plus 2 captured-image baselines.
- Validate the full path: still generation, selected-still-to-orbit synthesis, `ml-sharp`, and open in MetalSplatter.
- Pass gate: at least 7/10 generated jobs complete without manual file surgery, and at least 5/10 are visually acceptable in MetalSplatter.
- If this fails, generated input stays experimental and captured-image input remains the debug path.

### Milestone 1: macOS MVP

- Build a SwiftUI macOS app with typed prompt entry and a native dictation button.
- Generate 4 candidate stills at `1024x1024`.
- Support two still backends from day one:
  - Google image generation via [Google AI image docs](https://ai.google.dev/gemini-api/docs/image-generation)
  - Local RTX generation via [FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev)
- After selection, send the chosen still and prompt to the RTX worker's orbit stage, implemented as image-to-3D with [TRELLIS](https://github.com/microsoft/TRELLIS) plus a deterministic 16-view orbit renderer.
- Reject empty, duplicate, or dimension-mismatched orbit frames before invoking `ml-sharp`.
- Run `ml-sharp` locally on the Apple Silicon Mac, package the result bundle, and open the `.ply` in MetalSplatter if installed.
- Manual Vision Pro handoff is acceptable in this milestone.

### Milestone 2: visionOS Client and Automatic Delivery

- Build a visionOS SwiftUI app that pairs to the Mac over the local network.
- The headset app handles speech/text prompt entry, shows the 4 still candidates, lets the user choose one, displays job status, downloads the finished bundle, and opens it automatically.
- Use the Mac as the control hub: Vision Pro talks only to the Mac; the Mac talks to cloud services, the RTX worker, and `ml-sharp`.
- Replace third-party viewer handoff on Vision Pro by embedding or forking the MetalSplatter viewer code.
- Keep `.ply` as the canonical stored artifact.

### Post-MVP

- Improve local-only generative quality and reduce dependence on cloud still generation.
- Add multi-PLY composition as a separate scene-assembly feature.
- Attempt room-fragment scenes only after tabletop-vignette quality is stable.

## Proposed Repository Layout

```text
/apps/mac-studio
/apps/visionos-client
/services/rtx-worker
/packages/contracts
/third_party/ml-sharp
```

`/third_party/ml-sharp` should be managed as a pinned submodule or pinned external checkout handled by bootstrap scripts.

## Core Flow

1. User enters a prompt by text or dictation on macOS.
2. The system generates 4 still candidates.
3. The user selects 1 still.
4. The selected still and prompt are sent to the RTX worker.
5. The RTX worker produces a 16-frame orbit set.
6. Orbit frames pass quality control checks.
7. macOS runs `ml-sharp` locally against the orbit set.
8. The system packages the output bundle.
9. The resulting `.ply` opens in MetalSplatter.
10. In the later visionOS version, the bundle is transferred to the headset over the local network and opened automatically.

## Public Interfaces and Contracts

### Core Types

- `GenerationJob(id, prompt, inputSource, stillBackend, orbitBackend, status, selectedCandidateIndex, artifacts)`
- `StillCandidate(index, seed, backend, imageURL, thumbnailURL)`
- `OrbitSet(frameCount, directoryURL, cameraPath, qcReport)`
- `SharpResult(plyURL, previewVideoURL, logURL, durationMs)`
- `BundleManifest(jobId, prompt, selectedStill, orbitSet, sharpResult, viewerCompatibilityVersion)`

### macOS-Side Protocols

- `StillGenerator.generate(prompt, count, styleHints)`
- `OrbitSynthesizer.buildOrbit(prompt, selectedStillURL)`
- `SharpExecutor.run(orbitDirectoryURL)`
- `AssetPublisher.publish(bundleURL, target)`

### RTX Worker API

- `POST /v1/stills`
- `POST /v1/orbit-set`
- `GET /v1/jobs/{id}`
- `GET /v1/assets/{jobId}/{name}`

### Local Network Transport

- Bonjour advertisement on `_splatpipe._tcp`
- One-time 6-digit pairing code on first connect
- WebSocket for control and status
- HTTP for artifact transfer

## Output Bundle Layout

```text
jobs/<jobId>/manifest.json
jobs/<jobId>/stills/*.png
jobs/<jobId>/orbit/*.png
jobs/<jobId>/sharp/output.ply
jobs/<jobId>/sharp/preview.mp4
jobs/<jobId>/logs/*.txt
```

## Tests and Acceptance Scenarios

### Unit Tests

- Job state transitions
- Manifest serialization
- Backend selection logic
- Pairing-token validation
- Orbit QC rules

### Integration Tests

- Mocked cloud still backend
- Fake RTX worker responses
- Real `ml-sharp` invocation on sample orbit sets
- MetalSplatter compatibility check on emitted `.ply`

### End-to-End Tests

- macOS flow: typed or dictated prompt -> 4 stills -> choose 1 -> orbit synthesis -> `ml-sharp` -> bundle -> open in MetalSplatter
- visionOS flow: pair headset -> speech prompt -> choose candidate -> receive bundle -> auto-open viewer

### Failure Scenarios

- RTX worker offline
- Cloud timeout
- `ml-sharp` environment missing
- Orbit QC failure
- Viewer not installed on macOS
- Interrupted LAN transfer

### MVP Acceptance Bar

- A user can complete the Mac flow without touching Terminal.
- Every successful job leaves a reusable output bundle plus a viewable `.ply`.

## Assumptions and Defaults

- Apple Silicon Mac is available for `ml-sharp`.
- A separate RTX worker is reachable on the same LAN.
- Generated-content scope is tabletop vignettes, not room corners.
- Google is the default cloud still backend.
- FLUX is the default local still backend.
- TRELLIS on the RTX worker is the default bridge from selected still to orbit views.
- The macOS app is the system of record for jobs, files, logs, and retries.
- Multi-PLY merging is out of MVP scope and should not shape the initial architecture.
