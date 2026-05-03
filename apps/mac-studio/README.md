# mac-studio

This directory holds the Phase 1 macOS control-plane Swift package.

The first implementation target is a CLI executable named `prompt-to-ply`. The SwiftUI macOS app remains a later layer on top of the same job and bundle primitives.

## Responsibilities

- prompt entry by text and dictation
- still-generation orchestration
- candidate selection UI
- selected-still QC
- local `ml-sharp` execution
- bundle writing, provenance capture, and retries
- optional viewer launch
- visionOS pairing and delivery coordination

## Implemented Slice

- `check-sharp-env`
- `run-captured`
- `run-reconstruction`
- `validate-bundle`
- `show-job`
- Phase 1 command-surface placeholders for cloud stills, panorama viewports, and candidate selection

## Next Implementation Targets

- add `ml-sharp` invocation and logging wrappers
- add OpenAI and Gemini still providers
- add panorama viewport extraction
- add Python worker-stub integration

## Local Commands

```sh
swift test
swift run prompt-to-ply check-sharp-env
swift run prompt-to-ply run-captured --prompt "tiny object" --input-image /path/to/image.png --output-root /tmp/prompt-to-ply-jobs
swift run prompt-to-ply run-reconstruction /tmp/prompt-to-ply-jobs/<job-id>
swift run prompt-to-ply validate-bundle /tmp/prompt-to-ply-jobs/<job-id>
swift run prompt-to-ply show-job /tmp/prompt-to-ply-jobs/<job-id>
```
