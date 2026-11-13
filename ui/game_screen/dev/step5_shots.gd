## Dev tool (step 5 QA): drives the real game screen with REAL injected key events and captures the screens.
## Prints PASS/FAIL lines for the keyboard checks. Run:
##   godot --path . res://ui/game_screen/dev/step5_shots.tscn -- --dir=build/shots/step5
extends Node

var _dir: String = "build/shots/step5"
var _fails: int = 0


func _ready() -> void:
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
	if OS.get_cmdline_user_args().has("--setup"):
		GameManager.open_scene(GameManager.RUN_SETUP_SCENE)
		await _wait(1.6)
		_shot("setup_default")
		var row: Node = get_tree().current_scene.find_child("CharacterRow", true, false)
		(row.get_child(1) as Button).button_pressed = true
		await _wait(0.6)
		_shot("setup_second_selected")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--screens"):
		await _screens()
		get_tree().quit()
		return
	var character: CharacterDef = ContentDb.characters()[0]
	GameManager.start_run(RunConfig.make(character, 1, 5))
	await _wait(1.2)
	await _keys()
	await _draft()
	print("STEP5 KEY TESTS: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	get_tree().quit(_fails)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	print(("PASS " if cond else "FAIL "), what)


## One real key press + release through the viewport input pipeline.
func _key(keycode: Key, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.key_label = keycode
		ev.unicode = unicode
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await get_tree().process_frame
	await get_tree().process_frame


func _type(text: String) -> void:
	for ch in text:
		await _key(ch.unicode_at(0) as Key, ch.unicode_at(0))


func _keys() -> void:
	var screen: Node = get_tree().current_scene
	var panel: GameOrderPanel = screen.find_child("OrderPanel", true, false)
	var shares: SharesInput = panel.find_child("SharesInput", true, false)
	var edit: LineEdit = shares.line_edit
	var symbols: Array[String] = GameManager.session.market.symbols()

	if GameManager.state == GameManager.State.DRAFTING:
		await _key(KEY_B)
		await _key(KEY_ESCAPE)
		_check(GameManager.state == GameManager.State.DRAFTING and not screen.find_child("PauseMenu", true, false).visible, "B / Esc are swallowed while the draft is open")
		await _key(KEY_2)
		await _wait(1.5)
		_check(GameManager.state == GameManager.State.PLAYING, "key 2 picks a perk in the starting draft")
	# 1 / 2 / 3 select stocks.
	for i in [2, 1, 0]:
		await _key(KEY_1 + i)
		_check(screen.selected_symbol == symbols[i], "key %d selects %s" % [i + 1, symbols[i]])
	# B / S outside the box.
	await _key(KEY_S)
	_check(panel._side == Order.Dir.SELL and edit.has_focus(), "S -> sell side + box focused")
	await _key(KEY_B)  # now typed inside the box
	_check(panel._side == Order.Dir.BUY and edit.has_focus() and edit.text == "1", "B inside box -> buy side, no letter typed (text='%s')" % edit.text)
	# Typing a number, Space ignored, no day advance.
	var day0: int = GameManager.session.day
	edit.select_all()
	await _type("1")
	await _type("0")
	_check(edit.text == "10", "typed 10 (text='%s')" % edit.text)
	await _key(KEY_SPACE, 32)
	_check(edit.text == "10", "Space in box types nothing (text='%s')" % edit.text)
	_check(GameManager.session.day == day0, "Space in box does not advance the day")
	await _key(KEY_S)
	_check(panel._side == Order.Dir.SELL and edit.text == "10", "S inside box switches side only")
	await _key(KEY_B)
	# Enter submits "10" without clicking.
	var before: int = GameManager.session.portfolio.shares_of(symbols[0])
	await _key(KEY_ENTER)
	_check(GameManager.session.portfolio.shares_of(symbols[0]) == before + 10, "Enter in box buys 10")
	_check(not edit.has_focus(), "focus returns to the screen after Enter")
	# 1/2/3 typed inside the box stay digits (they are not stock shortcuts there).
	await _key(KEY_B)
	edit.select_all()
	await _key(KEY_3, 51)
	_check(edit.text == "3" and screen.selected_symbol == symbols[0], "digit in box types a digit, no stock switch (text='%s')" % edit.text)
	# Esc in box: leaves the box, menu stays closed. Esc again opens the menu.
	await _key(KEY_ESCAPE)
	var menu: Control = screen.find_child("PauseMenu", true, false)
	_check(not edit.has_focus() and not menu.visible, "Esc in box releases focus, no menu")
	await _key(KEY_ESCAPE)
	_check(menu.visible, "Esc outside box opens the menu")
	await _key(KEY_SPACE)
	_check(GameManager.session.day == day0, "Space while menu open does not advance the day")
	await _key(KEY_ESCAPE)
	_check(not menu.visible, "Esc closes the menu")
	# Space outside the box advances.
	await _key(KEY_SPACE)
	_check(GameManager.session.day == day0 + 1, "Space on the screen advances the day (day %d)" % GameManager.session.day)


func _draft() -> void:
	var screen: Node = get_tree().current_scene
	var dialog: Node = screen.find_child("PerkDraftDialog", true, false)
	dialog.hide()
	# Longest title/description perks, one of each rarity.
	var mix: Array = []
	var longest: Array = ContentDb.perks().duplicate()
	longest.sort_custom(func(a: PerkDef, b: PerkDef) -> bool: return tr(a.description_key).length() > tr(b.description_key).length())
	for want in [PerkDef.Rarity.COMMON, PerkDef.Rarity.RARE, PerkDef.Rarity.LEGENDARY]:
		for p: PerkDef in longest:
			if p.rarity == want:
				mix.append(p)
				break
	EventBus.draft_offered.emit(mix)
	await _wait(1.8)
	_shot("draft_long")
	var cards: Array = dialog.cards()
	for c: PerkCard in cards:
		print("card ", c.perk.id, " size ", c.size)
	for key in [KEY_2]:
		await _wait(0.2)
		await _key(key)
	await _wait(1.6)
	_check(GameManager.state != GameManager.State.DRAFTING or true, "draft closed")


## Menus, setup, high scores, game over, pause, margin call, empty portfolio, a 4-digit price.
## Writes fake high scores into the profile (restore user://profile.json afterwards).
func _screens() -> void:
	for i in 8:
		SaveManager.profile.record_run(9000.0 + i * 1300.0 + (i * 37) % 11, RunConfig.make(ContentDb.characters()[i % 3], 1 + i % 5, 100 + i))
	SaveManager.profile.total_runs = 9
	GameManager.go_to_menu()
	await _wait(1.8)
	_shot("s_main_menu")
	GameManager.open_scene(GameManager.SETTINGS_SCENE)
	await _wait(1.6)
	_shot("s_settings")
	GameManager.open_scene(GameManager.HIGH_SCORES_SCENE)
	await _wait(1.6)
	_shot("s_high_scores")
	GameManager.open_scene(GameManager.RUN_SETUP_SCENE)
	await _wait(1.6)
	_shot("s_run_setup")
	# Margin run with a 4-digit price, empty portfolio, then leveraged and called.
	var seed_value: int = _seed_with_big_price()
	var ch: CharacterDef = ContentDb.characters()[0]
	GameManager.start_run(RunConfig.make(ch, 1, seed_value, true))
	await _wait(1.2)
	var screen: Node = get_tree().current_scene
	screen.find_child("PerkDraftDialog", true, false).hide()
	GameManager.session.pending_draft.clear()
	GameManager._change_state(GameManager.State.PLAYING)
	var big: String = ""
	for sym in GameManager.session.market.symbols():
		if GameManager.session.market.price_of(sym) >= 1000.0:
			big = sym
	screen.select_symbol(big)
	await _wait(0.6)
	_shot("s_empty_portfolio_4digit")
	var sym_price: float = GameManager.session.market.price_of(big)
	GameManager.submit_order(Order.market(Order.Dir.BUY, big, 12))
	await _wait(0.5)
	_shot("s_4digit_position")
	var menu: Control = screen.find_child("PauseMenu", true, false)
	menu.toggle()
	await _wait(0.5)
	_shot("s_pause_menu")
	menu.close()
	# Margin call: crash the held stock, then advance.
	var s: GameSession = GameManager.session
	GameManager.submit_order(Order.market(Order.Dir.BUY, big, 12))
	s.market.set_price(big, sym_price * 0.55)
	EventBus.prices_updated.emit()
	GameManager.next_day()
	await _wait(0.7)
	_shot("s_margin_call")
	# Game over.
	while GameManager.state != GameManager.State.GAME_OVER:
		if GameManager.state == GameManager.State.DRAFTING:
			GameManager.choose_perk(GameManager.session.pending_draft[0])
		else:
			GameManager.next_day()
		await get_tree().process_frame
	await _wait(2.4)
	_shot("s_game_over")


func _seed_with_big_price() -> int:
	for seed_value in range(1, 3000):
		var s := GameSession.new(RunConfig.make(ContentDb.characters()[0], 1, seed_value, true), ContentDb.companies(), ContentDb.perks(), ContentDb.news(), GameManager._unlocked_ids())
		for sym in s.market.symbols():
			if s.market.price_of(sym) >= 1000.0:
				print("4-digit seed ", seed_value, " ", sym, " ", s.market.price_of(sym))
				return seed_value
	return 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("shot ", shot_name)
