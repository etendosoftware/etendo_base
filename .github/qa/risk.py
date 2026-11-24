#!/usr/bin/env python3
"""Deterministic risk grade for a change (no AI): low | medium | high, with the rule behind each reason.

Usage: risk.py DIFF_FILE [--out DIR]   (DIFF_FILE = `git diff base...HEAD`)
Writes DIR/risk.json and DIR/risk.md; prints the level. High risk forces the full regression.
"""
import argparse, fnmatch, json, os, re

LEVELS = ["low", "medium", "high"]

# (level, reason, file glob, regex on changed lines or None = any change to the file)
RULES = [
    ("high",   "Etendo core version range changed",            "build.gradle",        r"coreVersion"),
    ("high",   "Gradle plugin version changed",                "build.gradle",        r"^\s*id\s+['\"].*['\"]\s+version"),
    ("high",   "Gradle wrapper changed",                       "gradle/wrapper/*",    None),
    ("high",   "Module discovery / plugin repositories changed", "settings.gradle",   None),
    ("medium", "Module dependency added, removed or re-versioned", "build.gradle",    r"(implementation|compileOnly|runtimeOnly|moduleDeps)\s*\("),
    ("medium", "build.gradle changed",                         "build.gradle",        None),
    ("medium", "CI pipeline changed",                          ".github/workflows/*", None),
    ("medium", "CI pipeline changed",                          ".github/actions/*",   None),
    ("medium", "QA tooling changed",                           ".github/qa/*",        None),
    ("low",    "Documentation or editor/agent config",         "*.md",                None),
    ("low",    "Documentation or editor/agent config",         ".claude/*",           None),
    ("low",    "Documentation or editor/agent config",         ".run/*",              None),
]

ap = argparse.ArgumentParser()
ap.add_argument("diff")
ap.add_argument("--out", default=".")
a = ap.parse_args()

# Split the unified diff per file, keeping only added/removed lines.
changes, current = {}, None
for line in open(a.diff, encoding="utf-8", errors="ignore"):
    m = re.match(r"^diff --git a/(\S+) b/(\S+)", line)
    if m:
        current = m.group(2)
        changes[current] = []
    elif current and line[:1] in "+-" and not line.startswith(("+++", "---")):
        changes[current].append(line[1:])

reasons, level = [], "low"
for path, lines in changes.items():
    matched = False
    for lvl, why, glob, rx in RULES:
        if not fnmatch.fnmatch(path, glob):
            continue
        if rx is None or any(re.search(rx, l) for l in lines):
            reasons.append({"level": lvl, "file": path, "rule": why})
            level = max(level, lvl, key=LEVELS.index)
            matched = True
            break
    if not matched:
        reasons.append({"level": "medium", "file": path, "rule": "File not covered by a rule (default medium)"})
        level = max(level, "medium", key=LEVELS.index)

os.makedirs(a.out, exist_ok=True)
json.dump({"level": level, "reasons": reasons}, open(os.path.join(a.out, "risk.json"), "w"), indent=2)
badge = {"low": "🟢 low", "medium": "🟡 medium", "high": "🔴 high"}[level]
md = [f"**Risk: {badge}**" + (" — full regression required" if level == "high" else ""), ""]
md += [f"- `{r['file']}`: {r['rule']} ({r['level']})" for r in reasons] or ["- no file changes"]
open(os.path.join(a.out, "risk.md"), "w").write("\n".join(md) + "\n")
print(level)
