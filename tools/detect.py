"""Broken-game detector. Reads a playtest log.jsonl (+ optional stdout file).

Usage: python -I tools/detect.py <run_dir> [--expect-win]
Exit 0 = PASS, 1 = FAIL. Prints one line per problem.

Fails on:
  - any error line in <run_dir>/stdout.txt (SCRIPT ERROR, Parse Error, ERROR:)
  - two enemies within 4 px of each other for > 1.0 s (stacked)
  - an enemy that moves < 3 px for > 2.0 s while > 60 px from the player, unpaused (frozen/stuck)
  - a wave lasting > 90 s
  - no log / no ticks
  - with --expect-win: run did not end WON (status 2)
"""
import json
import math
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    run = Path(sys.argv[1])
    expect_win = "--expect-win" in sys.argv
    problems = []

    out = run / "stdout.txt"
    if out.exists():
        for line in out.read_text(encoding="utf-8", errors="replace").splitlines():
            if "SCRIPT ERROR" in line or "Parse Error" in line or line.startswith("ERROR:") or " ERROR: " in line:
                problems.append(f"error line: {line.strip()[:160]}")

    log = run / "log.jsonl"
    if not log.exists():
        print(f"FAIL {run.name}: no log.jsonl")
        return 1
    rows = [json.loads(l) for l in log.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(rows) < 3:
        problems.append("log has fewer than 3 rows")

    stacked_since = None
    # frozen tracking by enemy index within the same wave (positions list order is stable)
    frozen = {}
    wave_start = {}
    last_status = None
    for r in rows:
        t = r["t"]
        en = r.get("enemies", [])
        paused = r.get("paused", False)
        # stacked
        close = any(
            math.dist(en[i], en[j]) < 4.0 for i in range(len(en)) for j in range(i + 1, len(en))
        )
        if close and not paused:
            stacked_since = t if stacked_since is None else stacked_since
            if t - stacked_since > 1.0:
                problems.append(f"enemies stacked on one spot > 1 s (wave {r.get('wave')}, first at t={stacked_since})")
        elif not close:
            stacked_since = None
        # frozen
        pl = r.get("player")
        key = (r.get("wave"), len(en))
        for i, p in enumerate(en):
            k = (key, i)
            far = pl is not None and math.dist(p, pl) > 60.0
            prev = frozen.get(k)
            if prev is None or math.dist(prev[0], p) >= 3.0 or paused or not far:
                frozen[k] = (p, t)
            elif t - prev[1] > 2.0:
                problems.append(f"t={t}: enemy #{i} frozen at {p} > 2 s, {round(math.dist(p, pl))} px from player (wave {r.get('wave')})")
                frozen[k] = (p, 1e9)
        # wave length
        w = r.get("wave")
        if w and r.get("status") == 0:
            wave_start.setdefault(w, t)
            if t - wave_start[w] > 90.0:
                problems.append(f"wave {w} lasting > 90 s")
                wave_start[w] = 1e9
        last_status = r.get("status", last_status)

    if expect_win and last_status != 2:
        problems.append(f"expected WON, final status={last_status}")

    # de-duplicate
    seen = []
    for p in problems:
        if p not in seen:
            seen.append(p)
    if seen:
        for p in seen:
            print(f"FAIL {run.name}: {p}")
        return 1
    print(f"PASS {run.name}: {len(rows)} rows, final status={last_status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
