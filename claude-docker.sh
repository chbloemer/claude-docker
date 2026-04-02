#!/bin/bash
# Runs Claude Code in Docker with the current directory as workspace.
# Usage: Link this to a directory in your PATH, e.g.:
#   ln -s /path/to/claude-docker/claude-docker.sh ~/bin/claude-docker
export WORKSPACE_PATH="$(pwd)"

# Compute host memory path so container and host share project memory.
# Claude Code uses the absolute path with slashes replaced by dashes as project key.
HOST_PROJECT_KEY="-$(echo "$WORKSPACE_PATH" | sed 's|^/||; s|/|-|g')"
HOST_MEMORY_DIR="$HOME/.claude/projects/$HOST_PROJECT_KEY/memory"
mkdir -p "$HOST_MEMORY_DIR"
export HOST_MEMORY_DIR

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if command -v podman-compose &>/dev/null; then
    cd "$SCRIPT_DIR" && exec podman-compose run --rm claude "$@"
else
    cd "$SCRIPT_DIR" && exec docker compose run --rm claude "$@"
fi
