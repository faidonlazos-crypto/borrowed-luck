extends Node

const RoomScene: PackedScene = preload("res://scenes/room.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/projectile.tscn")
const HudScene: PackedScene = preload("res://scenes/hud.tscn")

const PLAYER_START: Vector2 = Vector2(640.0, 360.0)
const MIN_SPAWN_DISTANCE: float = 200.0

var _tuning: Tuning
var _run_state: RunState
var _room: Room
var _player: Player
var _hud: Hud

var _enemies: Array[Enemy] = []
var _projectiles: Array[Projectile] = []
var _pending_spawns: Array[Dictionary] = []
var _spawn_bag: Array[Vector2] = []

var _is_paused: bool = false
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

	_start_run()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_run()
	elif event.is_action_pressed("pause"):
		_toggle_pause()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _run_state == null:
		return

	_run_state.tick(delta)

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
	if _player != null:
		_player.set_physics_process(true)
		_player.run_state = _run_state
		_player.reset_for_run(PLAYER_START)
	if _hud != null:
		_hud.hide_overlays()
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
	if _run_state == null:
		return
	var applied := _run_state.damage(amount)
	if not applied:
		return
	if _hud != null:
		_hud.set_health(_run_state.health, _run_state.max_health)
	if _run_state.status == RunState.Status.LOST:
		_handle_game_over()


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
