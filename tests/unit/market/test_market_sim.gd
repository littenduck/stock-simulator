extends TestCase


func _company(symbol: String, sector: String, vol := 0.3, drift := 0.0, unlock: StringName = &"") -> CompanyDef:
	var c := CompanyDef.new()
	c.symbol = symbol
	c.sector = sector
	c.start_price = 100.0
	c.annual_volatility = vol
	c.annual_drift = drift
	c.unlock_id = unlock
	return c


func _event(sector: String, impact: float, days: int, symbol := "") -> NewsEventDef:
	var e := NewsEventDef.new()
	e.id = "e"
	e.target_sector = sector
	e.target_symbol = symbol
	e.total_impact = impact
	e.duration_days = days
	return e


func _sim(seed_value: int, companies: Array[CompanyDef] = []) -> MarketSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if companies.is_empty():
		companies = [_company("AAA", "tech"), _company("BBB", "space")]
	return MarketSim.new(companies, GbmPriceModel.new(), rng)


func _run(sim: MarketSim, days: int) -> void:
	for i in days:
		sim.step()


func test_same_seed_same_prices() -> void:
	var a := _sim(7)
	var b := _sim(7)
	_run(a, 60)
	_run(b, 60)
	for s in a.symbols():
		assert_eq(Array(a.history_of(s)), Array(b.history_of(s)), "history " + s)


func test_different_seed_differs() -> void:
	var a := _sim(7)
	var b := _sim(8)
	_run(a, 10)
	_run(b, 10)
	assert_true(a.price_of("AAA") != b.price_of("AAA"))


func test_price_never_below_floor() -> void:
	var sim := _sim(3, [_company("WILD", "tech", 2.0, -0.5)])
	for i in 300:
		sim.step()
		assert_true(sim.price_of("WILD") >= GbmPriceModel.MIN_PRICE)


func test_history_grows_and_is_capped() -> void:
	var sim := _sim(1)
	assert_eq(sim.history_of("AAA").size(), 1)
	_run(sim, 5)
	assert_eq(sim.history_of("AAA").size(), 6)
	_run(sim, MarketSim.MAX_HISTORY + 20)
	assert_eq(sim.history_of("AAA").size(), MarketSim.MAX_HISTORY)
	assert_almost(sim.history_of("AAA")[MarketSim.MAX_HISTORY - 1], sim.price_of("AAA"), 0.01)


func test_day_change() -> void:
	var sim := _sim(1)
	assert_eq(sim.day_change("AAA"), 0.0)
	sim.step()
	var h := sim.history_of("AAA")
	assert_almost(sim.day_change("AAA"), h[1] / h[0] - 1.0, 0.00001)


func test_news_shock_spread_over_duration() -> void:
	# zero-vol companies: only the shock moves the price
	var sim := _sim(1, [_company("AAA", "tech", 0.0001), _company("BBB", "space", 0.0001)])
	sim.apply_news(_event("tech", 0.20, 4))
	var daily := pow(1.2, 0.25) - 1.0
	for d in 4:
		var before := sim.price_of("AAA")
		sim.step()
		assert_almost(sim.price_of("AAA") / before - 1.0, daily, 0.002, "day %d" % d)
	assert_almost(sim.price_of("AAA"), 120.0, 0.5, "total impact")
	var before5 := sim.price_of("AAA")
	sim.step()
	assert_almost(sim.price_of("AAA") / before5 - 1.0, 0.0, 0.002, "shock expired")
	assert_almost(sim.price_of("BBB"), 100.0, 0.5, "other sector untouched")


func test_news_scale_negative_is_counter_impact() -> void:
	var sim := _sim(1, [_company("AAA", "tech", 0.0001)])
	sim.apply_news(_event("tech", 0.20, 2), -0.2)
	_run(sim, 2)
	assert_almost(sim.price_of("AAA"), 96.0, 0.2)


func test_news_targets() -> void:
	var sim := _sim(1, [_company("AAA", "tech", 0.0001), _company("BBB", "tech", 0.0001), _company("CCC", "space", 0.0001)])
	sim.apply_news(_event("tech", 0.10, 1, "BBB"))
	sim.step()
	assert_almost(sim.price_of("AAA"), 100.0, 0.2)
	assert_almost(sim.price_of("BBB"), 110.0, 0.2)
	sim.apply_news(_event("all", -0.10, 1))
	sim.step()
	assert_almost(sim.price_of("CCC"), 90.0, 0.2)
	assert_almost(sim.price_of("AAA"), 90.0, 0.2)


func test_save_load_roundtrip_continues_identically() -> void:
	var a := _sim(5)
	a.apply_news(_event("tech", 0.1, 6))
	_run(a, 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	# continue the original, and a restored copy with an rng in the same state
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5
	var b := MarketSim.new([_company("AAA", "tech"), _company("BBB", "space")], GbmPriceModel.new(), rng_b)
	rng_b.state = a._rng.state
	b.load_dict(data)
	assert_eq(b.history_of("AAA").size(), 4)
	_run(a, 5)
	_run(b, 5)
	assert_almost(a.price_of("AAA"), b.price_of("AAA"), 0.0001)
	assert_almost(a.price_of("BBB"), b.price_of("BBB"), 0.0001)


func test_set_price_overwrites_today() -> void:
	var sim := _sim(1)
	sim.set_price("AAA", 42.0)
	assert_eq(sim.price_of("AAA"), 42.0)
	assert_eq(sim.history_of("AAA")[0], 42.0)


func test_draw_companies_deterministic_and_unique() -> void:
	var pool: Array[CompanyDef] = []
	for i in 15:
		pool.append(_company("S%02d" % i, "tech"))
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var a := MarketSim.draw_companies(pool, 6, r1)
	var b := MarketSim.draw_companies(pool, 6, r2)
	assert_eq(a.size(), 6)
	var seen := {}
	for i in 6:
		assert_eq(a[i].symbol, b[i].symbol)
		seen[a[i].symbol] = true
	assert_eq(seen.size(), 6, "unique")
	# load order of the pool must not matter
	var reversed := pool.duplicate()
	reversed.reverse()
	var r3 := RandomNumberGenerator.new()
	r3.seed = 99
	var c := MarketSim.draw_companies(reversed, 6, r3)
	for i in 6:
		assert_eq(a[i].symbol, c[i].symbol, "pool order independent")


func test_draw_companies_respects_unlocks_and_varies_by_seed() -> void:
	var pool: Array[CompanyDef] = []
	for i in 10:
		pool.append(_company("S%02d" % i, "tech"))
	pool.append(_company("LOCK", "tech", 0.3, 0.0, &"u1"))
	var firsts := {}
	for seed_value in 30:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		var drawn := MarketSim.draw_companies(pool, 6, r)
		firsts[drawn[0].symbol] = true
		for c in drawn:
			assert_true(c.symbol != "LOCK", "locked company drawn")
	assert_true(firsts.size() > 3, "draw varies with the seed")
	var r2 := RandomNumberGenerator.new()
	r2.seed = 1
	var all_drawn := MarketSim.draw_companies(pool, 11, r2, [&"u1"])
	assert_eq(all_drawn.size(), 11)
	var r3 := RandomNumberGenerator.new()
	r3.seed = 1
	assert_eq(MarketSim.draw_companies(pool, 50, r3).size(), 10, "fewer eligible than count")
