#!/usr/bin/env bash
# Flaky policy: a test that failed and then passed on retry is a bug with an owner, not noise.
# Opens (or comments on) one issue per flaky test, deduplicated by title.
# Usage: .github/qa/flaky-issues.sh <failures.json> <run-url>    (needs GH_TOKEN with issues: write)
set -euo pipefail
failures="$1"; run_url="$2"

python3 -c "import json,sys;[print(f\"{f['class']}.{f['test']}\") for f in json.load(open(sys.argv[1]))['flaky']]" "$failures" |
while IFS= read -r test; do
  title="Flaky test: ${test}"
  n=$(gh issue list --state open --search "in:title \"${title}\"" --json number,title \
        -q ".[] | select(.title == \"${title}\") | .number" | head -1)
  body="Failed and then passed on retry in ${run_url}

Policy: fix the cause; do not add retries, sleeps or longer timeouts. Reproduce it first
(run the test repeatedly), then fix the shared state, ordering or timing that makes it nondeterministic.
Assign an owner. Close this issue only with the fix."
  if [ -n "$n" ]; then
    gh issue comment "$n" --body "Seen again: ${run_url}"
  else
    gh issue create --title "$title" --body "$body"
  fi
done
