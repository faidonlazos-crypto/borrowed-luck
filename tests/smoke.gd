extends SceneTree

const TIMEOUT_MS: int = 25000

var _main: Node


func _initialize() -> void:
	Callable(self, "_run").call_deferred()


func _run() -> void:
	var start_ms := Time.get_ticks_msec()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		print("SMOKE FAIL: could not load res://scenes/main.tscn")
		quit(1)
		return

	_main = packed.instantiate()
	if _main == null:
		print("SMOKE FAIL: could not instantiate main scene")
		quit(1)
		return
	root.add_child(_main)

	await process_frame
	await process_frame
	if not _wait_not_timed_out(start_ms):
		return

	# Force-clear waves until the run is won.
	var won := false
	while Time.get_ticks_msec() - start_ms < TIMEOUT_MS:
		var state := _get_state()
		if state == null:
			print("SMOKE FAIL: get_run_state() returned null")
			quit(1)
			return
		if state.status == RunState.Status.WON:
			won = true
			break
		_main.call("debug_kill_all_enemies")
		await create_timer(0.25).timeout

	if not won:
		var final_state := _get_state()
		var status_text := "null"
		if final_state != null:
			status_text = str(int(final_state.status))
		print("SMOKE FAIL: did not reach WON before timeout, status=%s" % status_text)
		quit(1)
		return

	# Restart must restore a fresh, non-won run.
	_main.call("restart_run")
	await process_frame
	await process_frame
	var restarted := _get_state()
	if restarted == null:
		print("SMOKE FAIL: get_run_state() returned null after restart")
		quit(1)
		return
	if restarted.status == RunState.Status.WON or restarted.health != restarted.max_health:
		print(
			"SMOKE FAIL: restart did not restore run, status=%d health=%d/%d"
			% [int(restarted.status), restarted.health, restarted.max_health]
		)
		quit(1)
		return

	# Forcing health to 0 must lose the run.
	_main.call("debug_set_health", 0)
	await process_frame
	var lost_state := _get_state()
	if lost_state == null or lost_state.status != RunState.Status.LOST:
		var lost_status := "null"
		if lost_state != null:
			lost_status = str(int(lost_state.status))
		print("SMOKE FAIL: debug_set_health(0) did not reach LOST, status=%s" % lost_status)
		quit(1)
		return

	print("SMOKE PASS")
	quit(0)


func _get_state() -> RunState:
	if _main == null:
		return null
	return _main.call("get_run_state") as RunState


func _wait_not_timed_out(start_ms: int) -> bool:
	if Time.get_ticks_msec() - start_ms >= TIMEOUT_MS:
		print("SMOKE FAIL: hard timeout")
		quit(1)
		return false
	return true
