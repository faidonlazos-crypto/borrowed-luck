class_name Enemy extends CharacterBody2D

signal died

@export var tuning: Tuning

var target_player: Player
var room: Room
var health: int = 3
var move_speed: float = 110.0
var contact_damage: int = 1

var _is_dead: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _contact_timer: float = 0.0
var _repath_timer: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _visual: Polygon2D
var _hurt_area: Area2D

const BASE_COLOR: Color = Color(0.9, 0.3, 0.25, 1.0)
const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)


func setup(p_tuning: Tuning, p_target: Player, p_room: Room = null) -> void:
	tuning = p_tuning
	target_player = p_target
	room = p_room
	_apply_tuning()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	_apply_tuning()
	_visual = Polygon2D.new()
	_visual.color = BASE_COLOR
	_visual.polygon = _circle_points(14.0, 18)
	add_child(_visual)
	_hurt_area = get_node_or_null("HurtBox") as Area2D


func _apply_tuning() -> void:
	if tuning != null:
		health = tuning.enemy_health
		move_speed = tuning.enemy_speed
		contact_damage = tuning.enemy_contact_damage


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0 and _visual != null:
			_visual.color = BASE_COLOR

	var desired := Vector2.ZERO
	if target_player != null and is_instance_valid(target_player):
		var to_player := target_player.global_position - global_position
		if to_player.length() > 4.0:
			desired = _steer_direction(delta) * move_speed
	desired += _separation() * move_speed * 0.6

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	velocity = desired + _knockback_velocity
	move_and_slide()

	_try_contact_damage(delta)


## Direction toward the player: straight line when the way is clear,
## otherwise follow an A* path around rocks (re-planned every 0.25 s).
func _steer_direction(delta: float) -> Vector2:
	var target := target_player.global_position
	if room == null or _line_clear(target):
		_path = PackedVector2Array()
		return (target - global_position).normalized()
	_repath_timer -= delta
	if _repath_timer <= 0.0 or _path_index >= _path.size():
		_repath_timer = 0.25
		_path = room.find_path(global_position, target)
		_path_index = 1 if _path.size() > 1 else 0
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 10.0:
		_path_index += 1
	if _path_index < _path.size():
		return (_path[_path_index] - global_position).normalized()
	return (target - global_position).normalized()


func _line_clear(target: Vector2) -> bool:
	# Cast a ray on either side of the body so the full width clears rocks.
	var space := get_world_2d().direct_space_state
	var dir := (target - global_position).normalized()
	var side := Vector2(-dir.y, dir.x) * 14.0
	for offset in [Vector2.ZERO, side, -side]:
		var q := PhysicsRayQueryParameters2D.create(global_position + offset, target + offset, 1)
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## Push away from nearby enemies so groups spread instead of stacking.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node2D):
			continue
		var away: Vector2 = global_position - (other as Node2D).global_position
		var d := away.length()
		if d < 34.0:
			if d < 0.5:
				away = Vector2.RIGHT.rotated(randf() * TAU)
				d = 0.5
			push += away.normalized() * (1.0 - d / 34.0)
	return push.limit_length(1.0)


func _try_contact_damage(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if _contact_timer > 0.0:
		return
	if _hurt_area == null:
		_hurt_area = get_node_or_null("HurtBox") as Area2D
	if _hurt_area == null:
		return
	for body in _hurt_area.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("request_damage"):
			body.call("request_damage", contact_damage)
			_contact_timer = 0.25
			return


func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO) -> void:
	if _is_dead or amount <= 0:
		return
	health -= amount
	_flash_timer = 0.09
	if _visual != null:
		_visual.color = FLASH_COLOR
	var strength := 260.0
	if tuning != null:
		strength = tuning.knockback
	if from_direction != Vector2.ZERO:
		_knockback_velocity = from_direction.normalized() * strength
	if health <= 0:
		_die()


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit()
	queue_free()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
