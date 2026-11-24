#!/usr/bin/env bash
# Prints the newest main commit that passed the full regression: the commit to build releases from.
# Every successful qa-regression.yml run on main is the record; no extra state is stored.
# Usage: .github/qa/last-green.sh [count]     (needs `gh` authenticated for this repo)
set -euo pipefail
gh run list --workflow qa-regression.yml --branch main --status success \
  --limit "${1:-1}" --json headSha,createdAt,event,url \
  --jq '.[] | "\(.headSha)  \(.createdAt)  \(.event)  \(.url)"'
