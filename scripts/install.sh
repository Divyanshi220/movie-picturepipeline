#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v python3.10 >/dev/null 2>&1; then
  uv python install 3.10
fi

sudo ln -sf "$(command -v python3.10)" /usr/local/bin/python3.10
if ! command -v pipenv >/dev/null 2>&1; then
  uv tool install pipenv
fi
if [[ -x "$HOME/.local/bin/pipenv" ]]; then
  sudo ln -sf "$HOME/.local/bin/pipenv" /usr/local/bin/pipenv
fi

PY310="$(readlink -f "$(command -v python3.10)")"

if [[ -d starter/backend ]]; then
  (cd starter/backend && pipenv --python "$PY310" install --dev)
fi

if [[ -d starter/frontend && -f starter/frontend/package-lock.json ]]; then
  if [[ -x starter/frontend/node_modules/.bin/react-scripts ]]; then
    echo "frontend node_modules present; skipping npm ci"
  else
    (cd starter/frontend && npm ci)
  fi
fi
