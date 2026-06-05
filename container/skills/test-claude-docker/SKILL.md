---
name: test-claude-docker
description: Verify the claude-docker container environment — checks that every tool the image installs (Node, uv, Podman, Claude Code, MCP servers, Playwright, and the Java/Gradle/Maven/.NET build toolchain) is present and at the expected pinned version. Use when the user asks to "test the container", "check the claude-docker environment", "are all tools installed", "what's the state of this image", or similar.
---

# Test claude-docker environment

This skill runs a self-check of the container image it lives in and reports
which tools are installed and whether pinned versions match expectations.

## How to run

Execute the bundled check script and show its output:

```bash
bash ~/.claude/skills/test-claude-docker/checks.sh
```

The script prints a per-tool report (`✓` ok / `!` version drift / `✗` missing)
grouped into sections (system tools, languages, Podman, Claude & MCP, build
toolchain, environment) and ends with a `Summary: N ok, N warn, N fail` line.
It exits non-zero if anything failed.

## How to present the result

1. Run the script and let its output through (the ✓/!/✗ lines are informative).
2. Summarise: state the ok/warn/fail counts.
3. If there are `✗` failures or `!` warnings, call them out explicitly and, for
   each, say what it means — e.g. a version `!` means the installed tool drifted
   from the pin in the Dockerfile; a `✗` means the tool is missing entirely.
4. If everything is `✓`, say the environment is healthy in one line.

Do not try to "fix" findings from inside the container — the fixes belong in
the Dockerfiles on the host. Report, don't patch.
