## Dev tool: plays the real flow (menu -> setup -> game -> 60 days -> game over) through GameManager and
## saves a PNG of each stage. Run: godot --path . res://ui/game_screen/dev/flow_shots.tscn -- --dir=build/shots/step3
extends Node

var _dir: String = "build/shots/step3"


func _ready() -> void:
	# The scene itself is replaced by the first scene change, so run from a node under the root.
	if get_parent() != get_tree().root or not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			_dir = a.trim_prefix("--dir=")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameManager.go_to_menu()
	await _wait(2.0)
	_shot("flow_1_menu")
	GameManager.open_scene(GameManager.RUN_SETUP_SCENE)
	await _wait(1.8)
	_shot("flow_2_setup")
	var character: CharacterDef = ContentDb.characters()[0]
	GameManager.start_run(RunConfig.make(character, 1, 5))
	await _wait(1.0)
	_shot("flow_3_game_start")
	var guard: int = 0
	while GameManager.state != GameManager.State.GAME_OVER and guard < 200:
		guard += 1
		if GameManager.state == GameManager.State.DRAFTING:
			GameManager.choose_perk(GameManager.session.pending_draft[0])
		else:
			if GameManager.session.day == 30:
				_shot("flow_4_day30")
			GameManager.next_day()
		await get_tree().process_frame
	await _wait(2.2)
	_shot("flow_5_game_over")
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
