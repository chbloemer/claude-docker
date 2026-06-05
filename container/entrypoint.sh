#!/bin/bash
set -e

# Ensure a directory exists and is writable (volumes may be created as root).
ensure_dir() {
    mkdir -p "$1"
    [ -w "$1" ] || sudo chown -R claude:claude "$1"
}

ensure_dir ~/.claude
ensure_dir ~/.claude/projects/-workspace/memory

# Mounting the memory volume at a nested path makes Podman auto-create the
# intermediate dirs (projects, -workspace) as root. Claude Code runs as
# `claude` and writes its session transcript into -workspace/<session>.jsonl,
# so those dirs must be claude-writable — otherwise no transcript is written
# and the statusLine can't compute context usage. chown non-recursively to
# avoid touching the bind-mounted memory/ contents.
for d in ~/.claude/projects ~/.claude/projects/-workspace; do
    [ -w "$d" ] || sudo chown claude:claude "$d"
done

# Ensure settings exist (volume starts empty).
# skipDangerousModePermissionPrompt is safe here because the container itself
# is the security boundary — there is no access to the host beyond /workspace.
if [ ! -f ~/.claude/settings.json ]; then
    cat > ~/.claude/settings.json <<'JSON'
{
  "skipDangerousModePermissionPrompt": true,
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
JSON
elif ! jq -e '.statusLine' ~/.claude/settings.json >/dev/null 2>&1; then
    # Settings already exist (persistent volume) but predate the statusLine —
    # add it without touching the user's other settings.
    tmp=$(mktemp)
    jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' \
        ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
fi

# Copy container-specific CLAUDE.md (updated on each start from image defaults)
cp /home/claude/.claude-defaults/CLAUDE.md ~/.claude/CLAUDE.md 2>/dev/null || true

# Copy statusLine script (updated on each start from image defaults)
cp /home/claude/.claude-defaults/statusline-command.sh ~/.claude/statusline-command.sh 2>/dev/null || true
chmod +x ~/.claude/statusline-command.sh 2>/dev/null || true

# Persist shell history across container restarts
export HISTFILE=/commandhistory/.bash_history
touch "$HISTFILE"

# Configure git-delta as git pager (once)
if ! git config --global core.pager >/dev/null 2>&1; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global merge.conflictstyle diff3
fi

# Start Podman socket for Testcontainers / docker-compose infra.
# Runs a rootless Podman daemon — isolated from the host, no socket sharing.
# XDG_RUNTIME_DIR and DOCKER_HOST are set in the Dockerfile so all child
# processes (including those spawned by Claude Code) inherit them.
if command -v podman &>/dev/null; then
    PODMAN_SOCK="${DOCKER_HOST#unix://}"
    sudo mkdir -p "$(dirname "$PODMAN_SOCK")"
    sudo chown claude:claude "$XDG_RUNTIME_DIR"
    podman system service --time=0 "unix://$PODMAN_SOCK" >/dev/null 2>&1 &
    # Symlink to standard Docker socket path so tools find it without config
    sudo ln -sf "$PODMAN_SOCK" /var/run/docker.sock
    # Wait for socket to be ready and verify it responds
    podman_ready=false
    for _ in {1..10}; do
        if [ -S "$PODMAN_SOCK" ] && podman info >/dev/null 2>&1; then
            podman_ready=true
            break
        fi
        sleep 1
    done
    # Warn (don't abort) — only Testcontainers / nested containers need this,
    # and a clear message here beats a cryptic failure deep in a test run.
    if [ "$podman_ready" != true ]; then
        echo "WARNING: Podman socket did not become ready within 10s." >&2
        echo "         Testcontainers and nested containers may not work. Check 'podman info'." >&2
    fi
fi

# Source SDKMAN if available (installed in project-specific images)
[ -f ~/.sdkman/bin/sdkman-init.sh ] && source ~/.sdkman/bin/sdkman-init.sh 2>/dev/null || true

# Auto-login if no API key and no existing credentials
if [ -z "$ANTHROPIC_API_KEY" ] && [ ! -f ~/.claude/.credentials.json ]; then
    echo "No API key set and not logged in. Starting OAuth login..."
    echo "A URL will be shown — open it in your browser to authenticate."
    echo ""
    claude login
fi

# --dangerously-skip-permissions is safe here: the container is isolated,
# /workspace is the only mounted host directory, and network access is
# limited to what Docker/Podman allows. The container IS the sandbox.
#
# Argument routing:
#   no args        → interactive Claude Code
#   args with "-"  → Claude Code flags (e.g., -p "prompt")
#   other args     → standalone command (e.g., bash, java --version)
if [ $# -eq 0 ]; then
    exec claude --dangerously-skip-permissions
elif [[ "$1" == -* ]]; then
    exec claude --dangerously-skip-permissions "$@"
else
    exec "$@"
fi
