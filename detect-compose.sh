#!/usr/bin/env bash
#
# Sets COMPOSE to the first available compose command, in order of preference:
#   1. podman compose      (built-in podman subcommand, newer podman)
#   2. podman-compose      (standalone podman-compose binary)
#   3. docker compose      (docker compose v2 plugin)
#   4. docker-compose      (legacy docker-compose v1 binary)
# Subcommand forms are probed with `version` because `command -v` only finds
# standalone binaries, not subcommands.
#
# Source this file (not execute) so COMPOSE is set in the caller:
#   source "$(dirname "$(readlink -f "$0")")/detect-compose.sh"

if podman compose version &>/dev/null; then
  COMPOSE="podman compose"
elif command -v podman-compose &>/dev/null; then
  COMPOSE="podman-compose"
elif docker compose version &>/dev/null; then
  COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  echo "No compose command found (podman compose, podman-compose, docker compose, docker-compose)." >&2
  exit 1
fi
