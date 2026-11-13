## Dev tool: plays the first days of a table run in a real window and saves screenshots.
##   godot --path . --script res://tools/table_shot.gd -- <output dir> [character id] [seed]
extends SceneTree

var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var char_id := StringName(args[1]) if args.size() > 1 else &"insider_inu"
	var seed_value := int(args[2]) if args.size() > 2 else 123
	_run.call_deferred(char_id, seed_value)


func _wait(frames: int = 8) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(6)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


## This tool plays through GameManager, which writes user://run.json: keep the player's real save safe.
func _backup_save() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), "%s/%s.bak" % [_out, path.get_file()])


## Puts the player's own run and profile back (and removes what this tool wrote if there was nothing before).
func _restore_save() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.PROFILE_PATH]:
		var real := ProjectSettings.globalize_path(path)
		var backup := "%s/%s.bak" % [_out, path.get_file()]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(real)
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, real)
			DirAccess.remove_absolute(backup)


func _run(char_id: StringName, seed_value: int) -> void:
	var gm := root.get_node("GameManager")
	_backup_save()
	await _wait(10)
	gm.open_scene(gm.RUN_SETUP_SCENE)
	await _wait(80)
	await _shot("1_setup")
	gm.start_run(RunConfig.make_table(ContentDb.character_by_id(char_id), seed_value))
	await _wait(40)
	await _shot("2_action")
	var t := gm.session as TableSession
	t.set_call(RumorTier.Side.BELIEVE)
	t.buy_fraction(0, t.market.symbols()[1], 0.25)
	gm.table_refresh()
	gm.next_day()
	await create_timer(0.55).timeout
	await _shot("3a_reveal_mid")
	await create_timer(1.4).timeout
	await _shot("3b_reveal")
	gm.next_day()
	await create_timer(0.45).timeout
	await _shot("4a_stamp_in_the_air")
	await create_timer(0.2).timeout
	await _shot("4b_impact")
	await create_timer(0.5).timeout
	await _shot("4c_confetti")
	await create_timer(1.5).timeout
	await _shot("4d_result")
	for i in 7:
		t.set_call(RumorTier.Side.BELIEVE)
		gm.next_day()
		await _wait(2)
		gm.next_day()
		await _wait(2)
	await _wait(10)
	await _shot("5_boss_day")
	# Save, reload and carry on: the continued run must look the same.
	var before := t.net_worth()
	var day_before := t.day
	var ok: bool = gm.continue_run()
	await _wait(40)
	var t2 := gm.session as TableSession
	print("continue ok=", ok, " day ", day_before, "->", t2.day, " nw ", snappedf(before, 0.01), "->", snappedf(t2.net_worth(), 0.01))
	await _shot("6_continued")
	var guard := 0
	while gm.state == gm.State.PLAYING and guard < 200:
		t2.set_call(RumorTier.Side.BULLSHIT)
		gm.next_day()
		await _wait(1)
		guard += 1
	await _wait(60)
	print("run over at day ", t2.day, " rank ", t2.human_rank(), " fired ", t2.human_fired)
	await _shot("7_game_over")
	_restore_save()
	quit()
