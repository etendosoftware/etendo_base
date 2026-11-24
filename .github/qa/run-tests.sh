#!/usr/bin/env bash
# Runs the tests listed in a suite file against the configured DB.
# Usage: .github/qa/run-tests.sh <suite-file>
# Env:   QA_MAX_RETRIES (default 1)
#        QA_GRADLE_ARGS extra Gradle args (shards use "-x compileJava": a cold recompile wipes the
#        Hibernate .hbm.xml resources that `install` placed in build/classes)
# The exit code is Gradle's (any failure, quarantined or not). The CI gate is `report.py --gate`.
set -euo pipefail
cd "$(dirname "$0")/../.."

suite="${1:-.github/qa/suites/smoke.txt}"
export QA_MAX_RETRIES="${QA_MAX_RETRIES:-1}"

args=()
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs)"
  [ -n "$line" ] && args+=(--tests "$line")
done < "$suite"

# shellcheck disable=SC2086
./gradlew test "${args[@]}" ${QA_GRADLE_ARGS:-} --init-script .github/qa/qa.init.gradle --continue --console=plain < /dev/null
