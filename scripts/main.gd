extends Node

const RoomScene: PackedScene = preload("res://scenes/room.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/projectile.tscn")
const HudScene: PackedScene = preload("res://scenes/hud.tscn")

const PLAYER_START: Vector2 = Vector2(640.0, 360.0)
const MIN_SPAWN_DISTANCE: float = 200.0
const MACHINE_RANGE: float = 70.0

var _tuning: Tuning
var _run_state: RunState
var _luck: LuckRules
var _panel_open: bool = false
var _borrow_available: bool = false
var _room: Room
var _player: Player
var _hud: Hud

var _enemies: Array[Enemy] = []
var _projectiles: Array[Projectile] = []
var _pending_spawns: Array[Dictionary] = []
var _spawn_bag: Array[Vector2] = []

var _is_paused: bool = false
var _debug_god: bool = false  # playtest only: bot_full proves progression, not survival
var _banner_active: bool = false
var _banner_timer: float = 0.0
var _next_wave: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var loaded_tuning := load("res://data/tuning.tres") as Tuning
	if loaded_tuning != null:
		_tuning = loaded_tuning
	else:
		_tuning = Tuning.new()

	_run_state = RunState.new()
	_run_state.reset(_tuning)
	_luck = LuckRules.new(_tuning)

	_room = RoomScene.instantiate() as Room
	add_child(_room)

	_player = PlayerScene.instantiate() as Player
	_player.tuning = _tuning
	_player.run_state = _run_state
	_player.fired.connect(_on_player_fired)
	_player.damage_requested.connect(_on_player_damage_requested)
	add_child(_player)
	_player.reset_for_run(PLAYER_START)

	_hud = HudScene.instantiate() as Hud
	add_child(_hud)
	_hud.machine_choice.connect(_on_machine_choice)

	_start_run()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_run()
		return
	if _panel_open:
		# Esc (pause action) closes only the panel; it must not also
		# toggle the pause menu on the same press.
		if event.is_action_pressed("pause"):
			_close_machine_panel()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			var key := (event as InputEventKey).keycode
			if key == KEY_1 or key == KEY_KP_1:
				_on_machine_choice(1)
			elif key == KEY_2 or key == KEY_KP_2:
				_on_machine_choice(2)
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("interact"):
		_try_open_machine()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _run_state == null:
		return

	_run_state.tick(delta)
	_update_machine_hint()

	if _banner_active:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_begin_wave()
		return

	_process_pending_spawns(delta)

	if _run_state.status == RunState.Status.PLAYING and _run_state.is_wave_cleared():
		_run_state.advance()
		if _run_state.status == RunState.Status.WON:
			_handle_victory()
		elif _run_state.status == RunState.Status.BETWEEN_WAVES:
			_queue_wave(_run_state.current_wave + 1)


func restart_run() -> void:
	get_tree().paused = false
	_is_paused = false
	if _hud != null:
		_hud.set_pause_visible(false)
	_start_run()


# Alias kept short for callers that prefer it.
func restart() -> void:
	restart_run()


func get_run_state() -> RunState:
	return _run_state


func get_debug_state() -> Dictionary:
	var usable := false
	if _luck != null and _run_state != null:
		usable = _luck.can_use(_run_state)
	return {"panel_open": _panel_open, "machine_usable": usable}


func debug_open_machine() -> void:
	if _player != null and _room != null:
		_player.global_position = _room.get_machine_position() + Vector2(0.0, 60.0)
		_player.velocity = Vector2.ZERO
	_open_machine_panel()


func debug_kill_all_enemies() -> void:
	if _run_state == null:
		return
	var pending_snapshot := _pending_spawns.duplicate()
	_pending_spawns.clear()
	for entry in pending_snapshot:
		var marker := entry.get("marker") as Node
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
		_run_state.enemy_killed()

	var snapshot := _enemies.duplicate()
	for enemy in snapshot:
		if enemy != null and is_instance_valid(enemy):
			enemy.take_damage(9999, Vector2.ZERO)
	if _hud != null:
		_hud.set_enemies(_run_state.enemies_remaining)


func debug_set_god(on: bool) -> void:
	_debug_god = on


func debug_set_health(value: int) -> void:
	if _run_state == null:
		return
	_run_state.health = clampi(value, 0, _run_state.max_health)
	_run_state.invuln_timer = 0.0
	if _hud != null:
		_hud.set_health(_run_state.health, _run_state.max_health)
	if _run_state.health <= 0:
		_run_state.status = RunState.Status.LOST
		_handle_game_over()


func _start_run() -> void:
	_clear_enemies_and_projectiles()
	_run_state.reset(_tuning)
	_panel_open = false
	if _luck != null:
		_luck.reset()
	if _player != null:
		_player.set_physics_process(true)
		_player.run_state = _run_state
		_player.reset_for_run(PLAYER_START)
	if _hud != null:
		_hud.hide_overlays()
		_hud.hide_machine_panel()
		_hud.set_pause_visible(false)
		_hud.set_health(_run_state.health, _run_state.max_health)
		_hud.set_wave(1, _run_state.get_total_waves())
		_hud.set_enemies(0)
	_run_state.mark_between_waves()
	_queue_wave(1)


func _queue_wave(wave_number: int) -> void:
	_next_wave = wave_number
	_banner_active = true
	_banner_timer = _tuning.wave_banner_time
	if _hud != null:
		_hud.show_banner("Wave %d" % wave_number)
		_hud.set_wave(wave_number, _run_state.get_total_waves())
		_hud.set_enemies(_run_state.enemies_remaining)


func _begin_wave() -> void:
	_banner_active = false
	if _hud != null:
		_hud.hide_banner()
	var count := _run_state.start_wave(_next_wave)
	if _hud != null:
		_hud.set_wave(_run_state.current_wave, _run_state.get_total_waves())
		_hud.set_enemies(_run_state.enemies_remaining)
	_spawn_bag.clear()
	for i in count:
		_schedule_spawn()


func _schedule_spawn() -> void:
	var spawn_pos := _pick_spawn_position()
	var marker := Polygon2D.new()
	marker.color = Color(1.0, 0.35, 0.2, 0.85)
	marker.polygon = PackedVector2Array([
		Vector2(0.0, -16.0),
		Vector2(16.0, 0.0),
		Vector2(0.0, 16.0),
		Vector2(-16.0, 0.0),
	])
	marker.position = spawn_pos
	marker.z_index = 5
	add_child(marker)
	_pending_spawns.append({
		"position": spawn_pos,
		"timer": _tuning.spawn_warning,
		"marker": marker,
	})


func _process_pending_spawns(delta: float) -> void:
	var pulse := 1.0 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.02)
	for i in range(_pending_spawns.size() - 1, -1, -1):
		var entry := _pending_spawns[i]
		var timer := float(entry.get("timer", 0.0)) - delta
		entry["timer"] = timer
		var marker := entry.get("marker") as Node2D
		if marker != null and is_instance_valid(marker):
			marker.scale = Vector2(pulse, pulse)
		if timer <= 0.0:
			var spawn_pos: Vector2 = entry.get("position", Vector2.ZERO)
			_pending_spawns.remove_at(i)
			if marker != null and is_instance_valid(marker):
				marker.queue_free()
			_spawn_enemy(spawn_pos)


func _spawn_enemy(spawn_pos: Vector2) -> void:
	var enemy := EnemyScene.instantiate() as Enemy
	if enemy == null:
		return
	enemy.setup(_tuning, _player, _room)
	add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.died.connect(_on_enemy_died.bind(enemy))
	_enemies.append(enemy)


func _pick_spawn_position() -> Vector2:
	if _room == null:
		return Vector2(150.0, 130.0)
	# Draw spawn points from a shuffled bag so a wave uses each point once
	# before repeating; repeats get an offset so enemies never stack.
	if _spawn_bag.is_empty():
		var points := _room.get_spawn_points()
		if points.is_empty():
			return Vector2(150.0, 130.0)
		for point in points:
			if _player == null or point.distance_to(_player.global_position) >= MIN_SPAWN_DISTANCE:
				_spawn_bag.append(point)
		if _spawn_bag.is_empty():
			_spawn_bag = points
		_spawn_bag.shuffle()
	var base: Vector2 = _spawn_bag.pop_back()
	var offset := Vector2.ZERO
	for entry in _pending_spawns:
		if (entry.get("position", Vector2.ZERO) as Vector2).distance_to(base) < 30.0:
			offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 40.0
			break
	return base + offset


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if _run_state != null:
		_run_state.enemy_killed()
		if _hud != null:
			_hud.set_enemies(_run_state.enemies_remaining)


func _on_player_fired(spawn_position: Vector2, direction: Vector2) -> void:
	var projectile := ProjectileScene.instantiate() as Projectile
	if projectile == null:
		return
	projectile.setup(direction, _tuning)
	add_child(projectile)
	projectile.global_position = spawn_position
	_projectiles.append(projectile)


func _on_player_damage_requested(amount: int) -> void:
	if _run_state == null or _debug_god:
		return
	var applied := _run_state.damage(amount)
	if not applied:
		return
	if _hud != null:
		_hud.set_health(_run_state.health, _run_state.max_health)
	if _run_state.status == RunState.Status.LOST:
		_handle_game_over()


func _update_machine_hint() -> void:
	if _hud == null or _player == null or _room == null or _luck == null or _run_state == null:
		return
	if _panel_open or _player.global_position.distance_to(_room.get_machine_position()) > MACHINE_RANGE:
		_hud.set_machine_hint("", false)
		return
	if _luck.can_use(_run_state):
		_hud.set_machine_hint("E — luck machine", false)
	else:
		_hud.set_machine_hint(_machine_reason_text(), true)


func _machine_reason_text() -> String:
	match _luck.blocked_reason(_run_state):
		"already_used":
			return "Machine: used this wave"
		"wave_not_eligible":
			return "Machine: closed in wave %d" % _run_state.current_wave
		_:
			return "Machine: not now"


func _try_open_machine() -> void:
	if get_tree().paused or _luck == null or _run_state == null or not _luck.can_use(_run_state):
		return
	if _player == null or _room == null:
		return
	if _player.global_position.distance_to(_room.get_machine_position()) > MACHINE_RANGE:
		return
	_open_machine_panel()


func _open_machine_panel() -> void:
	if _hud == null or _run_state == null or _tuning == null:
		return
	_panel_open = true
	_borrow_available = _run_state.health < _run_state.max_health
	get_tree().paused = true
	_hud.set_machine_hint("", false)
	_hud.show_machine_panel(_ordinary_text(), _borrowed_text(), _borrow_available)


func _close_machine_panel() -> void:
	_panel_open = false
	if _hud != null:
		_hud.hide_machine_panel()
		_hud.set_pause_visible(false)
	_is_paused = false
	get_tree().paused = false


func _on_machine_choice(choice: int) -> void:
	if not _panel_open:
		return
	if choice == 2 and not _borrow_available:
		return
	# S2: choices only close + log; effects land in S3. Cancel (0) never spends.
	if choice == 1 or choice == 2:
		print("choice %d" % choice)
	_close_machine_panel()


func _ordinary_text() -> String:
	var heal_pct := int(round(_tuning.ordinary_heal_chance * 100.0))
	var faster_pct := int(round((1.0 - _tuning.fast_hands_mult) * 100.0))
	return "1  Ordinary luck — %d%%: +%s · %d%%: Fast hands (shoot %d%% faster this wave). No debt." % [
		heal_pct, _hearts_text(_tuning.ordinary_heal), 100 - heal_pct, faster_pct]


func _borrowed_text() -> String:
	return "2  Borrowed luck — +%s now. Next wave: +%d enemies." % [
		_hearts_text(_tuning.borrow_heal), _tuning.borrow_debt]


## Tuning health units are half-hearts: 1 -> "½ heart", 2 -> "1 heart".
func _hearts_text(half_hearts: int) -> String:
	var halves := maxi(0, half_hearts)
	if halves == 1:
		return "½ heart"
	if halves % 2 == 1:
		return "%d½ hearts" % (halves / 2)
	return "%d heart%s" % [halves / 2, "" if halves == 2 else "s"]


func _toggle_pause() -> void:
	if _run_state != null and (_run_state.status == RunState.Status.WON or _run_state.status == RunState.Status.LOST):
		return
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	if _hud != null:
		_hud.set_pause_visible(_is_paused)


func _handle_victory() -> void:
	_banner_active = false
	if _player != null:
		_player.set_physics_process(false)
	_clear_projectiles_and_pending()
	if _hud != null:
		_hud.hide_banner()
		_hud.set_enemies(0)
		_hud.show_victory()


func _handle_game_over() -> void:
	_banner_active = false
	if _player != null:
		_player.set_physics_process(false)
	_clear_enemies_and_projectiles()
	if _hud != null:
		_hud.hide_banner()
		_hud.show_game_over()


func _clear_enemies_and_projectiles() -> void:
	for enemy in _enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_clear_projectiles_and_pending()


func _clear_projectiles_and_pending() -> void:
	for projectile in _projectiles:
		if projectile != null and is_instance_valid(projectile):
			projectile.queue_free()
	_projectiles.clear()
	for entry in _pending_spawns:
		var marker := entry.get("marker") as Node
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_pending_spawns.clear()
