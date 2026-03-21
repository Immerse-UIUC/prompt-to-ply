# job-core

This package is reserved for the core job model and pipeline state machine shared by the macOS app, tests, and later clients.

## Planned Responsibilities

- job state definitions
- transition rules
- retry policy primitives
- artifact path conventions
- serialization helpers for job metadata

The package should stay independent from UI and network transport details.
