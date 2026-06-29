# Claude Code Docker

Run [Claude Code](https://claude.ai/code) in an isolated Docker container. The **base image** includes Claude Code, MCP servers, Podman, and common dev tools. Extend it with a single `FROM` to add your project's build tools.

## Architecture

```
┌─────────────────────────────────────┐
│  claude-code-base                   │
│  Claude Code CLI, Node 22, Podman,  │
│  Playwright, MCP servers, uv/uvx,   │
│  Python 3, git-delta, fzf, ripgrep  │
└──────────────┬──────────────────────┘
               │ FROM claude-code-base
┌──────────────▼──────────────────────┐
│  Your project image                 │
│  Java, Gradle, .NET, Go, Rust, …   │
│  whatever your project needs        │
└─────────────────────────────────────┘
```

## What's in the base image

| Component           | Details                                 |
|---------------------|-----------------------------------------|
| Claude Code CLI     | Latest (native installer)               |
| Node.js             | 22 (Debian Bookworm)                    |
| Podman              | Rootless, for Testcontainers / infra    |
| Playwright/Chromium | Headless browser automation             |
| Python 3 / uv / uvx | For MCP servers and scripting          |
| git, jq, ripgrep    | Common dev utilities                   |
| git-delta, fzf      | Enhanced CLI experience                |

### MCP Servers (pre-configured)

| Server              | Purpose                                |
|---------------------|----------------------------------------|
| context7            | Library/framework documentation lookup |
| serena              | Semantic code analysis                 |
| sequential-thinking | Structured reasoning                   |
| playwright          | Headless browser automation            |

## Prerequisites

- **Docker** or **Podman** (with Compose)
- A **Claude account** — either a Pro/Team subscription (OAuth) or an [Anthropic API key](https://console.anthropic.com/)

## Quick start

```bash
# 1. Build the base image (once, or after updating)
podman-compose --profile build build base
# or: docker compose --profile build build base

# 2. Build the project image
podman-compose build claude
# or: docker compose build claude

# 3. Run
podman-compose run --rm claude
# or: docker compose run --rm claude
```

Or rebuild both images in one step with the helper script:

```bash
./rebuild.sh             # rebuild base + project image
./rebuild.sh --no-cache  # clean rebuild, ignoring the layer cache
./rebuild.sh --base      # rebuild only the base image
./rebuild.sh --project   # rebuild only the project image
```

The base image's Node version defaults to 22. Override it per team/project by
setting `NODE_VERSION` when building the base:

```bash
NODE_VERSION=20 podman-compose --profile build build base
# or directly: podman build --build-arg NODE_VERSION=20 -f Dockerfile.base .
```

On the first start you'll be prompted to authenticate (see [Authentication](#authentication)).

### Verifying the image

After a build, smoke-test that every tool the Dockerfiles install is present and at the expected version:

```bash
./test.sh           # test the project image (Java, Maven, .NET, …)
./test.sh base      # test the base image only
```

The script pipes `container/checks.sh` into the container, which prints a `✓ / ! / ✗` report with a pass/warn/fail summary (exit code non-zero on failure). Expected versions live at the top of `container/checks.sh` — keep them in sync when bumping a pin in a Dockerfile.

The same `checks.sh` is baked into the image as the **`test-claude-docker` skill**, so Claude Code running *inside* the container can self-check its environment — just ask it to "test the container" or invoke the skill.

## Extending the base image

Create a `Dockerfile` in your project that starts from the base:

```dockerfile
FROM claude-code-base

# Example: Java project
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source ~/.sdkman/bin/sdkman-init.sh \
    && sdk install java 21.0.10-amzn \
    && sdk install gradle 9.4.1"
ENV SDKMAN_DIR=/home/claude/.sdkman
ENV PATH="${SDKMAN_DIR}/candidates/java/current/bin:${SDKMAN_DIR}/candidates/gradle/current/bin:${PATH}"
```

```dockerfile
FROM claude-code-base

# Example: Python project
RUN pip install poetry
```

```dockerfile
FROM claude-code-base

# Example: Go project
RUN sudo apt-get update && sudo apt-get install -y golang-go \
    && sudo rm -rf /var/lib/apt/lists/*
```

The included `Dockerfile` is a working example for a Java/.NET project — use it as a starting point or replace it entirely.

## Shortcut: `claude-docker` command

Link the wrapper script to a directory in your PATH:

```bash
ln -s /path/to/claude-docker/claude-docker.sh ~/bin/claude-docker
```

Then use it like the native `claude` command — the current directory is automatically mounted as the workspace:

```bash
cd ~/my-project
claude-docker
```

## Authentication

Two options — choose one:

### Option A: OAuth login (Pro/Team subscription)

Just start the container. If not yet logged in, it will prompt you with a URL to open in your browser. The login is persisted in the `claude-data` volume — you only need to do this once.

### Option B: API key

Add your key to `.env`:

```bash
cp .env.example .env
# Edit .env and set ANTHROPIC_API_KEY
```

Or pass it directly:

```bash
ANTHROPIC_API_KEY=sk-ant-xxx claude-docker
```

## Usage

### Interactive session

```bash
claude-docker
```

### One-shot prompt

```bash
claude-docker -p "explain this project"
claude-docker -p "find bugs" --output-format json
```

### Shell access

```bash
claude-docker bash
```

### Run a command

```bash
claude-docker java --version
claude-docker gradle build
```

Arguments starting with `-` are passed as flags to Claude Code. Other arguments are executed as standalone commands.

## Testcontainers / nested containers

The base image includes a rootless Podman daemon for running containers inside the container. Testcontainers and `podman-compose` work out of the box.

- `DOCKER_HOST` is pre-configured to point to the Podman socket
- `TESTCONTAINERS_RYUK_DISABLED=true` is set (Ryuk is incompatible with rootless Podman)
- The container runs with `privileged: true` — on macOS this is safe because Podman runs inside a Linux VM

No host Docker socket is mounted. All nested containers are fully isolated.

## Memory sharing

When using the `claude-docker` wrapper script, Claude Code's project memory is shared between the container and your native Claude Code installation. Memories saved in the container are visible on the host and vice versa.

When using `docker compose` directly (without the wrapper), memory is stored in a separate Docker volume.

## File structure

```
claude-docker/
├── Dockerfile.base        # Base image: Node, Podman, Claude Code, MCP servers, Playwright, uv
├── Dockerfile             # Project image example: Java, Gradle, Maven, .NET (extend from base)
├── docker-compose.yml     # Service definitions with volume mounts
├── claude-docker.sh       # Wrapper script for CLI usage
├── rebuild.sh             # Helper script to rebuild the base + project images
├── test.sh                # Smoke-test: verify installed tools + versions in the image
├── container/
│   ├── claude-config.json                # Claude Code config: MCP servers, onboarding, workspace trust
│   ├── claude-container-instructions.md  # Instructions for Claude Code inside the container
│   ├── statusline-command.sh             # statusLine script (wired into settings.json at startup)
│   ├── checks.sh                         # Environment checks (run by test.sh and the in-container skill)
│   ├── skills/                           # Skills baked into the image (e.g. test-claude-docker)
│   └── entrypoint.sh                    # Podman socket, auth check, settings init, argument routing
├── CLAUDE.md              # Instructions for developing this repo
├── .env.example           # Template for environment variables
└── README.md
```

## Configuration

### HOST_UID

The container user `claude` is created with the same UID as your host user (default: 501, macOS default). This ensures mounted workspace files are read/writable without permission issues.

If your UID differs:

```bash
HOST_UID=$(id -u) podman-compose --profile build build base
HOST_UID=$(id -u) podman-compose build claude
```

### Persistent data

The `claude-data` Docker volume persists `~/.claude` between container runs (OAuth credentials, conversation history, settings).

To reset everything:

```bash
podman-compose down -v
```

### MCP servers

Edit `container/claude-config.json` and rebuild:

```bash
./rebuild.sh
```

## Troubleshooting

### Not authenticated

Run `claude login` inside the container (OAuth), or set `ANTHROPIC_API_KEY` in `.env`.

### MCP servers not connecting

Rebuild without cache:

```bash
./rebuild.sh --no-cache
```

### Testcontainers can't find Docker

The Podman socket is started automatically by the entrypoint. Verify with:

```bash
podman info
```

## License

MIT
