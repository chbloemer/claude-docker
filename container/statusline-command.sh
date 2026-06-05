#!/usr/bin/env bash
# Claude Code statusLine script
# Reads JSON from stdin and prints a single status line.

input=$(cat)

# Helper: extract via python (always available on macOS)
get() {
  python3 -c "import sys, json; d=json.load(sys.stdin);
keys='$1'.split('.')
v=d
for k in keys:
    v=v.get(k) if isinstance(v, dict) else None
    if v is None: break
print(v if v is not None else '')" <<< "$input"
}

model=$(get "model.display_name")
cwd=$(get "workspace.current_dir")
[ -z "$cwd" ] && cwd=$(get "cwd")
folder=$(basename "$cwd")

# Cost & context from session info
cost=$(python3 -c "import sys, json; d=json.load(sys.stdin); c=d.get('cost',{}); print(f\"\${c.get('total_cost_usd',0):.2f}\" if isinstance(c, dict) else '')" <<< "$input")
ctx_tokens=$(python3 -c "
import sys, json
d=json.load(sys.stdin)
t=d.get('transcript_path','')
total=0
try:
    with open(t) as f:
        for line in f:
            try:
                obj=json.loads(line)
                u=obj.get('message',{}).get('usage')
                if u:
                    total=(u.get('input_tokens',0) or 0) + (u.get('cache_read_input_tokens',0) or 0) + (u.get('cache_creation_input_tokens',0) or 0)
            except: pass
except: pass
print(total)
" <<< "$input")

# Context percentage (200k window default; 1M for opus 4.7 1m)
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