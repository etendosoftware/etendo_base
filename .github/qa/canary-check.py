#!/usr/bin/env python3
"""Canary verdict: after a known bug is injected, CI must go red and (if the AI ran) blame the change.

Usage: canary-check.py FAILURES_JSON [TRIAGE_JSON]
Exit 0 = the pipeline still detects bugs. Exit 1 = it went blind (e.g. tests skipped, selector broken).
"""
import json, os, sys

TARGET = "PasswordStrengthCheckerTest"
fails = [f for f in json.load(open(sys.argv[1]))["failures"] if f["class"].endswith(TARGET)]
problems = [] if fails else [f"no {TARGET} failure: the injected bug went undetected"]

if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
    verdicts = {".".join(v["test"].split(".")[-2:]): v for v in json.load(open(sys.argv[2]))["failures"]}
    for f in fails:
        v = verdicts.get(f"{TARGET}.{f['test']}")
        if not v or v["category"] != "regression" or not v.get("caused_by_change"):
            problems.append(f"AI verdict for {f['test']}: {v and (v['category'], v.get('caused_by_change'))} (expected regression, caused by change)")

print(f"{len(fails)} canary failure(s) detected" if fails else "canary NOT detected")
for p in problems:
    print("PROBLEM:", p)
sys.exit(1 if problems else 0)
