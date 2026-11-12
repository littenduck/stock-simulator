extends TestCase

func _config(seed_value: int = 42, difficulty: int = 1, margin: bool = false, char_id: StringName = &"rookie") -> RunConfig:
	return RunConfig.make(ContentDb.character_by_id(char_id), difficulty, seed_value, margin)


func _session(cfg: RunConfig) -> GameSession:
	var s := GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	s.start()
	return s


## Deterministic scripted policy: first perk of every draft, buy a little of the first stock on
## day 1, a limit order on day 2, sell half on day 30.
func _play_day(s: GameSession) -> DayReport:
	var syms := s.market.symbols()
	if s.day == 0:
		s.submit(Order.market(Order.Dir.BUY, syms[0], 5))
		s.submit(Order.limit(Order.Dir.BUY, syms[1], 3, s.market.price_of(syms[1]) * 0.97))
	if s.day == 30 and s.portfolio.shares_of(syms[0]) > 2:
		s.submit(Order.market(Order.Dir.SELL, syms[0], 2))
	var r := s.next_day()
	if not r.draft_offer.is_empty():
		s.choose_perk(r.draft_offer[0])
	return r


func _full_run(cfg: RunConfig) -> GameSession:
	var s := _session(cfg)
	s.choose_perk(s.pending_draft[0])
	var guard := 0
	while not s.is_finished() and guard < 100:
		_play_day(s)
		guard += 1
	return s


func test_day0_opens_draft() -> void:
	var s := _session(_config())
	assert_eq(s.pending_draft.size(), s.mods.draft_choices)
	assert_eq(s.day, 0)


func test_full_run_finishes_at_day_60() -> void:
	var s := _full_run(_config())
	assert_true(s.is_finished())
	assert_eq(s.day, 60)
	assert_true(s.score() > 0.0)
	assert_eq(s.book.pending().size(), 0, "orders cancelled at day 60")


func test_determinism() -> void:
	var a := _full_run(_config(7))
	var b := _full_run(_config(7))
	assert_eq(a.score(), b.score())
	assert_eq(a.owned_perks.size(), b.owned_perks.size())
	var c := _full_run(_config(8))
	assert_true(a.score() != c.score())


func test_draft_days() -> void:
	var s := _session(_config())
	s.choose_perk(s.pending_draft[0])
	var draft_days: Array[int] = []
	while not s.is_finished():
		var r := _play_day(s)
		if not r.draft_offer.is_empty():
			draft_days.append(r.day)
	assert_eq(draft_days, [10, 20, 30, 40, 50] as Array[int])
	assert_eq(s.owned_perks.size(), 6)


func test_finish_has_no_draft() -> void:
	var s := _session(_config())
	s.choose_perk(s.pending_draft[0])
	var last: DayReport
	while not s.is_finished():
		last = _play_day(s)
	assert_true(last.finished)
	assert_true(last.draft_offer.is_empty())


func test_report_contents_and_rumors_resolve() -> void:
	var s := _session(_config(3))
	s.choose_perk(s.pending_draft[0])
	var posted := 0
	var resolved := 0
	while not s.is_finished():
		var r := _play_day(s)
		posted += r.new_rumors.size()
		resolved += r.resolved_rumors.size()
		for x in r.resolved_rumors:
			assert_true(x.resolved)
	assert_true(posted > 0, "some rumors posted")
	assert_eq(resolved + s.news.pending().size(), posted)


func test_queued_order_fills_and_logs() -> void:
	var s := _session(_config(5))
	s.choose_perk(s.pending_draft[0])
	var sym := s.market.symbols()[0]
	var res := s.submit(Order.limit(Order.Dir.BUY, sym, 2, s.market.price_of(sym) * 10.0))
	assert_true(res.ok and res.pending)
	assert_true(res.order.id > 0)
	var r := s.next_day()
	assert_eq(r.fills.size(), 1)
	assert_true(r.fills[0].ok)
	assert_eq(s.portfolio.shares_of(sym), 2)
	assert_eq(s.trade_log.size(), 1)


func test_invalid_queued_order_fails() -> void:
	var s := _session(_config())
	var sym := s.market.symbols()[0]
	assert_false(s.submit(Order.limit(Order.Dir.BUY, sym, 0, 10.0)).ok)
	assert_false(s.submit(Order.limit(Order.Dir.BUY, "NOPE", 1, 10.0)).ok)
	assert_true(s.cancel_order(s.submit(Order.stop(Order.Dir.SELL, sym, 1, 1.0)).order.id))


func test_forced_liquidation_does_not_end_run() -> void:
	var s := _session(_config(11, 1, true))
	s.choose_perk(s.pending_draft[0])
	s.mods.max_leverage = 50.0
	var sym := s.market.symbols()[0]
	# Huge position, then crash the price: equity / exposure falls below maintenance.
	var shares := int(s.portfolio.cash * 20.0 / s.market.price_of(sym))
	s.submit(Order.market(Order.Dir.BUY, sym, shares))
	s.market.set_price(sym, s.market.price_of(sym) * 0.5)
	var r := s.next_day()
	assert_true(r.margin_called)
	assert_false(r.finished)
	assert_false(s.is_finished())
	assert_eq(s.portfolio.shares_of(sym), 0)
	s.next_day()
	assert_eq(s.day, 2)


func test_margin_disabled_blocks_shorting() -> void:
	var s := _session(_config(2, 1, false))
	assert_false(s.mods.can_short)
	assert_almost(s.mods.max_leverage, 1.0)


func test_difficulty4_sets_market_volatility() -> void:
	var s := _session(_config(2, 4))
	assert_almost(s.market.volatility_mult, 1.2)


func test_sector_fan_sets_bonus() -> void:
	var s := _session(_config(9))
	var fan := ContentDb.perk_by_id(&"sector_fan")
	s.choose_perk(fan)
	assert_eq(s.mods.sector_truth_bonus.size(), 1)
	for k in s.mods.sector_truth_bonus:
		assert_almost(s.mods.sector_truth_bonus[k], 0.15)
	# survives another perk pick (mods are rebuilt)
	s.choose_perk(ContentDb.perk_by_id(&"low_fees"))
	assert_eq(s.mods.sector_truth_bonus.size(), 1)


func _roundtrip(s: GameSession) -> GameSession:
	var text := JSON.stringify(s.to_dict())
	var data: Dictionary = JSON.parse_string(text)
	var cfg := GameSession.config_from_dict(data)
	return GameSession.from_dict(data, cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())


func test_save_load_identical_continuation() -> void:
	var a := _session(_config(21, 2, true))
	a.choose_perk(a.pending_draft[0])
	for i in 25:
		_play_day(a)
	var b := _roundtrip(a)
	assert_not_null(b)
	assert_eq(b.day, a.day)
	assert_eq(b.market.symbols(), a.market.symbols())
	assert_true(b.config.margin_enabled)
	assert_eq(b.book.pending().size(), a.book.pending().size())
	assert_eq(b.news.pending().size(), a.news.pending().size())
	assert_almost(b.net_worth(), a.net_worth(), 0.0001)
	while not a.is_finished():
		_play_day(a)
		_play_day(b)
		assert_almost(a.net_worth(), b.net_worth(), 0.0001, "day %d" % a.day)
	assert_true(b.is_finished())
	assert_almost(a.score(), b.score(), 0.0001)


func test_save_load_pending_draft() -> void:
	var a := _session(_config(4))
	var b := _roundtrip(a)
	assert_eq(b.pending_draft.size(), a.pending_draft.size())
	assert_eq(b.pending_draft[0].id, a.pending_draft[0].id)


func test_migrate_rejects_garbage() -> void:
	assert_true(GameSession.migrate({}).is_empty())
	assert_true(GameSession.migrate({"version": 99}).is_empty())
