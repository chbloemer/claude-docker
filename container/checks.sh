#!/usr/bin/env bash
#
# claude-docker environment checks — runs INSIDE the container.
#
# Verifies every tool the Dockerfiles install is present and (for pinned tools)
# at the expected version, then prints a ✓ / ! / ✗ report with a summary.
# Exit code is non-zero if any check fails.
#
# Two ways this runs:
#   - From the host via ./test.sh (pipes this file into the container).
#   - Inside the container via the "test-claude-docker" skill (baked into the image).
#
# No `set -e` — we want every check to run even if an earlier one fails.

# ── Expected versions (keep in sync with the Dockerfiles) ────────────────────
EXPECT_NODE="${EXPECT_NODE:-v22}"   # override for non-default NODE_VERSION builds
EXPECT_DELTA="0.18.2"      # Dockerfile.base GIT_DELTA_VERSION
EXPECT_UV="0.11.19"        # Dockerfile.base UV_VERSION
EXPECT_JAVA="25.0.2"       # Dockerfile  sdk default java
EXPECT_JAVA_ALT="21.0.10"  # Dockerfile  second JDK
EXPECT_GRADLE="9.4.1"      # Dockerfile  sdk install gradle
EXPECT_MAVEN="3.9.9"       # Dockerfile  sdk install maven
EXPECT_DOTNET="8."         # Dockerfile  dotnet --channel 8.0

# Pinned tools live on PATH via ENV in the Dockerfiles, so no SDKMAN sourcing needed.
[ -f ~/.sdkman/bin/sdkman-init.sh ] && source ~/.sdkman/bin/sdkman-init.sh 2>/dev/null

PASS=0; FAIL=0; WARN=0
C_RESET='\033[0m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'; C_BOLD='\033[1m'; C_DIM='\033[2m'

section() { printf "\n${C_BOLD}%s${C_RESET}\n" "$1"; }
ok()   { printf "  ${C_GREEN}✓${C_RESET} %-20s %s\n" "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf "  ${C_RED}✗${C_RESET} %-20s ${C_RED}%s${C_RESET}\n" "$1" "$2"; FAIL=$((FAIL+1)); }
warn() { printf "  ${C_YELLOW}!${C_RESET} %-20s ${C_YELLOW}%s${C_RESET}\n" "$1" "$2"; WARN=$((WARN+1)); }

# report LABEL "command" [expected-substring]
# Runs the command; the command itself must print the version on a single line.
report() {
    local label="$1" cmd="$2" want="${3:-}" out
    if ! out=$(eval "$cmd" 2>/dev/null) || [ -z "$out" ]; then
        bad "$label" "not found"
        return
    fi
    if [ -n "$want" ] && [[ "$out" != *"$want"* ]]; then
        warn "$label" "$out  (expected ~$want)"
    else
        ok "$label" "$out"
    fi
}

# check_path LABEL path   — assert a file/dir exists
check_path() {
    if [ -e "$2" ]; then ok "$1" "$2"; else bad "$1" "missing: $2"; fi
}

printf "${C_BOLD}claude-docker image check${C_RESET}  ${C_DIM}(%s)${C_RESET}\n" "$(uname -s -m)"

section "System & CLI tools"
report "curl"          "curl --version | head -1"
report "wget"          "wget --version | head -1"
report "git"           "git --version"
report "jq"            "jq --version"
report "zsh"           "zsh --version"
report "ripgrep (rg)"  "rg --version | head -1"
report "fzf"           "fzf --version"
report "git-delta"     "delta --version"                        "$EXPECT_DELTA"
report "unzip"         "unzip -v | head -1"
report "sudo"          "sudo --version | head -1"

section "Languages & package managers"
report "node"          "node --version"                         "$EXPECT_NODE"
report "npm"           "npm --version"
report "python3"       "python3 --version"
report "pip3"          "pip3 --version | head -1"
report "pipx"          "pipx --version"
report "uv"            "uv --version"                            "$EXPECT_UV"
report "uvx"           "uvx --version"
report "npm ignore-scripts" "npm config get ignore-scripts"     "true"

section "Container runtime (Podman)"
report "podman"        "podman --version"
report "podman-compose" "podman-compose --version | head -1"
# Just verify the rootless engine responds — don't depend on a --format field
# name (they differ across podman versions). The API socket is started by the
# entrypoint at runtime, not needed here.
if podman info >/dev/null 2>&1; then ok "podman info" "responds (rootless)"; else bad "podman info" "engine not responding"; fi

section "Claude Code & MCP"
report "claude"        "claude --version"
check_path "config (.claude.json)"  ~/.claude.json
check_path "CLAUDE.md default"      ~/.claude-defaults/CLAUDE.md
check_path "statusLine default"     ~/.claude-defaults/statusline-command.sh
report "MCP servers"   "jq -r '.mcpServers | keys | join(\", \")' ~/.claude.json"
# Playwright browser cache (chromium installed at build time).
# Honour PLAYWRIGHT_BROWSERS_PATH; fall back to the default per-user cache.
pw_dir="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
if ls "$pw_dir" 2>/dev/null | grep -qi chromium; then
    ok "Playwright chromium" "$(ls "$pw_dir" | grep -i chromium | head -1)  ($pw_dir)"
else
    bad "Playwright chromium" "not found in $pw_dir"
fi

section "Build toolchain (project image)"
# These only exist in the project image, not the bare base — skip cleanly there.
if command -v java &>/dev/null; then
    report "java (default)" "java --version | head -1"          "$EXPECT_JAVA"
    if [ -d ~/.sdkman/candidates/java ]; then
        if ls ~/.sdkman/candidates/java | grep -q "$EXPECT_JAVA_ALT"; then
            ok "java (alt JDK)" "$(ls ~/.sdkman/candidates/java | grep "$EXPECT_JAVA_ALT")"
        else
            warn "java (alt JDK)" "$EXPECT_JAVA_ALT not installed"
        fi
    fi
    report "javac"         "javac --version"
    report "gradle"        "gradle --version | grep -i '^Gradle'" "$EXPECT_GRADLE"
    report "maven (mvn)"   "mvn --version | head -1"             "$EXPECT_MAVEN"
    report "dotnet"        "dotnet --version"                    "$EXPECT_DOTNET"
else
    printf "  ${C_DIM}(no JVM — bare base image, skipping Java/.NET checks)${C_RESET}\n"
fi

section "Environment & runtime"
for v in DEVCONTAINER DOCKER_HOST XDG_RUNTIME_DIR TESTCONTAINERS_RYUK_DISABLED PLAYWRIGHT_BROWSERS_PATH JAVA_HOME SDKMAN_DIR DOTNET_ROOT PATH; do
    val="${!v:-}"
    if [ -n "$val" ]; then ok "$v" "$val"; else warn "$v" "(unset)"; fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n${C_BOLD}Summary:${C_RESET} ${C_GREEN}%d ok${C_RESET}, ${C_YELLOW}%d warn${C_RESET}, ${C_RED}%d fail${C_RESET}\n" "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ]
