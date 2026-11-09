class_name RunState extends RefCounted

enum Status { PLAYING, BETWEEN_WAVES, WON, LOST }

var status: Status = Status.PLAYING
var current_wave: int = 0
var enemies_remaining: int = 0
var health: int = 6
var max_health: int = 6
var invuln_timer: float = 0.0
var invuln_time: float = 1.0
var wave_counts: Array[int] = [3, 5, 7]


func _init(tuning: Tuning = null) -> void:
	if tuning != null:
		reset(tuning)


func reset(tuning: Tuning = null) -> void:
	if tuning != null:
		max_health = maxi(1, tuning.player_max_health)
		invuln_time = maxf(0.0, tuning.invuln_time)
		wave_counts.clear()
		wave_counts.append_array(tuning.wave_counts)
	if wave_counts.is_empty():
		wave_counts = [3, 5, 7]
	health = max_health
	current_wave = 0
	enemies_remaining = 0
	invuln_timer = 0.0
	status = Status.PLAYING


func get_total_waves() -> int:
	return wave_counts.size()


func start_wave(n: int) -> int:
	if status == Status.WON or status == Status.LOST:
		return 0
	if n < 1:
		n = 1
	if n > wave_counts.size():
		current_wave = wave_counts.size()
		enemies_remaining = 0
		status = Status.WON
		return 0
	current_wave = n
	enemies_remaining = wave_counts[n - 1]
	status = Status.PLAYING
	return enemies_remaining


func enemy_killed() -> void:
	if enemies_remaining > 0:
		enemies_remaining -= 1


func damage(amount: int) -> bool:
	if status != Status.PLAYING:
		return false
	if amount <= 0:
		return false
	if invuln_timer > 0.0:
		return false
	health = clampi(health - amount, 0, max_health)
	invuln_timer = invuln_time
	if health <= 0:
		health = 0
		status = Status.LOST
	return true


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)


func is_wave_cleared() -> bool:
	return current_wave > 0 and enemies_remaining <= 0


func is_invulnerable() -> bool:
	return invuln_timer > 0.0


func mark_between_waves() -> void:
	if status != Status.WON and status != Status.LOST:
		status = Status.BETWEEN_WAVES


func advance() -> void:
	if status == Status.WON or status == Status.LOST:
		return
	if current_wave >= wave_counts.size():
		enemies_remaining = 0
		status = Status.WON
	else:
		status = Status.BETWEEN_WAVES
