#!/usr/bin/env bash
#
# Rebuild the Claude Code container images.
#
# Rebuilds the base image (Dockerfile.base) and then the project image
# (Dockerfile) using podman-compose. Run this after changing any Dockerfile,
# the entrypoint, or the container config.
#
# Usage:
#   ./rebuild.sh            # rebuild base + project image
#   ./rebuild.sh --no-cache # clean rebuild, ignoring layer cache
#   ./rebuild.sh --base     # rebuild only the base image
#   ./rebuild.sh --project  # rebuild only the project image

set -euo pipefail

# Always run from the directory containing this script (the project root).
cd "$(dirname "$0")"

NO_CACHE=""
BUILD_BASE=true
BUILD_PROJECT=true

for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE="--no-cache" ;;
    --base)     BUILD_PROJECT=false ;;
    --project)  BUILD_BASE=false ;;
    -h|--help)
      grep '^#' "$0" | grep -v '!/usr/bin/env' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Try '$0 --help'." >&2
      exit 1
      ;;
  esac
done

if [ "$BUILD_BASE" = true ]; then
  echo "==> Building base image (claude-code-base)..."
  podman-compose --profile build build $NO_CACHE base
fi

if [ "$BUILD_PROJECT" = true ]; then
  echo "==> Building project image (claude)..."
  podman-compose build $NO_CACHE claude
fi

echo "==> Done."
