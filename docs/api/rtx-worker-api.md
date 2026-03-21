# RTX Worker API

This document describes the MVP worker API that supports still generation and asset retrieval.

## Source Of Truth

- machine-readable contract: `packages/contracts/rtx-worker.openapi.yaml`
- architecture reference: `docs/architecture/ARCHITECTURE-v2.md`

## Endpoints

### `POST /v1/stills`

Creates a still-generation job on the worker.

Expected inputs:
- `prompt`
- `count`
- `backend`
- optional `resolution`
- optional `styleHints`
- optional `seed`

Expected behavior:
- accept the request and create a generation job
- expose job progress through `GET /v1/jobs/{id}`
- keep candidate assets retrievable through `GET /v1/assets/{jobId}/{name}`

### `GET /v1/jobs/{id}`

Returns the current worker-side status for a still-generation job.

MVP worker statuses:
- `created`
- `generating_stills`
- `stills_ready`
- `generation_failed`

When stills are ready, the response should include candidate asset metadata sufficient for the macOS app to render choices and fetch the image files.

### `GET /v1/assets/{jobId}/{name}`

Returns the raw asset content for a generated candidate or related worker artifact.

## API Notes

- This API is intentionally narrower than the full macOS control-plane state machine.
- `POST /v1/orbit-set` is intentionally excluded from the MVP API.
- The worker may add preprocessing or richer artifact endpoints later, but they must not alter the MVP contract.
