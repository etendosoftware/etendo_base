#!/usr/bin/env python3
"""Eval harness for the AI triage agent.

Each case in cases/<name>/ holds real failures (failures.json), the optional change under test
(change.diff, applied to the source tree for the run like a real PR) and verified ground truth
(expected.json). A trial passes when every failure gets the expected category and, when the case
says so, the expected `caused_by_change`. Reports per-case pass rate, pass@k and pass^k.

Run from an Etendo source tree (after expandCore):
  .github/qa/ai/evals/run-evals.py [-k 3] [--cases a,b] [--min-pass-rate 0.8]
"""
import argparse, json, os, subprocess, sys, tempfile

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "../../../.."))
ap = argparse.ArgumentParser()
ap.add_argument("-k", type=int, default=1, help="trials per case")
ap.add_argument("--cases", default="", help="comma-separated subset")
ap.add_argument("--min-pass-rate", type=float, default=0.0, help="exit 1 below this overall trial pass rate")
ap.add_argument("--out", default=os.path.join(root, "build/qa-evals"))
ap.add_argument("--regrade", action="store_true", help="re-grade existing trial outputs without calling the agent")
a = ap.parse_args()

names = sorted(os.listdir(os.path.join(here, "cases")))
if a.cases:
    names = [n for n in names if n in a.cases.split(",")]

def git_apply(diff, reverse=False):
    cmd = ["patch", "-p1", "--forward", "--silent"] + (["-R"] if reverse else []) + ["-i", diff]
    subprocess.run(cmd, cwd=root, check=True)

def run_trial(case, diff, out, apply_diff):
    if apply_diff:
        git_apply(diff)
    try:
        subprocess.run([os.path.join(here, "..", "triage.sh"), os.path.join(case, "failures.json"),
                        diff if os.path.exists(diff) else "-", out], check=True, stdout=subprocess.DEVNULL)
    finally:
        if apply_diff:
            git_apply(diff, reverse=True)

rows, total_cost, trials_ok, trials_all = [], 0.0, 0, 0
for name in names:
    case = os.path.join(here, "cases", name)
    exp = json.load(open(os.path.join(case, "expected.json")))
    diff = os.path.join(case, "change.diff")
    results = []
    for t in range(1, a.k + 1):
        out = os.path.join(a.out, name, f"trial-{t}")
        if not a.regrade:
            run_trial(case, diff, out, exp.get("apply_diff"))
        raw = json.load(open(os.path.join(out, "raw.json")))
        total_cost += raw.get("total_cost_usd") or 0
        # Match on SimpleClass.method: the agent may or may not include the package.
        key = lambda name: ".".join(name.split(".")[-2:])
        got = {}
        if os.path.exists(os.path.join(out, "triage.json")):
            got = {key(f["test"]): f for f in json.load(open(os.path.join(out, "triage.json")))["failures"]}
        errors = []
        for test, want in exp["expect"].items():
            g = got.get(key(test))
            if not g:
                errors.append(f"{test}: missing verdict")
                continue
            accepted = want["category"] if isinstance(want["category"], list) else [want["category"]]
            if g["category"] not in accepted:
                errors.append(f"{test}: {g['category']} not in {accepted}")
            if "caused_by_change" in want and bool(g.get("caused_by_change")) != want["caused_by_change"]:
                errors.append(f"{test}: caused_by_change={g.get('caused_by_change')} != {want['caused_by_change']}")
        results.append(errors)
        print(f"{name} trial {t}: {'PASS' if not errors else 'FAIL ' + '; '.join(errors)}", file=sys.stderr)
    passes = sum(1 for e in results if not e)
    trials_ok += passes
    trials_all += len(results)
    rows.append((name, passes, len(results)))

md = ["## 🧪 AI triage evals", "", "| Case | Passed trials | pass@k | pass^k |", "|---|---:|:-:|:-:|"]
md += [f"| `{n}` | {p}/{k} | {'✅' if p else '❌'} | {'✅' if p == k else '❌'} |" for n, p, k in rows]
rate = trials_ok / trials_all if trials_all else 0
md += ["", f"**Trial pass rate: {trials_ok}/{trials_all} ({rate:.0%})** · k={a.k} · cost ${total_cost:.2f}"]
os.makedirs(a.out, exist_ok=True)
open(os.path.join(a.out, "evals.md"), "w").write("\n".join(md) + "\n")
print("\n".join(md))
sys.exit(1 if rate < a.min_pass_rate else 0)
