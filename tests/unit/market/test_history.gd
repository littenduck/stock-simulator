## Real history replay: HistoryData, HistoricalPriceModel, candles, session window, save/load.
extends TestCase


func _session(seed_value: int, difficulty: int = 1) -> GameSession:
	var cfg := RunConfig.make(ContentDb.characters()[0], difficulty, seed_value)
	return GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())


func _play_day(s: GameSession) -> void:
	if not s.pending_draft.is_empty():
		s.choose_perk(s.pending_draft[0])
	s.next_day()


func _bar(h: HistoryData, key: String, row: int) -> PackedFloat32Array:
	var b := h.bar(key, row)
	return PackedFloat32Array([b[0], b[1], b[2], b[3]])


func _real_company(symbol: String, key: String) -> CompanyDef:
	var c := CompanyDef.new()
	c.symbol = symbol
	c.history_key = key
	c.sector = "tech"
	c.start_price = 100.0
	return c


func test_history_data_loads_and_is_consistent() -> void:
	var h := HistoryData.default()
	assert_not_null(h)
	assert_eq(h.row_count(), 1220)
	assert_eq(h.date_at(0), "2022-01-03")
	assert_eq(h.date_at(1219), "2026-11-11")
	assert_eq(h.date_at(5000), "")
	for key in ["NVDA", "SOFI", "SNDK", "SPCX", "LUNR"]:
		assert_true(h.has_key(key))
		for r in range(h.first_row(key), h.row_count()):
			var b := h.bar(key, r)
			assert_true(b[2] <= b[0] and b[2] <= b[3] and b[0] <= b[1] and b[3] <= b[1], "%s row %d ohlc" % [key, r])
			assert_true(b[2] > 0.0)
	assert_eq(h.first_row("NVDA"), 0)
	assert_true(h.first_row("SNDK") > 0 and h.first_row("SPCX") > h.first_row("SNDK"), "late listings start later")
	assert_eq(h.first_row("NOPE"), -1)
	assert_false(h.has_key("NOPE"))
	assert_eq(h.bar("NOPE", 0).size(), 0)


func test_history_from_text() -> void:
	var h := HistoryData.from_text("date,AAA_o,AAA_h,AAA_l,AAA_c\n2024-01-02,10,11,9,10.5\n2024-01-03,10.5,12,10,11\n")
	assert_not_null(h)
	assert_eq(h.row_count(), 2)
	assert_almost(h.close_at("AAA", 1), 11.0)
	assert_eq(h.date_at(1), "2024-01-03")


func test_window_is_deterministic_per_seed_and_in_range() -> void:
	var seen := {}
	for seed_value in range(1, 31):
		var a := _session(seed_value)
		var b := _session(seed_value)
		assert_eq(a.window_start, b.window_start, "same seed same window")
		assert_eq(a.date_of_day(0), b.date_of_day(0))
		assert_true(a.window_start >= GameSession.PRE_GAME_DAYS, "lookback fits")
		assert_true(a.window_start + RunConfig.TRADING_DAYS < HistoryData.default().row_count(), "window fits")
		seen[a.window_start] = true
	assert_true(seen.size() >= 15, "different seeds use different windows (%d distinct)" % seen.size())


func test_history_from_text_late_listing_has_empty_cells() -> void:
	var h := HistoryData.from_text("date,AAA_o,AAA_h,AAA_l,AAA_c,BBB_o,BBB_h,BBB_l,BBB_c\n2024-01-02,10,11,9,10.5,,,,\n2024-01-03,10.5,12,10,11,5,6,4,5.5\n")
	assert_not_null(h)
	assert_eq(h.first_row("AAA"), 0)
	assert_eq(h.first_row("BBB"), 1)
	assert_almost(h.close_at("BBB", 1), 5.5)


func test_window_leaves_lookback_for_every_drawn_company() -> void:
	var h := HistoryData.default()
	for seed_value in range(1, 61):
		var s := _session(seed_value)
		for sym in s.market.symbols():
			var c := s.market.company_of(sym)
			assert_true(h.first_row(c.history_key) <= s.window_start - GameSession.PRE_GAME_DAYS, "%s has data for the whole window (seed %d)" % [sym, seed_value])


func test_late_listed_companies_still_appear() -> void:
	# SpaceZ (real SPCX, listed 2026-06) fits only recent windows but must still be drawable.
	var spcz := 0
	var unlocked: Array[StringName] = []
	for seed_value in range(1, 301):
		var cfg := RunConfig.make(ContentDb.characters()[0], 1, seed_value)
		var s := GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news(), unlocked)
		if s.market.has_symbol("SPCZ"):
			spcz += 1
			assert_true(s.date_of_day(0) >= "2026-07", "SpaceZ windows are recent: " + s.date_of_day(0))
	assert_true(spcz >= 20, "SpaceZ appears in some runs (%d)" % spcz)


func test_every_run_has_a_space_or_finance_company() -> void:
	for seed_value in range(1, 201):
		var cfg := RunConfig.make(ContentDb.characters()[0], 1, seed_value)
		var s := GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
		var ok := false
		for sector in s.market.sectors():
			ok = ok or sector in GameSession.GUARANTEED_SECTORS
		assert_true(ok, "seed %d has a space or finance company" % seed_value)


func test_dates_aligned_across_companies_and_starting_prices_are_real() -> void:
	var h := HistoryData.default()
	var s := _session(5)
	assert_true(s.window_start >= 0)
	var lb := GameSession.PRE_GAME_DAYS
	for sym in s.market.symbols():
		var c := s.market.company_of(sym)
		assert_eq(s.market.lookback_of(sym), lb, "lookback " + sym)
		var closes := s.market.history_of(sym)
		assert_eq(closes.size(), lb + 1)
		# Every entry of every company is the real close of the SAME calendar row.
		for i in closes.size():
			var row := s.window_start - lb + i
			assert_almost(closes[i], h.close_at(c.history_key, row), maxf(0.001, closes[i] * 1e-5), "%s row %d" % [sym, row])
		assert_almost(s.market.price_of(sym), h.close_at(c.history_key, s.window_start), maxf(0.001, closes[lb] * 1e-5), "start price is the real close")
	assert_eq(s.date_of_day(0), h.date_at(s.window_start))
	assert_eq(s.date_of_day(60), h.date_at(s.window_start + 60))
	assert_eq(s.date_of_day(-lb), h.date_at(s.window_start - lb))
	assert_eq(s.date_of_day(500), s.date_of_day(60), "clamped past the end")
	assert_true(s.date_of_day(0).length() == 10 and s.date_of_day(0) < s.date_of_day(1))


func test_candle_invariants_over_full_run_with_news_and_volatility() -> void:
	for seed_value in [3, 11]:
		var s := _session(seed_value, 4)   # difficulty 4 = volatility_mult 1.2
		s.start()
		while not s.is_finished():
			_play_day(s)
		for sym in s.market.symbols():
			var c := s.market.candles_of(sym)
			var n := s.market.history_of(sym).size()
			assert_eq(n, GameSession.PRE_GAME_DAYS + 1 + RunConfig.TRADING_DAYS, "history length")
			assert_true(n <= MarketSim.MAX_HISTORY)
			for k in ["open", "high", "low", "close"]:
				assert_eq((c[k] as PackedFloat32Array).size(), n, k + " parallel")
			for i in n:
				var o: float = c["open"][i]
				var hi: float = c["high"][i]
				var lo: float = c["low"][i]
				var cl: float = c["close"][i]
				assert_true(lo <= o and lo <= cl and o <= hi and cl <= hi and lo > 0.0, "%s candle %d: o%f h%f l%f c%f" % [sym, i, o, hi, lo, cl])
			assert_eq(Array(c["close"]), Array(s.market.history_of(sym)))


func test_gbm_candles_also_satisfy_invariants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var co := CompanyDef.new()
	co.symbol = "AAA"
	co.sector = "tech"
	co.start_price = 50.0
	co.annual_volatility = 0.9
	var sim := MarketSim.new([co] as Array[CompanyDef], GbmPriceModel.new(), rng)
	for i in 200:
		sim.step()
	var c := sim.candles_of("AAA")
	assert_eq(sim.lookback_of("AAA"), 0)
	for i in sim.history_of("AAA").size():
		assert_true(c["low"][i] <= minf(c["open"][i], c["close"][i]) and c["high"][i] >= maxf(c["open"][i], c["close"][i]), "gbm candle %d" % i)


func test_replay_matches_csv_returns_without_news() -> void:
	var h := HistoryData.default()
	var start := 100
	var co := _real_company("AAA", "MSFT")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var sim := MarketSim.new([co] as Array[CompanyDef], HistoricalPriceModel.new(h, start), rng)
	var p0 := h.close_at("MSFT", start)
	sim.init_series("AAA", [_bar(h, "MSFT", start)])
	assert_almost(sim.price_of("AAA"), p0, 0.01)
	var state_before := rng.state
	for d in range(1, 61):
		sim.step()
		var real_ratio := h.close_at("MSFT", start + d) / h.close_at("MSFT", start + d - 1)
		var hist := sim.history_of("AAA")
		var ratio := hist[hist.size() - 1] / hist[hist.size() - 2]
		assert_almost(ratio, real_ratio, 2e-4, "daily return day %d" % d)
		assert_almost(sim.price_of("AAA") / p0, h.close_at("MSFT", start + d) / p0, 2e-3 * h.close_at("MSFT", start + d) / p0, "level day %d" % d)
	assert_eq(rng.state, state_before, "replay consumes no rng draws")


func test_replay_news_shock_multiplies_and_persists() -> void:
	var h := HistoryData.default()
	var start := 200
	var make := func() -> MarketSim:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var sim := MarketSim.new([_real_company("AAA", "AAPL")] as Array[CompanyDef], HistoricalPriceModel.new(h, start), rng)
		sim.init_series("AAA", [_bar(h, "AAPL", start)])
		return sim
	var plain: MarketSim = make.call()
	var shocked: MarketSim = make.call()
	var ev := NewsEventDef.new()
	ev.target_symbol = "AAA"
	ev.total_impact = 0.20
	ev.duration_days = 4
	shocked.apply_news(ev)
	for i in 10:
		plain.step()
		shocked.step()
	assert_almost(shocked.price_of("AAA") / plain.price_of("AAA"), 1.20, 0.002, "shock persists on top of the real path")


func test_volatility_mult_scales_log_returns() -> void:
	var h := HistoryData.default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var sim := MarketSim.new([_real_company("AAA", "TSLA")] as Array[CompanyDef], HistoricalPriceModel.new(h, 300), rng)
	sim.volatility_mult = 1.2
	sim.init_series("AAA", [_bar(h, "TSLA", 300)])
	sim.step()
	var real_log := log(h.close_at("TSLA", 301) / h.close_at("TSLA", 300))
	var hist := sim.history_of("AAA")
	assert_almost(log(hist[1] / hist[0]), 1.2 * real_log, 5e-4)


func test_model_falls_back_to_gbm_without_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var sim := MarketSim.new([_real_company("ZZZ", "NOPE")] as Array[CompanyDef], HistoricalPriceModel.new(HistoryData.default(), 100), rng)
	for i in 5:
		sim.step()
	assert_true(sim.price_of("ZZZ") > 0.0 and sim.price_of("ZZZ") != 100.0)


func test_save_load_roundtrip_keeps_window_candles_and_continues_identically() -> void:
	var a := _session(21)
	a.start()
	a.choose_perk(a.pending_draft[0])
	for i in 15:
		_play_day(a)
	var data: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	assert_eq(int(data["window_start"]), a.window_start)
	assert_eq(String(data["start_date"]), a.date_of_day(0))
	var b := GameSession.from_dict(data, GameSession.config_from_dict(data), ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	assert_not_null(b)
	assert_eq(b.window_start, a.window_start)
	assert_eq(b.date_of_day(30), a.date_of_day(30))
	for sym in a.market.symbols():
		assert_eq(b.market.lookback_of(sym), a.market.lookback_of(sym))
		var ca := a.market.candles_of(sym)
		var cb := b.market.candles_of(sym)
		for k in ["open", "high", "low", "close"]:
			assert_eq(Array(cb[k]), Array(ca[k]), "%s %s" % [sym, k])
	for i in 20:
		_play_day(a)
		_play_day(b)
		for sym in a.market.symbols():
			assert_almost(a.market.price_of(sym), b.market.price_of(sym), a.market.price_of(sym) * 1e-5, "day %d %s" % [a.day, sym])


func test_old_save_without_window_falls_back_to_gbm() -> void:
	var a := _session(8)
	a.start()
	for i in 5:
		_play_day(a)
	var data: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	data.erase("window_start")
	data.erase("start_date")
	var m: Dictionary = data["market"]
	m.erase("candles")
	m.erase("lookback")
	m.erase("steps")
	var b := GameSession.from_dict(data, GameSession.config_from_dict(data), ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	assert_not_null(b)
	assert_eq(b.window_start, -1)
	assert_eq(b.date_of_day(0), "")
	for sym in b.market.symbols():
		var n := b.market.history_of(sym).size()
		assert_eq((b.market.candles_of(sym)["open"] as PackedFloat32Array).size(), n)
	for i in 10:
		_play_day(b)
	assert_eq(b.day, 15)
	for sym in b.market.symbols():
		assert_true(b.market.price_of(sym) > 0.0)
