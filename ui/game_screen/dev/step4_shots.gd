## Dev tool: captures the step 4 pop-ups on the real game screen (perk draft with a common/rare/legendary
## mix, news pop-ups, confirm/debunk stamps, typed order quantity).
## Run: godot --path . res://ui/game_screen/dev/step4_shots.tscn -- --dir=build/shots/step4 [--w=1280 --h=720]
extends Node

var _dir: String = "build/shots/step4"


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
	var character: CharacterDef = ContentDb.characters()[0]
	GameManager.start_run(RunConfig.make(character, 1, _find_seed(character)))
	await _wait(1.2)
	for i in 6:
		GameManager.next_day()
		if GameManager.state == GameManager.State.DRAFTING:
			GameManager.choose_perk(GameManager.session.pending_draft[0])
		await _wait(0.1)
	await _wait(1.5)
	var screen: Node = get_tree().current_scene
	screen.find_child("PerkDraftDialog", true, false).hide()  # a draft may have been auto-answered above
	var popups: GameNewsPopups = screen.find_child("NewsPopups", true, false)
	popups.clear_all()
	await _wait(0.4)

	for sym in GameManager.session.market.symbols():
		GameManager.submit_order(Order.market(Order.Dir.BUY, sym, 1))
	await _wait(0.5)
	_shot("rows_and_portfolio")
	var chart: GamePriceChart = screen.find_child("PriceChart", true, false)
	for frac in [0.93, 0.2]:
		var ev := InputEventMouseMotion.new()
		ev.position = Vector2(chart._plot.position.x + chart._plot.size.x * frac, 120)
		chart._on_canvas_gui_input(ev)
		await _wait(0.2)
		_shot("chart_hover_%d" % int(frac * 100))
	chart._hover_index = -1
	chart._canvas.queue_redraw()
	# Order panel with "10" typed and not submitted.
	var panel: GameOrderPanel = screen.find_child("OrderPanel", true, false)
	var shares: SharesInput = panel.find_child("SharesInput", true, false)
	shares.line_edit.text = "10"
	shares.line_edit.text_changed.emit("10")
	await _wait(0.3)
	_shot("order_10_typed")
	shares.line_edit.text = "abc"
	shares.line_edit.text_changed.emit("abc")
	await _wait(0.2)
	_shot("order_invalid")
	shares.line_edit.text = "1"
	shares.line_edit.text_changed.emit("1")

	# News pop-ups: one bullish, one bearish, then resolved ones.
	var bull: Rumor = _make_rumor(true)
	var bear: Rumor = _make_rumor(false)
	var any: Rumor = bull
	popups.enqueue(GameNewsPopups.Kind.POSTED, bull if bull != null else any, GameManager.session)
	popups.enqueue(GameNewsPopups.Kind.POSTED, bear if bear != null else any, GameManager.session)
	await _wait(0.2)
	_shot("news_mid_animation")
	await _wait(0.9)
	_shot("news_popups")
	popups.clear_all()
	await _wait(0.3)
	var t: Rumor = bull if bull != null else any
	t.is_true = true
	popups.enqueue(GameNewsPopups.Kind.RESOLVED, t, GameManager.session)
	await _wait(0.9)
	_shot("resolved_confirmed")
	popups.clear_all()
	await _wait(0.3)
	var f: Rumor = bear if bear != null else any
	f.is_true = false
	popups.enqueue(GameNewsPopups.Kind.RESOLVED, f, GameManager.session)
	await _wait(0.9)
	_shot("resolved_debunked")
	popups.clear_all()
	await _wait(0.3)

	# Perk draft with one of each rarity.
	var mix: Array = []
	for want in [PerkDef.Rarity.COMMON, PerkDef.Rarity.RARE, PerkDef.Rarity.LEGENDARY]:
		for p in ContentDb.perks():
			if p.rarity == want:
				mix.append(p)
				break
	EventBus.draft_offered.emit(mix)
	await _wait(0.5)
	_shot("draft_mid_animation")
	await _wait(1.3)
	_shot("draft_settled")
	var dialog: Node = screen.find_child("PerkDraftDialog", true, false)
	var cards: Array = dialog.cards()
	cards[2]._hover_target = 1.0
	cards[2]._tilt_target = 0.03
	await _wait(0.5)
	_shot("draft_hover_legendary")
	cards[2]._hover_target = 0.0
	cards[2]._tilt_target = 0.0
	await _wait(0.4)
	dialog._open_time = 0.0
	dialog.select_index(1)
	await _wait(0.3)
	_shot("draft_pick_mid")
	await _wait(1.2)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("shot ", shot_name)


## A seed whose six stocks include a long ticker (NFLE), a long name and a four-digit price.
func _find_seed(character: CharacterDef) -> int:
	for seed_value in range(1, 600):
		var s := GameSession.new(RunConfig.make(character, 1, seed_value), ContentDb.companies(), ContentDb.perks(), ContentDb.news())
		var syms: Array[String] = s.market.symbols()
		if "NFLE" in syms and ("LLU" in syms or "CAST" in syms) and ("MEGA" in syms or "ISRC" in syms):
			print("seed ", seed_value, " ", syms)
			return seed_value
	return 5


func _make_rumor(bullish: bool) -> Rumor:
	for ev in ContentDb.news():
		if (ev.total_impact >= 0.0) == bullish and ev.target_sector != "":
			var r := Rumor.new()
			r.event = ev
			r.posted_day = GameManager.session.day
			r.reveal_day = r.posted_day + (2 if bullish else 1)
			r.shown_credibility = 0.8 if bullish else 0.7
			return r
	return null
