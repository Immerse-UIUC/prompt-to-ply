#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${PROMPT_TO_PLY_SHARP_ENV:-prompt-to-ply-sharp}"
PYTHON_VERSION="${PROMPT_TO_PLY_SHARP_PYTHON:-3.13}"
REPO_URL="${PROMPT_TO_PLY_SHARP_REPO_URL:-https://github.com/apple/ml-sharp.git}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$SCRIPT_DIR/upstream"
PIN_FILE="$SCRIPT_DIR/VERSION"

log() {
  printf '[bootstrap-ml-sharp] %s\n' "$*"
}

fail() {
  printf '[bootstrap-ml-sharp] ERROR: %s\n' "$*" >&2
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

install_miniforge_if_needed() {
  if find_conda >/dev/null 2>&1; then
    return 0
  fi

  command -v brew >/dev/null 2>&1 || fail "conda is missing and Homebrew is not available. Install Miniforge manually, then rerun this script."

  log "conda not found; installing Miniforge with Homebrew"
  brew install --cask miniforge || brew install miniforge || fail "Homebrew Miniforge install failed"

  find_conda >/dev/null 2>&1 || fail "Miniforge installed, but conda was not found on PATH or in known Homebrew locations."
}

read_pin() {
  [[ -f "$PIN_FILE" ]] || fail "Missing pin file: $PIN_FILE"
  tr -d '[:space:]' < "$PIN_FILE"
}

ensure_upstream_checkout() {
  local pin="$1"

  if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
    log "cloning $REPO_URL into $UPSTREAM_DIR"
    git clone "$REPO_URL" "$UPSTREAM_DIR"
  else
    log "updating existing upstream checkout"
    git -C "$UPSTREAM_DIR" fetch --tags origin
  fi

  log "checking out pinned revision $pin"
  git -C "$UPSTREAM_DIR" checkout --detach "$pin"
}

ensure_env() {
  local conda_exe="$1"

  if "$conda_exe" env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    log "conda environment exists: $ENV_NAME"
  else
    log "creating conda environment $ENV_NAME with Python $PYTHON_VERSION"
    "$conda_exe" create -y -n "$ENV_NAME" "python=$PYTHON_VERSION" pip
  fi
}

install_python_dependencies() {
  local conda_exe="$1"

  log "installing upstream Python dependencies"
  "$conda_exe" run -n "$ENV_NAME" python -m pip install --upgrade pip
  (
    cd "$UPSTREAM_DIR"
    "$conda_exe" run -n "$ENV_NAME" python -m pip install -r requirements.txt
  )
}

smoke_check() {
  local conda_exe="$1"

  log "running sharp CLI smoke check"
  "$conda_exe" run -n "$ENV_NAME" sharp --help >/dev/null

  log "checking torch MPS availability"
  "$conda_exe" run -n "$ENV_NAME" python - <<'PY'
import torch
print(f"torch={torch.__version__}")
print(f"mps_available={torch.backends.mps.is_available()}")
PY
}

main() {
  install_miniforge_if_needed
  local conda_exe
  conda_exe="$(find_conda)" || fail "conda not found"
  local pin
  pin="$(read_pin)"

  log "using conda: $conda_exe"
  log "using environment: $ENV_NAME"
  log "using pin: $pin"

  ensure_upstream_checkout "$pin"
  ensure_env "$conda_exe"
  install_python_dependencies "$conda_exe"
  smoke_check "$conda_exe"

  log "bootstrap complete"
}

main "$@"
