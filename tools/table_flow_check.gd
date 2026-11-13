## Dev tool: plays one turn through the real screen and prints the step, the phase and what is enabled at each point.
##   godot --path . --script res://tools/table_flow_check.gd -- <scratch dir for the save backup>
## It starts a run through GameManager, which saves: the player's run.json and profile.json are put back afterwards.
extends SceneTree

var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _backup() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), "%s/%s.flowbak" % [_out, path.get_file()])


func _restore() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.PROFILE_PATH]:
		var real := ProjectSettings.globalize_path(path)
		var backup := "%s/%s.flowbak" % [_out, path.get_file()]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(real)
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, real)
			DirAccess.remove_absolute(backup)


func _state(label: String) -> void:
	var gm := root.get_node("GameManager")
	var t: TableSession = gm.session
	var scene := current_scene
	var bar: Node = scene.get_node("%TurnBar")
	var next: Button = bar.get("_next")
	var trade_ok: bool = not (scene.get_node("%TradePanel").get("_buy_buttons")[0] as Button).disabled
	var overlay: Node = scene.get_node("%TableOverlay")
	print("%-34s step=%d phase=%d day=%d  Next enabled=%s (\"%s\")  buy buttons enabled=%s  window=%s" % [
		label, bar.get("step"), t.phase, t.day, not next.disabled, next.text.replace("\n", " "), trade_ok, overlay.get("_mode")])


func _run() -> void:
	var gm := root.get_node("GameManager")
	_backup()
	for i in 10:
		await process_frame
	gm.start_run(RunConfig.make_table(ContentDb.character_by_id(&"saving_son"), 7))
	await create_timer(1.5).timeout
	_state("1 pre-market, news playing")
	await create_timer(3.6).timeout
	_state("1 pre-market, news landed")
	var bar: Node = current_scene.get_node("%TurnBar")
	bar.call("_on_next_pressed")
	await create_timer(0.4).timeout
	_state("2 market open (after Next)")
	bar.call("_on_next_pressed")
	await create_timer(1.0).timeout
	_state("3 after-market (after Next)")
	await create_timer(4.0).timeout
	_state("3 after-market, 4 s later (no auto)")
	bar.call("_on_next_pressed")
	await create_timer(0.2).timeout
	_state("4 next day (after Next)")
	await create_timer(1.2).timeout
	_state("1 pre-market, verdict window")
	current_scene.get_node("%TableOverlay").call("_close")
	await create_timer(1.0).timeout
	_state("1 pre-market, news playing again")
	await create_timer(3.6).timeout
	_state("1 pre-market, news landed again")
	bar.call("_on_next_pressed")
	await create_timer(0.4).timeout
	_state("2 market open, day 1")
	_restore()
	quit()
