extends SceneTree

const RunStateScript = preload("res://scripts/logic/run_state.gd")
const TuningScript = preload("res://data/tuning.gd")

var _passed: int = 0
var _failed: int = 0
var _tuning: Tuning


func _initialize() -> void:
	_tuning = _make_tuning()

	_test_wave_counts()
	_test_killing_all_clears_wave()
	_test_advance_after_wave_3_wins()
	_test_damage_to_zero_loses()
	_test_health_clamps()
	_test_invulnerability_blocks_repeat_damage()
	_test_damage_ignored_when_won_or_lost()
	_test_reset_restores_everything()

	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _make_tuning() -> Tuning:
	var loaded := load("res://data/tuning.tres") as Tuning
	if loaded != null:
		return loaded
	var fallback := TuningScript.new() as Tuning
	return fallback


func _new_state() -> RunState:
	var state := RunStateScript.new() as RunState
	state.reset(_tuning)
	return state


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS %s" % name)
	else:
		_failed += 1
		if detail == "":
			print("FAIL %s" % name)
		else:
			print("FAIL %s: %s" % [name, detail])


func _test_wave_counts() -> void:
	var state := _new_state()
	var ok := true
	var detail := ""
	var c1 := state.start_wave(1)
	if c1 != 3 or state.enemies_remaining != 3 or state.current_wave != 1:
		ok = false
		detail = "wave1 count=%d remaining=%d current=%d" % [c1, state.enemies_remaining, state.current_wave]
	var c2 := state.start_wave(2)
	if c2 != 5 or state.enemies_remaining != 5 or state.current_wave != 2:
		ok = false
		detail = "wave2 count=%d remaining=%d current=%d" % [c2, state.enemies_remaining, state.current_wave]
	var c3 := state.start_wave(3)
	if c3 != 7 or state.enemies_remaining != 7 or state.current_wave != 3:
		ok = false
		detail = "wave3 count=%d remaining=%d current=%d" % [c3, state.enemies_remaining, state.current_wave]
	_check("wave_counts_3_5_7", ok, detail)


func _test_killing_all_clears_wave() -> void:
	var state := _new_state()
	state.start_wave(1)
	var before := state.is_wave_cleared()
	state.enemy_killed()
	state.enemy_killed()
	var mid := state.is_wave_cleared()
	state.enemy_killed()
	var after := state.is_wave_cleared()
	_check(
		"killing_all_clears_wave",
		not before and not mid and after and state.enemies_remaining == 0,
		"before=%s mid=%s after=%s remaining=%d" % [str(before), str(mid), str(after), state.enemies_remaining]
	)


func _test_advance_after_wave_3_wins() -> void:
	var state := _new_state()
	state.start_wave(1)
	state.advance()
	var between_ok := state.status == RunState.Status.BETWEEN_WAVES
	state.start_wave(3)
	for i in 7:
		state.enemy_killed()
	state.advance()
	_check(
		"advance_after_wave_3_wins",
		between_ok and state.status == RunState.Status.WON,
		"between_ok=%s status=%d" % [str(between_ok), int(state.status)]
	)


func _test_damage_to_zero_loses() -> void:
	var state := _new_state()
	for i in 6:
		state.damage(1)
		state.tick(_tuning.invuln_time + 0.01)
	_check(
		"damage_to_zero_loses",
		state.health == 0 and state.status == RunState.Status.LOST,
		"health=%d status=%d" % [state.health, int(state.status)]
	)


func _test_health_clamps() -> void:
	var state := _new_state()
	var at_max := state.health == state.max_health and state.health == 6
	state.damage(999)
	var clamped_low := state.health == 0
	# Negative damage must never heal or change health.
	var other := _new_state()
	var negative_ignored := not other.damage(-5) and other.health == other.max_health
	_check(
		"health_clamps_0_to_max",
		at_max and clamped_low and negative_ignored,
		"at_max=%s health_after_999=%d negative_ignored=%s" % [str(at_max), state.health, str(negative_ignored)]
	)


func _test_invulnerability_blocks_repeat_damage() -> void:
	var state := _new_state()
	var first := state.damage(1)
	var blocked := state.damage(1)
	var health_after_block := state.health
	state.tick(0.5)
	var still_blocked := state.damage(1)
	state.tick(0.6)
	var after_window := state.damage(1)
	_check(
		"invulnerability_blocks_repeat_damage",
		first and not blocked and health_after_block == 5 and not still_blocked and after_window and state.health == 4,
		"first=%s blocked=%s health=%d still_blocked=%s after=%s final=%d" % [
			str(first), str(blocked), health_after_block, str(still_blocked), str(after_window), state.health
		]
	)


func _test_damage_ignored_when_won_or_lost() -> void:
	var won_state := _new_state()
	won_state.start_wave(3)
	for i in 7:
		won_state.enemy_killed()
	won_state.advance()
	var won_health := won_state.health
	var won_blocked := not won_state.damage(1) and won_state.health == won_health

	var lost_state := _new_state()
	for i in 6:
		lost_state.damage(1)
		lost_state.tick(_tuning.invuln_time + 0.01)
	var lost_blocked := not lost_state.damage(1) and lost_state.health == 0

	_check(
		"damage_ignored_when_won_or_lost",
		won_state.status == RunState.Status.WON and won_blocked and lost_state.status == RunState.Status.LOST and lost_blocked,
		"won_status=%d won_blocked=%s lost_status=%d lost_blocked=%s" % [
			int(won_state.status), str(won_blocked), int(lost_state.status), str(lost_blocked)
		]
	)


func _test_reset_restores_everything() -> void:
	var state := _new_state()
	state.start_wave(2)
	state.enemy_killed()
	state.damage(1)
	state.tick(0.2)
	state.reset(_tuning)
	_check(
		"reset_restores_everything",
		state.current_wave == 0
		and state.enemies_remaining == 0
		and state.health == state.max_health
		and state.max_health == 6
		and state.invuln_timer == 0.0
		and not state.is_invulnerable()
		and state.status == RunState.Status.PLAYING
		and not state.is_wave_cleared(),
		"wave=%d remaining=%d health=%d/%d invuln=%f status=%d" % [
			state.current_wave, state.enemies_remaining, state.health, state.max_health, state.invuln_timer, int(state.status)
		]
	)
