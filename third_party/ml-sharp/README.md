# ml-sharp

This directory manages the pinned Apple `ml-sharp` checkout used by the Phase 1 local SHARP path.

## Policy

- keep upstream source isolated under `third_party/`
- pin to an explicit revision in `VERSION`
- manage updates through documented bootstrap steps
- avoid mixing local project code with vendored upstream files

The canonical architecture currently assumes `ml-sharp` is the MVP reconstruction backend.

## Layout

- `VERSION`: pinned upstream `apple/ml-sharp` commit
- `bootstrap-macos.sh`: creates the local Conda environment and installs upstream dependencies
- `run-predict.sh`: wrapper used by the Swift CLI to run `sharp predict`
- `upstream/`: ignored pinned checkout created by `bootstrap-macos.sh`

## Bootstrap

```sh
third_party/ml-sharp/bootstrap-macos.sh
```

Defaults:
- Conda environment: `prompt-to-ply-sharp`
- Python: `3.13`
- Upstream checkout: `third_party/ml-sharp/upstream`

The bootstrap script installs Miniforge with Homebrew only when `conda` is missing.

## Prediction Wrapper

```sh
third_party/ml-sharp/run-predict.sh <input-image> <output-dir> <log-path>
```

The wrapper stages one selected still into the directory input shape expected by upstream `sharp predict`, writes logs to the caller-provided path, and returns non-zero on failure.

`preview.mp4` is not required for Apple Silicon success because upstream rendering with `--render` is CUDA-only.
