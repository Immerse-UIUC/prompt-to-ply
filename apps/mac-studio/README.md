# mac-studio

This directory will hold the macOS control-plane application.

## Responsibilities

- prompt entry by text and dictation
- still-generation orchestration
- candidate selection UI
- selected-still QC
- local `ml-sharp` execution
- bundle writing, provenance capture, and retries
- optional viewer launch
- visionOS pairing and delivery coordination

## First Implementation Targets

- define the job state machine in code
- model the bundle manifest and artifact paths
- add `ml-sharp` invocation and logging wrappers
- add a local storage layout for jobs and bundles
