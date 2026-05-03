# job-core

This package contains the core job model and local validation primitives shared by the macOS control plane, tests, and later clients.

## Responsibilities

- job state definitions
- transition rules
- bundle manifest serialization
- artifact path conventions
- image, panorama, and `.ply` validation helpers
- contact-sheet writing for local desktop review

The package should stay independent from UI and network transport details.

## Local Commands

```sh
swift test
```
