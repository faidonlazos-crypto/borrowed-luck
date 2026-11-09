class_name Player extends CharacterBody2D

signal fired(spawn_position: Vector2, direction: Vector2)
signal damage_requested(amount: int)

@export var tuning: Tuning

var run_state: RunState

var _fire_timer: float = 0.0
var _blink_timer: float = 0.0
var _visual: Polygon2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	if tuning == null:
		tuning = Tuning.new()
	_visual = Polygon2D.new()
	_visual.color = Color(0.35, 0.75, 1.0, 1.0)
	_visual.polygon = _circle_points(14.0, 20)
	add_child(_visual)
	# A small nose marker so the facing/movement read is clearer.
	# Parented to the body polygon so invulnerability blink hides both.
	var nose := Polygon2D.new()
	nose.name = "Nose"
	nose.color = Color(0.08, 0.15, 0.25, 1.0)
	nose.polygon = PackedVector2Array([Vector2(0.0, -18.0), Vector2(5.0, -8.0), Vector2(-5.0, -8.0)])
	_visual.add_child(nose)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := 260.0
	var accel := 1800.0
	if tuning != null:
		speed = tuning.player_speed
		accel = tuning.player_accel
	var target_velocity := input_dir * speed
	velocity = velocity.move_toward(target_velocity, accel * delta)
	move_and_slide()

	_fire_timer = maxf(0.0, _fire_timer - delta)
	var shoot_dir := _read_shoot_direction()
	if shoot_dir != Vector2.ZERO and _fire_timer <= 0.0:
		var interval := 0.35
		if tuning != null:
			interval = tuning.fire_interval
		_fire_timer = interval
		fired.emit(global_position + shoot_dir * 22.0, shoot_dir)

	_update_blink(delta)


func _read_shoot_direction() -> Vector2:
	if Input.is_action_pressed("shoot_right"):
		return Vector2.RIGHT
	if Input.is_action_pressed("shoot_left"):
		return Vector2.LEFT
	if Input.is_action_pressed("shoot_up"):
		return Vector2.UP
	if Input.is_action_pressed("shoot_down"):
		return Vector2.DOWN
	return Vector2.ZERO


func _update_blink(delta: float) -> void:
	if _visual == null:
		return
	var invulnerable := false
	if run_state != null:
		invulnerable = run_state.is_invulnerable()
	if invulnerable:
		_blink_timer += delta
		_visual.visible = int(_blink_timer * 12.0) % 2 == 0
	else:
		_blink_timer = 0.0
		_visual.visible = true


func request_damage(amount: int) -> void:
	if amount <= 0:
		return
	damage_requested.emit(amount)


func reset_for_run(start_position: Vector2) -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	_fire_timer = 0.0
	_blink_timer = 0.0
	if _visual != null:
		_visual.visible = true


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
