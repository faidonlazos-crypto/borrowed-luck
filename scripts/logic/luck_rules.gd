class_name LuckRules extends RefCounted

# Pure luck-machine rules (no nodes). The run controller owns when waves
# start/end; this class only decides whether a use is legal and applies it.
# Success: {"ok": true, "kind": String, "healed": int, "debt_added": int}
# Failure: {"ok": false, "reason": String} and nothing changes.

var ordinary_heal: int = 1
var ordinary_heal_chance: float = 0.5
var fast_hands_mult: float = 0.7
var borrow_heal: int = 2
var borrow_debt: int = 3
var machine_waves: Array[int] = [1, 2]

var fast_hands: bool = false
var pending_debt: int = 0
var used_this_wave: bool = false


func _init(tuning: Tuning = null) -> void:
	if tuning != null:
		_apply_tuning(tuning)


func _apply_tuning(tuning: Tuning) -> void:
	ordinary_heal = maxi(0, tuning.ordinary_heal)
	ordinary_heal_chance = clampf(tuning.ordinary_heal_chance, 0.0, 1.0)
	fast_hands_mult = tuning.fast_hands_mult
	borrow_heal = maxi(0, tuning.borrow_heal)
	borrow_debt = maxi(0, tuning.borrow_debt)
	machine_waves.clear()
	machine_waves.append_array(tuning.machine_waves)
	if machine_waves.is_empty():
		machine_waves = [1, 2]


func reset() -> void:
	fast_hands = false
	pending_debt = 0
	used_this_wave = false


func on_wave_end() -> void:
	fast_hands = false
	used_this_wave = false


func consume_debt() -> int:
	var debt := pending_debt
	pending_debt = 0
	return debt


func is_fast_hands_active() -> bool:
	return fast_hands


func fire_interval_mult() -> float:
	return fast_hands_mult if fast_hands else 1.0


func is_eligible_wave(wave: int) -> bool:
	return machine_waves.has(wave)


func can_use(state: RunState) -> bool:
	return _blocked_reason(state) == ""


## Public reason a use is blocked ("" when usable), for HUD hint text.
func blocked_reason(state: RunState) -> String:
	return _blocked_reason(state)


func _blocked_reason(state: RunState) -> String:
	if state == null:
		return "no_state"
	if state.status != RunState.Status.PLAYING:
		return "not_playing"
	if not is_eligible_wave(state.current_wave):
		return "wave_not_eligible"
	if used_this_wave:
		return "already_used"
	return ""


func use_ordinary(state: RunState, roll: float) -> Dictionary:
	var blocked := _blocked_reason(state)
	if blocked != "":
		return {"ok": false, "reason": blocked}
	used_this_wave = true
	if roll < ordinary_heal_chance:
		var healed := state.heal(ordinary_heal)
		return {"ok": true, "kind": "heal", "healed": healed, "debt_added": 0}
	fast_hands = true
	return {"ok": true, "kind": "fast_hands", "healed": 0, "debt_added": 0}


func use_borrowed(state: RunState) -> Dictionary:
	var blocked := _blocked_reason(state)
	if blocked != "":
		return {"ok": false, "reason": blocked}
	if state.health >= state.max_health:
		return {"ok": false, "reason": "full_health"}
	used_this_wave = true
	var healed := state.heal(borrow_heal)
	pending_debt += borrow_debt
	return {"ok": true, "kind": "borrowed", "healed": healed, "debt_added": borrow_debt}
