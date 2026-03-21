# viewer-interop

This package is reserved for viewer-launch and compatibility helpers.

## Planned Responsibilities

- viewer compatibility versioning
- local viewer discovery
- launch payload generation
- non-fatal viewer failure classification

Viewer interop must remain downstream of bundle success. Viewer failures cannot invalidate a successful reconstruction job.
