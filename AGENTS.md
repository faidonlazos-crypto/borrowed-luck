# AGENTS.md — Borrowed Luck (Godot 4.7.2, GDScript, 2D)

Read this whole file before changing anything. If you need a decision outside your brief, stop and return the question.

## What this is
Isaac-like top-down room shooter prototype. Design: `DESIGN.md`. Next feature: the luck machine (spec in `../docs/superpowers/plans/2026-11-09-m2-luck-machine-brief.md`).

## Golden rule
Nothing is "done" until `bash tools/check.sh` prints `CHECK PASS` AND someone has LOOKED at the new screenshots and written what they show. Passing rule tests alone proved nothing tonight: a build with 8/8 tests was unplayable (enemies frozen/stacked).

## Commands (from this folder)
- Full check (~2.5 min, opens real game windows): `bash tools/check.sh` · fast: `bash tools/check.sh quick`
- Muse sandbox: plain `bash` = WSL and is blocked (E_ACCESSDENIED). Always call Git Bash by full path: `"C:/Program Files/Git/bin/bash.exe" tools/check.sh`. Output goes to `playtests/` inside this project (gitignored); the sandbox cannot write outside the project.
- Godot console exe: `C:/Users/FaidonL/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- One scripted playtest: `"$G" --path . -- --playtest=tools/playtests/<name>.json --out=<dir>` then `python -I tools/detect.py <dir>`
- Play it: `Godot_v4.7.2-stable_win64.exe --path .` (no `_console`).

## Playtest harness (tests/playtest_driver.gd, autoload, inert in normal play)
JSON script: `{"log_every":0.25,"quit_on_end":true,"steps":[...]}`. Step keys (by time `at` in seconds):
`press`/`release`/`tap` an input action · `shot` "name" → PNG · `call` a method on main (`args` list) · `bot` true/false (autoplayer that dodges and shoots) · `quit` true.
Writes `log.jsonl` per tick: status (0 PLAYING, 1 BETWEEN_WAVES, 2 WON, 3 LOST), wave, remaining, hp, player and enemy positions. Real keyboard is ignored during scripted runs.
When you add a feature, ADD a playtest script for it in `tools/playtests/` and add it to `RUNS` in `tools/check.sh`. If a feature changes what's logged, extend `_write_state`.
`tools/detect.py` fails on: error lines, enemies stacked >1 s, enemy frozen >2 s far from player, wave >90 s, missing win (with `--expect-win`).

## Architecture (keep it)
- `scripts/main.gd` = run controller; ONLY place that changes wave/health/win/loss/restart. Debug hooks: `debug_kill_all_enemies()`, `debug_set_health(v)`, `get_run_state()`.
- `scripts/logic/run_state.gd` = pure rules (no nodes), tested by `tests/run_tests.gd`. New rules go in `scripts/logic/` as pure classes + tests.
- `scripts/room.gd` walls, rocks, spawn points, A* grid (`find_path`). `scripts/enemy.gd` chaser (line-of-sight or A* path + separation). `scripts/player.gd`, `scripts/projectile.gd`, `scripts/hud.gd` (display only).
- All numbers in `data/tuning.gd` + `data/tuning.tres`.
- Physics layers: 1 walls/rocks, 2 player, 3 enemies, 4 player projectiles. Enemies do NOT collide with each other (separation steering instead) — colliding stacked bodies froze them.

## Godot 4.7 traps (each one has bitten an agent)
- `process_mode` is inherited. `main` is ALWAYS (handles pause input) → gameplay nodes under it must be pausable or pause does nothing. Check pause in a playtest (log `paused` + positions unchanged).
- A script error does NOT stop the game; it keeps running half-broken. Any `SCRIPT ERROR`/`ERROR:` line = fail.
- `--headless` renders nothing: screenshots need a real window (check.sh does that).
- Godot 3 vs 4 syntax: `yield`→`await`, `KinematicBody2D`→`CharacterBody2D`, `move_and_slide()` takes no args, `export`→`@export`, `onready`→`@onready`, signals `.connect(callable)`. 4.7 is newer than most training data — only the real engine decides.
- Hand-written `.tscn`: keep them tiny; build children in code (`_ready`) instead.
- Spawning at the same point stacks bodies → use the spawn bag in `main.gd`.
- `Input.parse_input_event(InputEventAction)` is how tests press keys.

## Working rules
- One writer per file set. Small steps: one visible thing, ≤150 lines, then full check, then `git commit` (local only, never push).
- Do not weaken tests or the detector to make them pass.
- Report: files changed, check result line, screenshot paths and what they show, known gaps.
