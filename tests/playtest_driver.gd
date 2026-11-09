extends Node
## Scripted playtest driver (autoload). Inert unless the game is started with
##   -- --playtest=<script.json> --out=<dir>
## Script: {"steps":[{"at":1.0,"press":"move_right"},{"at":2.0,"release":"move_right"},
##   {"at":2.5,"shot":"name"},{"at":3.0,"call":"debug_kill_all_enemies"},{"at":20,"quit":true}],
##   "log_every":0.25}
## Writes <out>/<name>.png screenshots and <out>/log.jsonl state lines.

var _active: bool = false
var _steps: Array = []
var _t: float = 0.0
var _log_every: float = 0.25
var _log_t: float = 0.0
var _out: String = ""
var _log: FileAccess
var _bot: bool = false
var _bot_held: Dictionary = {}
var _quit_on_end: bool = false
var _end_timer: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var script_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playtest="):
			script_path = arg.substr(11)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	if script_path == "":
		return
	var text := FileAccess.get_file_as_string(script_path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("playtest: bad script " + script_path)
		get_tree().quit(2)
		return
	_steps = data.get("steps", [])
	_steps.sort_custom(func(a, b): return float(a.get("at", 0)) < float(b.get("at", 0)))
	_log_every = float(data.get("log_every", 0.25))
	_quit_on_end = bool(data.get("quit_on_end", false))
	if _out == "":
		_out = OS.get_user_data_dir() + "/playtest"
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out + "/log.jsonl", FileAccess.WRITE)
	# Ignore the real keyboard/mouse during a scripted run so a person typing
	# into the focused window cannot steer the test.
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	_active = true
	print("PLAYTEST start, steps=", _steps.size(), " out=", _out)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_log_t += delta
	if _log_t >= _log_every:
		_log_t = 0.0
		_write_state("tick")
	while not _steps.is_empty() and float(_steps[0].get("at", 0)) <= _t:
		var step: Dictionary = _steps.pop_front()
		_run_step(step)
	if _bot and not get_tree().paused:
		_bot_tick()
	if _quit_on_end:
		var main := get_tree().current_scene
		if main != null and main.has_method("get_run_state"):
			var rs = main.get_run_state()
			if rs != null and (rs.status == 2 or rs.status == 3):
				if _end_timer < 0.0:
					_end_timer = 1.0
					_write_state("end")
				_end_timer -= delta
				if _end_timer <= 0.0:
					_run_step({"shot": "zz_end", "quit": true})
					_quit_on_end = false


func _run_step(step: Dictionary) -> void:
	if step.has("bot"):
		_bot = bool(step["bot"])
		if not _bot:
			_bot_set({})
	if step.has("expect"):
		# {"expect": {"wave": 2, "remaining": 8}} compares against the last state
		# snapshot fields (see _state()); mismatch logs tag expect_fail:... which
		# tools/detect.py turns into a FAIL.
		var st := _state()
		var exp: Dictionary = step["expect"]
		for k in exp.keys():
			var same := false
			if st.has(k):
				var a = st[k]
				var b = exp[k]
				if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
					same = is_equal_approx(float(a), float(b))
				else:
					same = str(a) == str(b)
			if not same:
				_write_state("expect_fail:%s want=%s got=%s" % [k, str(exp[k]), str(st.get(k, "<missing>"))])
			else:
				_write_state("expect_ok:%s=%s" % [k, str(exp[k])])
	if step.has("press"):
		_send_action(String(step["press"]), true)
	if step.has("release"):
		_send_action(String(step["release"]), false)
	if step.has("tap"):
		_send_action(String(step["tap"]), true)
		await get_tree().process_frame
		await get_tree().process_frame
		_send_action(String(step["tap"]), false)
	if step.has("call"):
		var main := get_tree().current_scene
		var args: Array = step.get("args", [])
		if main != null and main.has_method(String(step["call"])):
			main.callv(String(step["call"]), args)
		else:
			_write_state("missing_method:" + String(step["call"]))
	if step.has("shot"):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _out + "/" + String(step["shot"]) + ".png"
		img.save_png(path)
		_write_state("shot:" + String(step["shot"]))
	if step.get("quit", false):
		_write_state("quit")
		if _log != null:
			_log.close()
		print("PLAYTEST done")
		get_tree().quit(0)


func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Simple autoplayer: keep distance from the nearest enemy, line up on one
## axis and shoot along it. Good enough to prove waves can be cleared by play.
func _bot_tick() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Vector2 = (players[0] as Node2D).global_position
	var nearest: Node2D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and not e.is_queued_for_deletion():
			var d := p.distance_to(e.global_position)
			if d < best:
				best = d
				nearest = e
	var want := {}
	if nearest != null:
		var to := nearest.global_position - p
		# shoot along the better-aligned axis
		if absf(to.y) < 22.0:
			want["shoot_right" if to.x > 0 else "shoot_left"] = true
		elif absf(to.x) < 22.0:
			want["shoot_down" if to.y > 0 else "shoot_up"] = true
		var move := Vector2.ZERO
		if best < 150.0:
			move = -to.normalized()
		else:
			# slide sideways to line up on the closer axis
			if absf(to.x) < absf(to.y):
				move.x = signf(to.x)
			else:
				move.y = signf(to.y)
		# stay away from walls
		var center := Vector2(640, 360)
		if p.x < 90 or p.x > 1190 or p.y < 90 or p.y > 630:
			move += (center - p).normalized()
		if move.x > 0.3: want["move_right"] = true
		if move.x < -0.3: want["move_left"] = true
		if move.y > 0.3: want["move_down"] = true
		if move.y < -0.3: want["move_up"] = true
	_bot_set(want)


func _bot_set(want: Dictionary) -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "shoot_up", "shoot_down", "shoot_left", "shoot_right"]:
		var on := want.has(a)
		if on != _bot_held.get(a, false):
			_bot_held[a] = on
			_send_action(a, on)


func _write_state(tag: String) -> void:
	if _log == null:
		return
	var d := _state()
	d["tag"] = tag
	_log.store_line(JSON.stringify(d))
	_log.flush()


## Snapshot of game state. Features may add fields here (e.g. debt, machine
## uses) — if main has get_debug_state() -> Dictionary, it is merged in.
func _state() -> Dictionary:
	var d := {"t": snappedf(_t, 0.01), "paused": get_tree().paused}
	var main := get_tree().current_scene
	if main != null and main.has_method("get_run_state"):
		var rs = main.get_run_state()
		if rs != null:
			d["status"] = rs.status
			d["wave"] = rs.current_wave
			d["remaining"] = rs.enemies_remaining
			d["hp"] = rs.health
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node2D = players[0]
		d["player"] = [roundi(p.global_position.x), roundi(p.global_position.y)]
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and not e.is_queued_for_deletion():
			enemies.append([roundi(e.global_position.x), roundi(e.global_position.y)])
	d["enemies"] = enemies
	if main != null and main.has_method("get_debug_state"):
		var extra = main.get_debug_state()
		if typeof(extra) == TYPE_DICTIONARY:
			d.merge(extra, true)
	return d
