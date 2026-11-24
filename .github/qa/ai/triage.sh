#!/usr/bin/env bash
# AI triage of failing tests with Claude Code in headless mode (same script in CI and locally).
# Usage: .github/qa/ai/triage.sh <failures.json> <diff-file|-> <out-dir>
# Env:   QA_AI_MODEL (default sonnet), QA_AI_MAX_TURNS (default 30). Auth: ANTHROPIC_API_KEY or a logged-in CLI.
# Writes <out-dir>/triage.json (structured verdicts) and <out-dir>/triage.md (PR-ready). Read-only tools only.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
failures="$1"; diff="$2"; out="$(mkdir -p "$3" && cd "$3" && pwd)"

if [ "$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['failures']))" "$failures")" = 0 ]; then
  echo "No failures to triage."; exit 0
fi

# Inputs live inside the repo so the agent's Read tool can open them.
work="$root/build/qa-ai"; mkdir -p "$work"
cp "$failures" "$work/failures.json"
if [ "$diff" = "-" ] || [ ! -s "$diff" ]; then : > "$work/change.diff"; else cp "$diff" "$work/change.diff"; fi

prompt="$(sed -e "s#{{FAILURES}}#build/qa-ai/failures.json#g" -e "s#{{DIFF}}#build/qa-ai/change.diff#g" "$here/triage-prompt.md")"

cd "$root"
claude -p "$prompt" \
  --output-format json \
  --json-schema "$(cat "$here/triage-schema.json")" \
  --allowedTools "Read,Grep,Glob" \
  --permission-mode dontAsk \
  --max-turns "${QA_AI_MAX_TURNS:-30}" \
  --model "${QA_AI_MODEL:-sonnet}" \
  > "$out/raw.json"

python3 "$here/render-triage.py" "$out/raw.json" "$out"
