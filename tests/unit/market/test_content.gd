extends TestCase

const REAL_TICKERS := ["AAPL", "MSFT", "GOOG", "AMZN", "META", "TSLA", "NVDA", "COIN", "PWR", "HLX", "GRID", "PETZ", "GENE", "MOON", "BANK", "BYTE", "MEDI", "CURA", "SOLR"]


func test_company_counts_and_fields() -> void:
	var cs := ContentDb.companies()
	assert_eq(cs.size(), 20, "20 companies")
	var starters := 0
	var symbols := {}
	var sectors := {}
	for c in cs:
		symbols[c.symbol] = true
		if c.unlock_id == &"":
			starters += 1
			sectors[c.sector] = (sectors.get(c.sector, 0) as int) + 1
		assert_true(c.symbol != "" and c.symbol == c.symbol.to_upper(), "symbol " + c.symbol)
		assert_eq(c.display_name, "COMPANY_" + c.symbol)
		assert_true(c.symbol not in REAL_TICKERS, "real ticker " + c.symbol)
		# NOVA is the one 4-letter exception: the lead's test_foundation refers to it (see requests file)
		assert_true(c.symbol.length() == 5 or c.symbol == "NOVA", "5 letter ticker " + c.symbol)
		assert_true(c.start_price > 0.0 and c.annual_volatility > 0.0)
		assert_true(tr(c.display_name) != c.display_name, "missing translation " + c.display_name)
	assert_eq(symbols.size(), 20, "unique symbols")
	assert_eq(starters, 15)
	assert_eq(sectors.size(), 5)
	for s in sectors:
		assert_eq(sectors[s], 3, "3 starters in " + s)


func test_news_templates() -> void:
	var ns := ContentDb.news()
	assert_true(ns.size() >= 30, "about 30+ templates")
	var good := {}
	var bad := {}
	var ids := {}
	var symbols := {}
	for c in ContentDb.companies():
		symbols[c.symbol] = c.sector
	for e in ns:
		ids[e.id] = true
		assert_eq(e.headline_key, "NEWS_" + e.id.to_upper())
		assert_true(tr(e.headline_key) != e.headline_key, "missing translation " + e.headline_key)
		assert_true(e.total_impact > -0.9 and e.denial_impact_ratio < 0.0)
		if e.target_symbol == NewsDirector.ANY_SYMBOL:
			assert_true(e.target_sector in symbols.values(), "no company in sector " + e.target_sector)
		elif e.target_symbol != "":
			assert_true(symbols.has(e.target_symbol), "unknown symbol " + e.target_symbol)
		elif e.target_sector != "all":
			var d := good if e.total_impact > 0.0 else bad
			d[e.target_sector] = (d.get(e.target_sector, 0) as int) + 1
	assert_eq(ids.size(), ns.size(), "unique ids")
	for s in ["tech", "energy", "consumer", "finance", "health"]:
		assert_true(good.get(s, 0) >= 2, "2 good in " + s)
		assert_true(bad.get(s, 0) >= 2, "2 bad in " + s)


func test_sixty_day_simulation_is_plausible() -> void:
	var pool := ContentDb.companies()
	for seed_value in [1, 2, 3, 4, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var unlocked: Array[StringName] = [&"co_lunaris", &"co_oldegate", &"co_quantora", &"co_tidalon", &"co_aurelix"]
		var market := MarketSim.new(MarketSim.draw_companies(pool, 6, rng, unlocked), GbmPriceModel.new(), rng)
		var director := NewsDirector.new(ContentDb.news(), rng)
		var mods := RunModifiers.new()
		var rumors := 0
		for day in range(1, 61):
			for r in director.due(day):
				market.apply_news(r.event, r.impact_scale())
			market.step()
			rumors += director.roll(day, mods, market).size()
		assert_true(rumors >= 10 and rumors <= 60, "rumor count %d" % rumors)
		for s in market.symbols():
			var p := market.price_of(s)
			var start := market.company_of(s).start_price
			assert_true(p >= GbmPriceModel.MIN_PRICE, "floor")
			assert_true(p < start * 12.0, "%s exploded: %f from %f" % [s, p, start])
