# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds a Docker container for running Claude Code in isolation. It uses a two-layer image architecture: a base image (`Dockerfile.base`) with common tools and a project-specific image (`Dockerfile`) that extends it.

## Building (from host)

```bash
podman-compose --profile build build base   # base image (once, or after updating)
podman-compose build claude                 # project image
podman-compose build --no-cache             # clean rebuild
```

## Key Files

- `Dockerfile.base` — base image: Node 22, Podman, Claude Code, MCP servers, Playwright, uv
- `Dockerfile` — project image example extending the base (Java, Gradle, Maven, .NET)
- `docker-compose.yml` — service definitions with volume mounts
- `claude-docker.sh` — wrapper script for CLI usage
- `rebuild.sh` — rebuild base + project images (`--no-cache`/`--base`/`--project`)
- `test.sh` — host-side smoke-test: pipes `container/checks.sh` into the image (`./test.sh` or `./test.sh base`)
- `container/` — files copied into the Docker image:
  - `claude-config.json` — Claude Code config: MCP servers, onboarding, workspace trust
  - `claude-container-instructions.md` — instructions for Claude Code inside the container (copied as `~/.claude/CLAUDE.md` at startup)
  - `statusline-command.sh` — statusLine script (copied to `~/.claude/` at startup, wired into `settings.json`)
  - `checks.sh` — environment checks (verify installed tools + pinned versions); single source run by both `test.sh` and the in-container skill. Expected versions are pinned at the top and must stay in sync with the Dockerfiles
  - `skills/` — skills baked into the image, copied to `~/.claude/skills/` at startup. `test-claude-docker` runs `checks.sh` so Claude Code inside the container can self-check
  - `entrypoint.sh` — Podman socket, auth check, settings init, argument routing

## Container Instructions

The file `container/claude-container-instructions.md` is what Claude Code sees when running inside the container. It is deliberately named differently to avoid being picked up by Claude Code on the host. The entrypoint copies it to `~/.claude/CLAUDE.md` on each container start.
