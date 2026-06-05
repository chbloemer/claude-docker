#!/usr/bin/env bash
# Claude Code statusLine script
# Reads JSON from stdin and prints a single status line.

input=$(cat)

# Extract everything in ONE python3 pass (statusLine renders often — avoid
# forking an interpreter per field). Emits tab-separated:
#   model <TAB> cwd <TAB> cost <TAB> ctx_tokens
IFS=$'\t' read -r model cwd cost ctx_tokens <<EOF
$(python3 -c '
import sys, json

d = json.load(sys.stdin)

def dig(obj, path):
    for k in path.split("."):
        obj = obj.get(k) if isinstance(obj, dict) else None
        if obj is None:
            return None
    return obj

model = dig(d, "model.display_name") or ""
cwd = dig(d, "workspace.current_dir") or d.get("cwd") or ""

cost = dig(d, "cost.total_cost_usd")
cost = f"${cost:.2f}" if isinstance(cost, (int, float)) else ""

# Context size = usage of the most recent transcript message that has it.
ctx = 0
t = d.get("transcript_path", "")
try:
    with open(t) as f:
        for line in f:
            try:
                u = json.loads(line).get("message", {}).get("usage")
            except Exception:
                continue
            if u:
                ctx = ((u.get("input_tokens") or 0)
                       + (u.get("cache_read_input_tokens") or 0)
                       + (u.get("cache_creation_input_tokens") or 0))
except Exception:
    pass

print("\t".join([model, cwd, cost, str(ctx)]))
' <<< "$input")
EOF

folder=$(basename "$cwd")

# Context percentage (200k window default; 1M for the 1M-context models)
ctx_max=200000
case "$model" in
  *1M*|*"1m"*) ctx_max=1000000 ;;
esac
if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" -gt 0 ] 2>/dev/null; then
  ctx_pct=$(( ctx_tokens * 100 / ctx_max ))
  ctx_str="${ctx_pct}% (${ctx_tokens}/${ctx_max})"
else
  ctx_str="—"
fi

# Git branch
branch=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
fi

# ANSI colors
C_RESET='\033[0m'
C_DIM='\033[2m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_MAGENTA='\033[35m'
C_BLUE='\033[34m'

out=""
out+="${C_CYAN}${folder}${C_RESET}"
[ -n "$branch" ] && out+=" ${C_DIM}on${C_RESET} ${C_GREEN}${branch}${C_RESET}"
out+=" ${C_DIM}│${C_RESET} ${C_MAGENTA}${model}${C_RESET}"
out+=" ${C_DIM}│${C_RESET} ${C_YELLOW}ctx ${ctx_str}${C_RESET}"
[ -n "$cost" ] && out+=" ${C_DIM}│${C_RESET} ${C_BLUE}${cost}${C_RESET}"

printf "%b" "$out"
