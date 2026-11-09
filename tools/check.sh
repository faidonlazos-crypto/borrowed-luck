#!/usr/bin/env bash
# Full check for Borrowed Luck. Usage: bash tools/check.sh [quick]
# Exit 0 = everything passed. Prints screenshot paths the lead must LOOK at.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd -W)"
G="${GODOT:-C:/Users/FaidonL/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
OUT="$(cd "$ROOT/.." && pwd -W)/playtests/check-$(date +%H%M%S)"
mkdir -p "$OUT"
FAIL=0
bad() { echo "FAIL: $*"; FAIL=1; }
errs() { grep -E "SCRIPT ERROR|Parse Error|^ERROR:| ERROR: " "$1" | head -5; }

echo "== 1 import"
timeout 180 "$G" --headless --path "$ROOT" --import > "$OUT/import.txt" 2>&1 || bad "import exit $?"
E=$(errs "$OUT/import.txt"); [ -n "$E" ] && bad "import errors:" && echo "$E"

echo "== 2 rule tests"
timeout 120 "$G" --headless --path "$ROOT" -s res://tests/run_tests.gd > "$OUT/tests.txt" 2>&1 || bad "run_tests exit $?"
grep -E "^FAIL|RESULT" "$OUT/tests.txt"; E=$(errs "$OUT/tests.txt"); [ -n "$E" ] && bad "test errors:" && echo "$E"

echo "== 3 smoke"
timeout 120 "$G" --headless --path "$ROOT" -s res://tests/smoke.gd > "$OUT/smoke.txt" 2>&1 || bad "smoke exit $?"
grep -E "SMOKE" "$OUT/smoke.txt"; E=$(errs "$OUT/smoke.txt"); [ -n "$E" ] && bad "smoke errors:" && echo "$E"

echo "== 4 playtests (real window)"
RUNS="bot_full:1 bot_full:2 bot_full:3 stand_still:1 corner:1"
[ "${1:-}" = "quick" ] && RUNS="bot_full:1 stand_still:1"
WINS=0
for r in $RUNS; do
  name="${r%%:*}"; n="${r##*:}"; d="$OUT/${name}_$n"
  timeout 150 "$G" --path "$ROOT" -- --playtest="$ROOT/tools/playtests/$name.json" --out="$d" > "$d.stdout" 2>&1
  mkdir -p "$d"; mv "$d.stdout" "$d/stdout.txt"
  python -I "$ROOT/tools/detect.py" "$d" || bad "detector $name#$n"
  grep -q '"status": 2\|"status":2' "$d/log.jsonl" 2>/dev/null && [ "$name" = bot_full ] && WINS=$((WINS+1))
done
echo "bot wins: $WINS"
[ "${1:-}" = "quick" ] || [ $WINS -ge 2 ] || bad "bot won fewer than 2 of 3 full runs"

echo "== screenshots to LOOK at:"; ls "$OUT"/*/*.png 2>/dev/null
if [ $FAIL -eq 0 ]; then echo "CHECK PASS  ($OUT)"; else echo "CHECK FAIL  ($OUT)"; fi
exit $FAIL
