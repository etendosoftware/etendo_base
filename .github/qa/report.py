#!/usr/bin/env python3
"""Aggregate JUnit XML results into a Markdown summary, a failures JSON and per-class timings.

Usage: report.py [--gate] --out DIR RESULTS_DIR [RESULTS_DIR ...]
Writes DIR/summary.md, DIR/failures.json, DIR/timings.json.
Quarantine: failures matching known-failures.txt (Gradle-style patterns: Class or Class.method*) are
reported separately and do not gate; quarantined tests that now pass are flagged for removal.
With --gate, exits 1 when there are non-quarantined failures (this is the CI gate).
With --floor NAME, also fails when fewer tests ran than floors.json[NAME] (tests must not silently disappear).
"""
import argparse, fnmatch, glob, json, os, re, sys, xml.etree.ElementTree as ET
from collections import defaultdict

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--title", default="QA results")
ap.add_argument("--known", default=os.path.join(os.path.dirname(__file__), "known-failures.txt"))
ap.add_argument("--gate", action="store_true")
ap.add_argument("--floor", help="key in floors.json with the minimum test count")
ap.add_argument("dirs", nargs="+")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)

known = set()
if os.path.exists(a.known):
    for line in open(a.known):
        p = re.sub(r"#.*", "", line).strip()
        if p:
            known.add(p)

# Each (class, test) may appear several times when the retry plugin re-ran it.
runs = defaultdict(list)            # (cls, name) -> [outcome, ...]
details = {}                        # (cls, name) -> (message, trace)
timings = defaultdict(float)
for d in a.dirs:
    for f in glob.glob(os.path.join(d, "**", "TEST-*.xml"), recursive=True):
        root = ET.parse(f).getroot()
        for tc in root.iter("testcase"):
            cls, name = tc.get("classname"), tc.get("name")
            timings[cls] += float(tc.get("time") or 0)
            bad = next((c for c in tc if c.tag in ("failure", "error")), None)
            if bad is not None:
                runs[(cls, name)].append("fail")
                details[(cls, name)] = ((bad.get("message") or "").strip(), (bad.text or "").strip())
            elif tc.find("skipped") is not None:
                runs[(cls, name)].append("skip")
            else:
                runs[(cls, name)].append("pass")

def quarantined(cls, name):
    return any(p == cls or fnmatch.fnmatchcase(f"{cls}.{name}", p) for p in known)

failed, flaky, in_quarantine, healed = [], [], [], []
passed = skipped = 0
for key, outcomes in runs.items():
    if quarantined(*key):
        (in_quarantine if outcomes[-1] == "fail" else healed if outcomes[-1] == "pass" else []).append(key)
    if outcomes[-1] == "fail":
        if not quarantined(*key):
            failed.append(key)
    elif "fail" in outcomes:
        flaky.append(key)
    elif outcomes[-1] == "skip":
        skipped += 1
    else:
        passed += 1
total = len(runs)
secs = sum(timings.values())

def short(msg, n=160):
    msg = " ".join(msg.split())
    return (msg[: n - 1] + "…") if len(msg) > n else msg

floor = json.load(open(os.path.join(os.path.dirname(__file__), "floors.json")))[a.floor] if a.floor else 0
below_floor = total < floor
icon = "❌" if failed or below_floor else ("⚠️" if flaky or healed else "✅")
md = [f"## {icon} {a.title}", "",
      "| Total | Passed | Failed | Quarantined | Flaky | Skipped | Test time |",
      "|---:|---:|---:|---:|---:|---:|---:|",
      f"| {total} | {passed} | {len(failed)} | {len(in_quarantine)} | {len(flaky)} | {skipped} | {secs/60:.1f} min |", ""]
if below_floor:
    md += [f"### ❌ Only {total} tests ran; the floor for `{a.floor}` is {floor}",
           "", "Tests were lost (deleted, renamed or not discovered). If this is intended, lower the floor in `.github/qa/floors.json` in the same PR.", ""]
if failed:
    md += ["### Failures", "", "| Test | Message |", "|---|---|"]
    md += [f"| `{c.split('.')[-1]}.{n}` | {short(details[(c, n)][0]).replace('|', '/')} |" for c, n in sorted(failed)]
    md.append("")
if flaky:
    md += ["### Flaky (failed, then passed on retry)", ""]
    md += [f"- `{c.split('.')[-1]}.{n}`" for c, n in sorted(flaky)]
    md.append("")
if healed:
    md += ["### ✅ Quarantined tests now passing — remove them from `.github/qa/known-failures.txt`", ""]
    md += [f"- `{c.split('.')[-1]}.{n}`" for c, n in sorted(healed)]
    md.append("")
if in_quarantine:
    md += [f"<sub>{len(in_quarantine)} known failure(s) in quarantine, not gating — see `.github/qa/known-failures.txt`.</sub>", ""]
slow = sorted(timings.items(), key=lambda kv: -kv[1])[:5]
if slow:
    md += ["<details><summary>Slowest classes</summary>", ""]
    md += [f"- `{c}` — {t:.1f}s" for c, t in slow]
    md += ["", "</details>"]

open(os.path.join(a.out, "summary.md"), "w").write("\n".join(md) + "\n")
json.dump({"total": total, "passed": passed, "skipped": skipped,
           "failures": [{"class": c, "test": n, "message": details[(c, n)][0],
                         "trace": details[(c, n)][1][:4000]} for c, n in sorted(failed)],
           "flaky": [{"class": c, "test": n} for c, n in sorted(flaky)],
           "quarantined": [{"class": c, "test": n} for c, n in sorted(in_quarantine)],
           "healed": [{"class": c, "test": n} for c, n in sorted(healed)]},
          open(os.path.join(a.out, "failures.json"), "w"), indent=2)
json.dump({c: round(t, 2) for c, t in sorted(timings.items())},
          open(os.path.join(a.out, "timings.json"), "w"), indent=2)
print("\n".join(md))
sys.exit(1 if a.gate and (failed or below_floor) else 0)
