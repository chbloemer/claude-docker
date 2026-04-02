# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Container Environment

You are running inside a Docker container. The container IS the security boundary — `/workspace` is the only host-mounted directory.

## Available Tools
- **Java 25** (Amazon Corretto, default) + **Java 21** available — both via SDKMAN (`sdk use java 21-amzn` / `sdk use java 25-amzn`)
- **Gradle 9.4.1** (via SDKMAN), **Maven**
- **.NET 8 SDK** (for NSwag API client generation)
- **Podman** (rootless, nested containers) — use `podman` instead of `docker`
- **podman-compose** — use instead of `docker-compose`
- **Node.js 22**, **npx** (postinstall scripts disabled globally for security; use `--ignore-scripts=false` for trusted packages)
- **Python 3**, **uv**, **uvx**
- **Git**, **jq**, **curl**, **ripgrep**, **fzf**, **git-delta**

## Container Runtime
- Podman socket runs at `$DOCKER_HOST` and is symlinked to `/var/run/docker.sock`
- Testcontainers works out of the box — do not set `DOCKER_HOST` manually
- `TESTCONTAINERS_RYUK_DISABLED=true` is set (required for rootless Podman)
- Use `podman` and `podman-compose` commands, not `docker` / `docker-compose`

## MCP Servers
- **context7** — library/framework documentation lookup
- **serena** — semantic code analysis (symbols, references, renaming)
- **sequential-thinking** — structured multi-step reasoning
- **playwright** — headless Chromium browser automation

## Working Directory
- `/workspace` is the mounted host project directory
- Files are owned by the host user (UID matching) — no permission issues

## Limitations
- No GUI, no desktop browser — Playwright runs headless only
- No host network access beyond what Podman allows

## Building This Container (from host)
```bash
podman-compose --profile build build base   # base image (once, or after updating)
podman-compose build claude                 # project image
podman-compose build --no-cache             # clean rebuild
```
