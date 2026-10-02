#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
mkdir -p /tmp/movie-picture

FRONTEND_PORT="${FRONTEND_PORT:-43133}"
BACKEND_PORT="${BACKEND_PORT:-5000}"

start_backend() {
  if curl -sf "http://127.0.0.1:${BACKEND_PORT}/movies" >/dev/null 2>&1; then
    echo "backend already listening on :${BACKEND_PORT}"
    return
  fi
  tmux has-session -t backend 2>/dev/null && tmux kill-session -t backend
  tmux new-session -d -s backend "cd $(pwd)/starter/backend && FLASK_RUN_PORT=${BACKEND_PORT} pipenv run serve 2>&1 | tee /tmp/movie-picture/backend.log"
}

start_frontend() {
  if curl -sf "http://127.0.0.1:${FRONTEND_PORT}" >/dev/null 2>&1; then
    echo "frontend already listening on :${FRONTEND_PORT}"
    return
  fi
  tmux has-session -t frontend 2>/dev/null && tmux kill-session -t frontend
  tmux new-session -d -s frontend "cd $(pwd)/starter/frontend && HOST=0.0.0.0 PORT=${FRONTEND_PORT} BROWSER=none REACT_APP_MOVIE_API_URL=http://127.0.0.1:${BACKEND_PORT} npm start 2>&1 | tee /tmp/movie-picture/frontend.log"
}

start_backend
for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:${BACKEND_PORT}/movies" >/dev/null 2>&1; then
    echo "backend ready"
    break
  fi
  sleep 1
done

start_frontend
for _ in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:${FRONTEND_PORT}" >/dev/null 2>&1; then
    echo "frontend ready"
    break
  fi
  sleep 1
done
