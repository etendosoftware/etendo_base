---
name: qa
description: Run Etendo QA locally exactly like CI (smoke, full regression or a test pattern), report results and triage failures. Use when asked to run tests, verify a change or check QA.
argument-hint: "[smoke | regression | <test pattern>]"
allowed-tools: Bash(.github/qa/run-tests.sh *), Bash(python3 .github/qa/*), Read
---

Run QA for: $ARGUMENTS (default: smoke).

1. Pick the suite file:
   - `smoke` → `.github/qa/suites/smoke.txt`
   - `regression` → write `org.openbravo.test.StandaloneTestSuite` to `build/qa/adhoc.txt` (the official suite keeps the
     execution order some tests depend on; ≈12 min sequential — say so before starting)
   - anything else → write the pattern(s) to `build/qa/adhoc.txt`, one per line
2. Run with the CI entrypoint, English locale and JDK 17 (ask for `JAVA_HOME` if `java -version` is not 17):
   `JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" .github/qa/run-tests.sh <suite-file>`
3. Summarize: `python3 .github/qa/report.py --title "Local QA" --out build/qa build/test-results/test` and show `build/qa/summary.md`.
4. If there are failures, delegate to the `qa-triager` agent with `build/qa/failures.json` and `git diff` (if any),
   then present its verdicts. Flag anything it rates `low` confidence as unverified.
5. If a failure also happens on a clean install and is not caused by the change, propose (don't apply) a
   `.github/qa/known-failures.txt` entry with the verified cause.
