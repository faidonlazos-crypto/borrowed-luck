# Borrowed Luck — M1: Isaac-like room arena

## Playtest (for friends)

**Easiest (Windows):** go to [Releases](https://github.com/faidonlazos-crypto/borrowed-luck/releases), download the newest `BorrowedLuck-vX-windows.zip`, unzip, double-click `BorrowedLuck.exe` (SmartScreen: More info → Run anyway). Or run from source:

1. Download **Godot 4.7.2** (standard, not .NET): https://godotengine.org/download/archive/4.7.2-stable/ and unzip it.
2. Download this repo: green **Code** button → **Download ZIP**, unzip.
3. Start Godot → **Import** → pick `project.godot` from the unzipped folder → **Import & Edit** → press **F5** (Run).
4. Play 3 runs and tell us: what felt good, what felt bad, where you got confused, any bug (what you did right before it).

Early prototype: placeholder shapes, no art or sound. The luck system is being redesigned (dice on a key), so the current machine is temporary.

A top-down 2D arena prototype in Godot 4.7.2 / GDScript. One room, three waves, placeholder shapes only. See [DESIGN.md](DESIGN.md) for the approved design.

## Controls

| Input | Action |
| --- | --- |
| W / A / S / D | Move (8 directions) |
| Arrow keys | Shoot up / down / left / right (Isaac style, 4 directions) |
| Esc | Pause / resume. On the victory or game-over overlay, Esc quits. |
| R | Restart the run (works during play, pause, victory, and game over) |

## Gameplay

- Health is 6 points, shown as 3 hearts with halves. Contact damage is 1 point (half heart).
- After a hit the player is invulnerable for 1 s and blinks.
- Waves spawn 3 / 5 / 7 chaser enemies. Each spawn shows a warning marker for 0.6 s at a point at least 200 px from the player.
- A 1.5 s "Wave N" banner plays before each wave. Clearing wave 3 wins; health reaching 0 loses.
- The room is a 1200x640 play area with walls and 4 rock obstacles. Projectiles stop at walls, rocks, and the first enemy hit.
- All gameplay numbers live in [data/tuning.tres](data/tuning.tres) (script: [data/tuning.gd](data/tuning.gd)).

## How to run

Open the project in Godot 4.7.2 and run the main scene ([scenes/main.tscn](scenes/main.tscn)), or from the command line:

```powershell
$GODOT = "C:/Users/FaidonL/Downloads/Godot_v4.7.2-stable_win64.exe"
& $GODOT --path .
```

## How the lead runs the tests

Run these from the workspace root. Import first so `class_name` scripts are registered.

```powershell
$GODOT = "C:/Users/FaidonL/Downloads/Godot_v4.7.2-stable_win64.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . -s res://tests/run_tests.gd
& $GODOT --headless --path . -s res://tests/smoke.gd
```

Expected results:

- `run_tests.gd` prints `PASS`/`FAIL` per test, then `RESULT: N passed, 0 failed`, and exits 0. It covers only the pure-logic `RunState` class: wave counts 3/5/7, wave clearing, advance to victory, damage to loss, health clamping, invulnerability timing, damage ignored when won/lost, and reset.
- `smoke.gd` prints `SMOKE PASS` and exits 0. It loads the main scene, force-kills waves through to victory via `debug_kill_all_enemies()`, restarts, forces death via `debug_set_health(0)`, and checks the lost state. It has a hard 25 s timeout that exits 1 instead of hanging.
- No parse errors or `SCRIPT ERROR` lines in any output.

The run controller ([scripts/main.gd](scripts/main.gd)) exposes `get_run_state()`, `debug_kill_all_enemies()`, `debug_set_health(v)`, and `restart_run()` for tests.

## Structure

- [scripts/logic/run_state.gd](scripts/logic/run_state.gd) — pure wave/health/status logic, no nodes.
- [scripts/player.gd](scripts/player.gd), [scripts/enemy.gd](scripts/enemy.gd), [scripts/projectile.gd](scripts/projectile.gd), [scripts/room.gd](scripts/room.gd), [scripts/hud.gd](scripts/hud.gd) — one script per scene in `scenes/`; simple visuals (walls, rocks, hearts, markers) are built in code to keep the `.tscn` files minimal.
- [scripts/main.gd](scripts/main.gd) — run controller: owns `RunState`, spawns waves with warning markers, handles banner/pause/restart/win/loss. HUD only displays state.

## Known gaps

- Placeholder shapes only: no art, animation beyond blink/flash, or audio.
- One enemy type (chaser), one room, no doors, items, bosses, or the Milestone 2 luck machine.
- Enemy separation is only collision-based; chasers can bunch up.
- Shooting picks a single cardinal direction (horizontal priority); no diagonal fire, matching the Isaac-style brief.
- Tests were not run by the authoring agent (no execution environment); the lead runs the commands above.
