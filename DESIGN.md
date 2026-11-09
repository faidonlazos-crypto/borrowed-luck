# Borrowed Luck — Milestone 1: Isaac-like room arena (2D)

Status: approved direction by owner 2026-11-09 («as pame na DOKIMASOUME afto an den mou aresei pame sto allo»). Replaces the 3D FPS arena of the earlier draft for now; the luck machine (earlier draft, "The luck decision") is Milestone 2 and is NOT built yet. If the owner dislikes the 2D feel, fall back to the 3D arena draft.

## Goal
A playable top-down 2D room in Godot 4.7.2 that feels like The Binding of Isaac's combat: move, shoot in four directions, clear three enemy waves, die or win, restart. Owner plays it to decide 2D vs 3D.

## Scope
- Godot 4.7.2, GDScript, single-player desktop, 1280x720 window, stretch mode canvas_items. No external assets, plugins or downloads; placeholder shapes drawn with Polygon2D/ColorRect/_draw.
- One rectangular room with walls and 3-4 rock obstacles (static bodies).
- Player: WASD moves (8 directions, slight acceleration), arrow keys shoot projectiles in 4 directions (Isaac style). Fire rate and projectile speed/range from tuning. Projectiles stop at walls/rocks.
- Enemy (one type, "chaser"): walks toward the player, contact damage, 3 hits to kill, small knockback and flash when hit.
- Health: 6 points shown as 3 hearts with halves; contact deals 1 (half heart); 1 s invulnerability with blinking after a hit.
- Waves: 3 / 5 / 7 enemies. Spawns appear at spawn points with a 0.6 s warning marker, never on top of the player. A wave is cleared when all its enemies are dead; a 1.5 s "Wave N" banner before the next. Clearing wave 3 = win.
- HUD: hearts, wave number, enemies remaining. Overlays: Pause (Esc), Game Over, Victory. R restarts from the initial state at any time after win/loss (and from pause).
- All numbers in one editable resource `res://data/tuning.tres`.

## Structure
Separate scenes/scripts: player, projectile, enemy, room, HUD, and a run controller that alone owns wave/health/win/loss/restart transitions. Wave rules live in a pure logic class (no nodes) so they can be tested headless. HUD only displays and sends requests.

## Verification
- Project imports and all scripts parse with no errors (headless).
- Headless test script covers wave logic: counts per wave, clear → advance, wave 3 clear → win, health 0 → loss, health clamps 0..max, invulnerability blocks repeat damage, restart resets everything.
- Smoke test loads the main scene headless, forces waves to clear → victory, and forces death → game over, without errors.
- Owner plays the window build: movement feel, shooting, collisions, readability.

Out of scope for M1: luck machine/debt, multiple rooms/doors, items, bosses, co-op, art/audio.
