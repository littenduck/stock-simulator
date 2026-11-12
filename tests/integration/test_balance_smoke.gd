## Integration smoke test: whole-run flow through GameSession and the audio hookup.
## Works against the stubs; assertions only use properties that hold for stub and real code.
extends TestCase


func _session(seed_value: int) -> GameSession:
	var cfg := RunConfig.make(ContentDb.characters()[0], 1, seed_value)
	return GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())


func test_full_run_finishes_in_60_days() -> void:
	var s := _session(42)
	s.start()
	var guard := 0
	while not s.is_finished() and guard < 200:
		guard += 1
		s.next_day()
		if not s.pending_draft.is_empty():
			s.choose_perk(s.pending_draft[0])
	assert_true(s.is_finished(), "run finishes")
	assert_eq(s.day, RunConfig.TRADING_DAYS, "60 trading days")


func test_same_seed_same_result() -> void:
	var a := _session(7)
	var b := _session(7)
	for i in 10:
		a.next_day()
		b.next_day()
		if not a.pending_draft.is_empty():
			a.choose_perk(a.pending_draft[0])
		if not b.pending_draft.is_empty():
			b.choose_perk(b.pending_draft[0])
	assert_almost(a.net_worth(), b.net_worth(), 0.0001, "determinism")
	assert_eq(a.market.symbols(), b.market.symbols(), "same companies")


func test_audio_feedback_survives_missing_files_and_signals() -> void:
	var node: Node = load("res://ui/audio/audio_feedback.tscn").instantiate()
	var bus: Node = load("res://autoload/event_bus.gd").new()
	# Not added to a tree: the test runner has none while tests execute.
	node.call("_ready")
	node.set("_streams", {})
	node.call("bind_bus", bus)
	bus.day_advanced.emit(1)
	bus.margin_called.emit()
	bus.trade_failed.emit("TRADE_ERR_X")
	bus.draft_offered.emit([])
	var o := Order.market(Order.Dir.SELL, "NOVA", 1)
	bus.order_filled.emit(o, TradeResult.success(o, 1.0, 0.0))
	var played: Dictionary = node.get("played")
	assert_eq(played.get(&"next_day"), 1, "next_day sound")
	assert_eq(played.get(&"margin_call"), 1, "margin sound")
	assert_eq(played.get(&"error"), 1, "error sound")
	assert_eq(played.get(&"perk"), 1, "perk sound")
	assert_eq(played.get(&"sell"), 1, "sell sound")
	node.free()
	bus.free()


func test_all_sfx_files_exist() -> void:
	var node: Node = load("res://ui/audio/audio_feedback.tscn").instantiate()
	var sfx: Dictionary = node.get("SFX")
	for key in sfx:
		assert_true(ResourceLoader.exists("res://audio/" + String(sfx[key])), "missing audio " + String(sfx[key]))
	node.free()
