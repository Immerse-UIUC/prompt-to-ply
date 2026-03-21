# rtx-worker

This directory will hold the LAN-accessible GPU worker service.

## MVP Responsibilities

- generate still candidates
- expose job status for still-generation requests
- host generated assets for retrieval by the macOS control plane

## Future Responsibilities

- optional image preprocessing
- preview generation offload
- experimental reconstruction or image-to-3D backends such as TRELLIS

## Contract

The current worker API contract is defined in `packages/contracts/rtx-worker.openapi.yaml`.
