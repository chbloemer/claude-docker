#!/usr/bin/env bash
#
# Smoke-test the claude-docker image from the host: verify every tool the
# Dockerfiles install is present and at the expected version.
#
# Usage:
#   ./test.sh              # test the project image (service "claude")
#   ./test.sh base         # test the base image only (service "base")
#
# It pipes container/checks.sh into a fresh container and runs it there. The
# image entrypoint is bypassed (--entrypoint bash) so no OAuth prompt or
# Podman-socket startup interferes. The same checks.sh is baked into the image
# and exposed inside the container as the "test-claude-docker" skill.

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

SERVICE="${1:-claude}"
export WORKSPACE_PATH="${WORKSPACE_PATH:-.}"

# Sets COMPOSE to the first available compose command.
source "$(dirname "$(readlink -f "$0")")/detect-compose.sh"

# The base service has profile "build" — enable it so it's runnable.
PROFILE=()
[ "$SERVICE" = "base" ] && PROFILE=(--profile build)

echo "==> Running checks inside service '$SERVICE' ($COMPOSE)..."
exec $COMPOSE "${PROFILE[@]}" run --rm -T --entrypoint bash "$SERVICE" -s < container/checks.sh
