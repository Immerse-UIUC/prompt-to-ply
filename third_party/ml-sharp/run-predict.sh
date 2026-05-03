#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${PROMPT_TO_PLY_SHARP_ENV:-prompt-to-ply-sharp}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$SCRIPT_DIR/upstream"

usage() {
  cat >&2 <<'EOF'
Usage:
  third_party/ml-sharp/run-predict.sh <input-image> <output-dir> <log-path>

Runs the pinned upstream `sharp predict` CLI on a single selected still.
EOF
}

fail() {
  printf '[run-ml-sharp] ERROR: %s\n' "$*" >&2
  exit 1
}

find_conda() {
  if command -v conda >/dev/null 2>&1; then
    command -v conda
    return 0
  fi

  for candidate in \
    "$HOME/miniforge3/bin/conda" \
    "/opt/homebrew/bin/conda" \
    "/opt/homebrew/Caskroom/miniforge/base/bin/conda" \
    "/usr/local/bin/conda" \
    "/usr/local/Caskroom/miniforge/base/bin/conda"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

main() {
  if [[ $# -ne 3 ]]; then
    usage
    exit 64
  fi

  local input_image="$1"
  local output_dir="$2"
  local log_path="$3"

  [[ -f "$input_image" ]] || fail "input image does not exist: $input_image"
  [[ -d "$UPSTREAM_DIR" ]] || fail "missing upstream checkout: $UPSTREAM_DIR. Run bootstrap-macos.sh first."

  local conda_exe
  conda_exe="$(find_conda)" || fail "conda not found. Run bootstrap-macos.sh first."

  mkdir -p "$output_dir"
  mkdir -p "$(dirname "$log_path")"

  local staged_dir
  staged_dir="$(mktemp -d)"
  trap 'rm -rf "${staged_dir:-}"' EXIT

  local input_ext
  input_ext="${input_image##*.}"
  if [[ "$input_ext" == "$input_image" ]]; then
    input_ext="png"
  fi

  local staged_input="$staged_dir/selected-still.$input_ext"
  cp "$input_image" "$staged_input"

  {
    printf '[run-ml-sharp] started=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '[run-ml-sharp] input=%s\n' "$input_image"
    printf '[run-ml-sharp] staged_input=%s\n' "$staged_input"
    printf '[run-ml-sharp] output_dir=%s\n' "$output_dir"
    printf '[run-ml-sharp] env=%s\n' "$ENV_NAME"
    printf '[run-ml-sharp] upstream=%s\n' "$UPSTREAM_DIR"
  } > "$log_path"

  (
    cd "$UPSTREAM_DIR"
    PYTORCH_ENABLE_MPS_FALLBACK="${PYTORCH_ENABLE_MPS_FALLBACK:-1}" \
      "$conda_exe" run -n "$ENV_NAME" sharp predict -i "$staged_dir" -o "$output_dir"
  ) >> "$log_path" 2>&1

  printf '[run-ml-sharp] finished=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$log_path"
}

main "$@"
