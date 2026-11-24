# Etendo base — QA harness

Etendo ERP (Openbravo fork; Java 17, Hibernate, PostgreSQL). Only build files and `.github/` are
versioned; the core sources (`src*/`, `modules_core/`, `src-test/`) come from `./gradlew expandCore`.

## Running tests
- Always through `.github/qa/run-tests.sh <suite-file>` — the same entrypoint CI uses.
  Suites: `.github/qa/suites/smoke.txt`; full DB-only regression = `org.openbravo.test.StandaloneTestSuite`.
  Some tests depend on execution order: never run a suite's classes as loose `--tests` patterns; CI
  shards are generated ordered suites (`.github/qa/plan-shards.py`).
- Results: `python3 .github/qa/report.py --out build/qa build/test-results/test` → `summary.md`, `failures.json`.
- Requires JDK 17 (`JAVA_HOME`) and a DB configured in `gradle.properties` / `config/Openbravo.properties`.
- Tests assert English texts: run with `JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US"`.

## Rules
- Never commit `gradle.properties` changes: it holds local credentials. CI writes its own.
- `install` runs `DROP ROLE IF EXISTS <bbdd.user>`: never point a test install at a shared role.
- A test failing on a clean install goes to `.github/qa/known-failures.txt` with its verified cause, not deleted.
- Failure triage rules live in `.github/qa/ai/triage-prompt.md` (shared by CI and the `qa-triager` agent).
- Changing anything in `.github/qa/ai/` requires running `.github/qa/ai/evals/run-evals.py`.
