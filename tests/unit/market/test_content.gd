extends TestCase

const ICONS := ["chip", "window", "fruit", "magnifier", "people", "eye", "rocket", "box", "car", "play", "cart", "coffee", "soda", "bank", "card", "coin", "pill", "cross", "dna", "robot", "drop", "barrel", "sun"]
const ALL_UNLOCKS: Array[StringName] = [&"company_moon", &"company_olde", &"company_extra_1", &"company_extra_2", &"company_extra_3"]


func test_company_counts_and_fields() -> void:
	var cs := ContentDb.companies()
	assert_eq(cs.size(), 24, "24 companies")
	var starters := 0
	var symbols := {}
	var keys := {}
	var sectors := {}
	var hist := HistoryData.default()
	assert_not_null(hist, "history.csv loads")
	for c in cs:
		symbols[c.symbol] = true
		keys[c.history_key] = true
		if c.unlock_id == &"":
			starters += 1
			sectors[c.sector] = (sectors.get(c.sector, 0) as int) + 1
		assert_true(c.symbol != "" and c.symbol == c.symbol.to_upper(), "symbol " + c.symbol)
		assert_true(c.symbol.length() >= 3 and c.symbol.length() <= 5, "ticker length " + c.symbol)
		assert_eq(c.display_name, "COMPANY_" + c.symbol)
		assert_true(c.icon in ICONS, "icon " + c.symbol)
		assert_true(c.history_key != "" and c.history_key != c.symbol, "history key is the real ticker " + c.symbol)
		if hist != null:
			assert_true(hist.has_key(c.history_key), "history column " + c.history_key)
		assert_true(c.start_price > 0.0 and c.annual_volatility > 0.0)
		assert_true(tr(c.display_name) != c.display_name, "missing translation " + c.display_name)
		assert_true(c.unlock_id == &"" or c.unlock_id in ALL_UNLOCKS, "unknown unlock id " + String(c.unlock_id))
	assert_eq(symbols.size(), 24, "unique symbols")
	assert_eq(keys.size(), 24, "unique history keys")
	assert_eq(starters, 19)
	assert_eq(sectors.size(), 5)
	for s in sectors:
		assert_true(sectors[s] >= 3, "3+ starters in " + s)


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
	assert_true(ns.size() >= 50, "50+ templates")
	var sym_events := 0
	var sectors_with_symbol := {}
	for e in ns:
		assert_true(e.icon == "" or e.icon in ICONS, "unknown news icon " + e.icon)
		if e.target_symbol != "" and e.target_symbol != NewsDirector.ANY_SYMBOL:
			sym_events += 1
			sectors_with_symbol[symbols[e.target_symbol]] = true
			assert_eq(e.target_sector, symbols[e.target_symbol], "target_sector matches company " + e.id)
			assert_true(e.id.begins_with(e.target_symbol.to_lower() + "_"), "id starts with ticker " + e.id)
	assert_true(sym_events >= 20, "20+ symbol events")
	assert_eq(sectors_with_symbol.size(), 5, "symbol events in all sectors")
	for s in ["tech", "energy", "consumer", "finance", "health"]:
		assert_true(good.get(s, 0) >= 2, "2 good in " + s)
		assert_true(bad.get(s, 0) >= 2, "2 bad in " + s)


func test_news_csv_keys_match_events() -> void:
	var f := FileAccess.open("res://localization/news.csv", FileAccess.READ)
	assert_not_null(f, "news.csv readable")
	var keys := {}
	f.get_csv_line()    # header
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() >= 2 and line[0] != "":
			assert_false(keys.has(line[0]), "duplicate csv key " + line[0])
			assert_true(line[1].begins_with("Rumor:"), "rumor tone " + line[0])
			keys[line[0]] = true
	var used := {}
	for e in ContentDb.news():
		assert_true(keys.has(e.headline_key), "csv lacks " + e.headline_key)
		used[e.headline_key] = true
	for k in keys:
		assert_true(used.has(k), "orphan csv key " + k)


func test_symbol_events_only_fire_for_drawn_companies() -> void:
	var pool := ContentDb.companies()
	var by_sector := {}
	for seed_value in range(1, 13):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var market := MarketSim.new(MarketSim.draw_companies(pool, 6, rng, ALL_UNLOCKS), GbmPriceModel.new(), rng)
		var director := NewsDirector.new(ContentDb.news(), rng)
		var rumors := 0
		var mods := RunModifiers.new()
		for day in range(1, 61):
			market.step()
			for r in director.roll(day, mods, market):
				rumors += 1
				assert_true(market.has_symbol(r.event.target_symbol) or r.event.target_symbol == "", "rumor for symbol not in run: " + r.event.id)
		assert_true(rumors >= 12, "seed %d only %d rumors" % [seed_value, rumors])


func test_sixty_day_simulation_is_plausible() -> void:
	var pool := ContentDb.companies()
	for seed_value in [1, 2, 3, 4, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var unlocked: Array[StringName] = ALL_UNLOCKS
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
