# ml-sharp

This directory is reserved for a pinned checkout or submodule of Apple's `ml-sharp`.

## Policy

- keep upstream source isolated under `third_party/`
- pin to an explicit revision
- manage updates through documented bootstrap steps
- avoid mixing local project code with vendored upstream files

The canonical architecture currently assumes `ml-sharp` is the MVP reconstruction backend.
