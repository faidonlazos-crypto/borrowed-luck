extends SceneTree

const RunStateScript = preload("res://scripts/logic/run_state.gd")
const LuckRulesScript = preload("res://scripts/logic/luck_rules.gd")
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
	_test_start_wave_extra()
	_test_heal_returns_applied_and_clamps()
	_test_luck_roll_boundary()
	_test_luck_ordinary_heal_at_full_zero()
	_test_luck_fast_hands_cleared_on_wave_end()
	_test_luck_once_per_wave()
	_test_luck_borrow_rejected_at_full()
	_test_luck_borrow_heals_and_adds_debt()
	_test_luck_debt_applies_to_next_wave_once()
	_test_luck_borrow_in_wave_2_makes_wave_3_ten()
	_test_luck_no_use_in_wave_3()
	_test_luck_no_use_when_not_playing()
	_test_luck_reset_clears_all()

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


func _new_luck() -> LuckRules:
	var luck := LuckRulesScript.new(_tuning) as LuckRules
	return luck


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


func _test_start_wave_extra() -> void:
	var state := _new_state()
	var with_extra := state.start_wave(1, 3)
	var extra_ok := with_extra == 6 and state.enemies_remaining == 6 and state.current_wave == 1
	var plain := state.start_wave(2)
	var plain_ok := plain == 5 and state.enemies_remaining == 5
	var negative := state.start_wave(1, -2)
	var negative_ok := negative == 3 and state.enemies_remaining == 3
	_check("start_wave_extra_adds_to_count", extra_ok and plain_ok and negative_ok,
		"extra=%d plain=%d negative=%d" % [with_extra, plain, negative])


func _test_heal_returns_applied_and_clamps() -> void:
	var state := _new_state()
	state.health = 4
	var applied := state.heal(1)
	var clamped := state.heal(99)
	var at_full := state.heal(1)
	var zero := state.heal(0)
	var negative := state.heal(-3)
	_check("heal_clamped_returns_applied",
		applied == 1 and clamped == 1 and at_full == 0 and zero == 0 and negative == 0 and state.health == 6,
		"applied=%d clamped=%d at_full=%d health=%d" % [applied, clamped, at_full, state.health])


func _test_luck_roll_boundary() -> void:
	var heal_state := _new_state()
	heal_state.start_wave(1)
	heal_state.health = 4
	var heal_luck := _new_luck()
	var heal_result: Dictionary = heal_luck.use_ordinary(heal_state, 0.49)
	var heal_ok: bool = bool(heal_result.get("ok", false)) and str(heal_result.get("kind", "")) == "heal" \
		and int(heal_result.get("healed", -1)) == 1 and int(heal_result.get("debt_added", -1)) == 0 \
		and heal_state.health == 5 and not heal_luck.fast_hands and heal_luck.pending_debt == 0
	var fast_state := _new_state()
	fast_state.start_wave(1)
	fast_state.health = 4
	var fast_luck := _new_luck()
	var fast_result: Dictionary = fast_luck.use_ordinary(fast_state, 0.5)
	var fast_ok: bool = bool(fast_result.get("ok", false)) and str(fast_result.get("kind", "")) == "fast_hands" \
		and int(fast_result.get("healed", -1)) == 0 and fast_state.health == 4 and fast_luck.fast_hands
	_check("luck_roll_boundary_049_heal_050_fast_hands", heal_ok and fast_ok,
		"heal=%s health=%d fast=%s fast_hands=%s" % [str(heal_result), heal_state.health, str(fast_result), str(fast_luck.fast_hands)])


func _test_luck_ordinary_heal_at_full_zero() -> void:
	var state := _new_state()
	state.start_wave(1)
	var luck := _new_luck()
	var result: Dictionary = luck.use_ordinary(state, 0.0)
	_check("luck_heal_at_full_is_zero_but_allowed",
		bool(result.get("ok", false)) and int(result.get("healed", -1)) == 0 and state.health == 6 and luck.used_this_wave,
		"result=%s health=%d used=%s" % [str(result), state.health, str(luck.used_this_wave)])


func _test_luck_fast_hands_cleared_on_wave_end() -> void:
	var state := _new_state()
	state.start_wave(1)
	var luck := _new_luck()
	luck.use_ordinary(state, 0.9)
	var active := luck.fast_hands
	luck.on_wave_end()
	var cleared := not luck.fast_hands and not luck.used_this_wave
	state.start_wave(2)
	state.health = 4
	var again: Dictionary = luck.use_ordinary(state, 0.1)
	_check("luck_fast_hands_cleared_on_wave_end", active and cleared and bool(again.get("ok", false)),
		"active=%s cleared=%s again=%s" % [str(active), str(cleared), str(again)])


func _test_luck_once_per_wave() -> void:
	var state := _new_state()
	state.start_wave(1)
	state.health = 4
	var luck := _new_luck()
	var first: Dictionary = luck.use_ordinary(state, 0.1)
	var second: Dictionary = luck.use_ordinary(state, 0.1)
	var third: Dictionary = luck.use_borrowed(state)
	_check("luck_once_per_wave",
		bool(first.get("ok", false)) and not bool(second.get("ok", true)) and str(second.get("reason", "")) == "already_used" \
		and not bool(third.get("ok", true)) and state.health == 5 and not luck.fast_hands and luck.pending_debt == 0,
		"first=%s second=%s third=%s health=%d" % [str(first), str(second), str(third), state.health])


func _test_luck_borrow_rejected_at_full() -> void:
	var state := _new_state()
	state.start_wave(1)
	var luck := _new_luck()
	var rejected: Dictionary = luck.use_borrowed(state)
	var rejected_ok := not bool(rejected.get("ok", true)) and str(rejected.get("reason", "")) == "full_health" \
		and state.health == 6 and luck.pending_debt == 0 and not luck.used_this_wave
	var after: Dictionary = luck.use_ordinary(state, 0.1)
	_check("luck_borrow_rejected_at_full", rejected_ok and bool(after.get("ok", false)),
		"rejected=%s after=%s" % [str(rejected), str(after)])


func _test_luck_borrow_heals_and_adds_debt() -> void:
	var state := _new_state()
	state.start_wave(1)
	state.health = 3
	var luck := _new_luck()
	var result: Dictionary = luck.use_borrowed(state)
	var applied := bool(result.get("ok", false)) and str(result.get("kind", "")) == "borrowed" \
		and int(result.get("healed", -1)) == 2 and int(result.get("debt_added", -1)) == 3 \
		and state.health == 5 and luck.pending_debt == 3
	var consumed := luck.consume_debt()
	var consumed_again := luck.consume_debt()
	_check("luck_borrow_heals_adds_debt_consumed_once",
		applied and consumed == 3 and consumed_again == 0 and luck.pending_debt == 0,
		"result=%s consumed=%d again=%d" % [str(result), consumed, consumed_again])


func _test_luck_debt_applies_to_next_wave_once() -> void:
	var state := _new_state()
	state.start_wave(1)
	state.health = 4
	var luck := _new_luck()
	luck.use_borrowed(state)
	var wave_2 := state.start_wave(2, luck.consume_debt())
	var wave_3 := state.start_wave(3, luck.consume_debt())
	_check("luck_debt_wave2_5_plus_3_wave3_back_to_7",
		wave_2 == 8 and state.current_wave == 3 and wave_3 == 7,
		"wave2=%d wave3=%d" % [wave_2, wave_3])


func _test_luck_borrow_in_wave_2_makes_wave_3_ten() -> void:
	var state := _new_state()
	state.start_wave(2)
	state.health = 4
	var luck := _new_luck()
	luck.on_wave_end()
	var borrowed: Dictionary = luck.use_borrowed(state)
	var wave_3 := state.start_wave(3, luck.consume_debt())
	_check("luck_borrow_wave2_wave3_is_10",
		bool(borrowed.get("ok", false)) and wave_3 == 10 and state.enemies_remaining == 10,
		"borrowed=%s wave3=%d" % [str(borrowed), wave_3])


func _test_luck_no_use_in_wave_3() -> void:
	var state := _new_state()
	state.start_wave(3)
	state.health = 4
	var luck := _new_luck()
	var ordinary: Dictionary = luck.use_ordinary(state, 0.1)
	var borrowed: Dictionary = luck.use_borrowed(state)
	_check("luck_no_use_in_wave_3",
		not bool(ordinary.get("ok", true)) and not bool(borrowed.get("ok", true)) \
		and str(ordinary.get("reason", "")) != "" and state.health == 4 \
		and not luck.fast_hands and luck.pending_debt == 0 and not luck.used_this_wave,
		"ordinary=%s borrowed=%s health=%d" % [str(ordinary), str(borrowed), state.health])


func _test_luck_no_use_when_not_playing() -> void:
	var between_state := _new_state()
	between_state.start_wave(1)
	between_state.mark_between_waves()
	between_state.health = 4
	var between_luck := _new_luck()
	var between: Dictionary = between_luck.use_ordinary(between_state, 0.1)
	var won_state := _new_state()
	won_state.start_wave(3)
	for i in 7:
		won_state.enemy_killed()
	won_state.advance()
	won_state.health = 4
	var won_luck := _new_luck()
	var won: Dictionary = won_luck.use_borrowed(won_state)
	var lost_state := _new_state()
	for i in 6:
		lost_state.damage(1)
		lost_state.tick(_tuning.invuln_time + 0.01)
	var lost_luck := _new_luck()
	var lost: Dictionary = lost_luck.use_ordinary(lost_state, 0.1)
	_check("luck_no_use_when_won_lost_or_between",
		between_state.status == RunState.Status.BETWEEN_WAVES and not bool(between.get("ok", true)) \
		and won_state.status == RunState.Status.WON and not bool(won.get("ok", true)) \
		and lost_state.status == RunState.Status.LOST and not bool(lost.get("ok", true)) \
		and between_state.health == 4 and won_state.health == 4 and lost_state.health == 0,
		"between=%s won=%s lost=%s" % [str(between), str(won), str(lost)])


func _test_luck_reset_clears_all() -> void:
	var state := _new_state()
	state.start_wave(1)
	var luck := _new_luck()
	luck.use_ordinary(state, 0.9)
	luck.on_wave_end()
	state.start_wave(2)
	state.health = 4
	luck.use_borrowed(state)
	var dirty := luck.pending_debt == 3 and luck.used_this_wave
	luck.reset()
	var cleared := not luck.fast_hands and luck.pending_debt == 0 and not luck.used_this_wave and luck.consume_debt() == 0
	var fresh_state := _new_state()
	fresh_state.start_wave(1)
	fresh_state.health = 4
	var again: Dictionary = luck.use_ordinary(fresh_state, 0.1)
	_check("luck_reset_clears_all", dirty and cleared and bool(again.get("ok", false)),
		"dirty=%s cleared=%s again=%s" % [str(dirty), str(cleared), str(again)])
